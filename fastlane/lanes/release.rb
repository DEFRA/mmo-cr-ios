platform :ios do
  desc "Compile the app ONCE with its bundle identity and keep the signed archive. No stage config, no upload."
  lane :compile do |options|
    app = CrRelease.app!(options[:app])
    team_id = ENV.fetch("APPLE_TEAM_ID")
    profile_name = sync_signing(app_identifier: app[:app_identifier])

    FileUtils.rm_rf(CrRelease::RELEASE_DIR)
    FileUtils.mkdir_p(CrRelease::RELEASE_DIR)
    archive = CrRelease::ARCHIVE_PATH

    build_app(
      project: CrRelease::PROJECT,
      scheme: app[:scheme],
      configuration: app[:configuration],
      archive_path: archive,
      skip_package_ipa: true,
      clean: true,
      xcargs: CrRelease::Signing.xcargs(team_id, profile_name, app)
    )
    CrRelease::Archive.expect_app!(archive, app)

    app_plist = CrRelease::Archive.app_plist(archive)
    commit = ENV["GITHUB_SHA"].to_s[0, 7]
    CrRelease::Plist.set_string(app_plist, "GitCommitSHA", commit) unless commit.empty?

    uuids = CrRelease::Archive.mach_o_uuids(CrRelease::Archive.app_path(archive))
    File.write(CrRelease::UUIDS_PATH, JSON.generate(uuids))
    UI.success("#{app[:app_identifier]} #{CrRelease::Plist.read(app_plist, 'CFBundleShortVersionString')} " \
               "(#{CrRelease::Plist.read(app_plist, 'CFBundleVersion')}) compiled")
  end

  desc "Package the compiled archive with this Environment's stage config as build N and upload it to TestFlight."
  lane :upload_internal do |options|
    app = CrRelease.app!(options[:app])
    config = CrRelease::AppConfig.from_env!(ENV.fetch("CR_APP_CFG_VARS", ""))
    team_id = ENV.fetch("APPLE_TEAM_ID")
    groups = app[:external_on_upload] ? CrRelease::TestFlight.external_groups!(ENV["ASC_EXTERNAL_TESTING_GROUPS"]) : []

    archive = CrRelease.expect_archive!
    CrRelease::Archive.expect_app!(archive, app)
    version, build_number = CrRelease::ReleaseTag.parse!(ENV["GITHUB_REF_NAME"])
    archived_build = CrRelease::Plist.read(CrRelease::Archive.app_plist(archive), "CFBundleVersion")
    UI.user_error!("Archive build '#{archived_build}' does not match the tag's build #{build_number}") unless archived_build == build_number
    uuids = JSON.parse(File.read(CrRelease::UUIDS_PATH))

    api_key = asc_api_key
    if CrRelease::TestFlight.build_exists?(app[:app_identifier], version, build_number)
      # This run's compile is not the code already uploaded as build N, so promotion could not prove compile-once.
      UI.user_error!("Build #{version} (#{build_number}) is already in TestFlight for #{app[:app_identifier]}. " \
                     "Bump the version and release again.")
    end

    profile_name = sync_signing(app_identifier: app[:app_identifier], api_key: api_key)
    ipa, exported_app = export_package(
      archive: archive, name: "internal", config: config, build_number: build_number,
      team_id: team_id, profile_name: profile_name, app: app
    )
    CrRelease::PackageChecks.verify!(exported_app, app: app, config: config, build_number: build_number, uuids: uuids)

    upload = { api_key: api_key, ipa: ipa, app_identifier: app[:app_identifier] }
    if groups.empty?
      upload_to_testflight(**upload, distribute_external: false, skip_waiting_for_build_processing: true)
    else
      upload_to_testflight(
        **upload, distribute_external: true, groups: groups, notify_external_testers: true,
        # Shown to external testers as "What to Test"; Apple requires it for external distribution.
        changelog: "Version #{version} (#{build_number})", skip_waiting_for_build_processing: false
      )
    end
    UI.success("#{app[:app_identifier]} build #{build_number} -> internal TestFlight#{" and external #{groups}" unless groups.empty?}")
  end

  desc "Re-package the kept archive with this Environment's stage config as build N.1 and send it to external TestFlight. No recompile."
  lane :promote_external do |options|
    app = CrRelease.app!(options[:app])
    config = CrRelease::AppConfig.from_env!(ENV.fetch("CR_APP_CFG_VARS", ""))
    team_id = ENV.fetch("APPLE_TEAM_ID")
    groups = CrRelease::TestFlight.external_groups!(ENV["ASC_EXTERNAL_TESTING_GROUPS"])

    archive = CrRelease.expect_archive!
    CrRelease::Archive.expect_app!(archive, app)

    app_plist = CrRelease::Archive.app_plist(archive)
    internal_only_hosts =
      config.url_hosts(CrRelease::Plist.read_json(app_plist, CrRelease::AppConfig::PLIST_KEY)) - config.url_hosts
    internal_build = CrRelease::Plist.read(app_plist, "CFBundleVersion")
    UI.user_error!("Archive build '#{internal_build}' is not an internal build N") unless internal_build.match?(/\A\d+\z/)
    external_build = "#{internal_build}.1"
    version = CrRelease::Plist.read(app_plist, "CFBundleShortVersionString")
    uuids = JSON.parse(File.read(CrRelease::UUIDS_PATH))

    api_key = asc_api_key
    distribution = {
      api_key: api_key,
      app_identifier: app[:app_identifier],
      distribute_external: true,
      groups: groups,
      # Shown to external testers as "What to Test"; Apple requires it for external distribution.
      changelog: "Version #{version} (#{external_build})",
      notify_external_testers: true
    }

    if CrRelease::TestFlight.build_exists?(app[:app_identifier], version, external_build)
      # Only a package that passed every check below is ever uploaded, so a re-run just finishes distribution.
      UI.important("Build #{version} (#{external_build}) is already in TestFlight; distributing it without re-uploading")
      upload_to_testflight(
        **distribution, distribute_only: true, app_version: version, build_number: external_build,
        app_platform: "ios"
      )
    else
      profile_name = sync_signing(app_identifier: app[:app_identifier], api_key: api_key)

      ipa, exported_app = export_package(
        archive: archive, name: "external", config: config, build_number: external_build,
        team_id: team_id, profile_name: profile_name, app: app
      )
      CrRelease::PackageChecks.verify!(exported_app, app: app, config: config, build_number: external_build, uuids: uuids)
      CrRelease::PackageChecks.expect_no_leaks!(exported_app, internal_only_hosts)

      upload_to_testflight(**distribution, ipa: ipa, skip_waiting_for_build_processing: false)
    end
    UI.success("#{app[:app_identifier]} build #{external_build} -> external TestFlight #{groups} " \
               "(same compiled code as build #{internal_build})")
  end

  desc "Submit the external build N.1 (the upload sanity testers used) for App Review. No packaging or signing."
  lane :submit_app_store do |options|
    app = CrRelease.app!(options[:app])
    UI.user_error!("#{app[:app_identifier]} is not released to the App Store") unless app[:app_store]
    version, build_number = CrRelease::ReleaseTag.parse!(ENV["GITHUB_REF_NAME"])
    external_build = "#{build_number}.1"

    api_key = asc_api_key
    unless CrRelease::TestFlight.build_exists?(app[:app_identifier], version, external_build)
      UI.user_error!("Build #{version} (#{external_build}) is not in App Store Connect for #{app[:app_identifier]}; " \
                     "promote it to external TestFlight first")
    end

    # Release type and phased release are only applied on the metadata path, so point it at an empty folder.
    metadata = File.join(CrRelease::RELEASE_DIR, "no-metadata")
    FileUtils.mkdir_p(metadata)
    upload_to_app_store(
      api_key: api_key,
      app_identifier: app[:app_identifier],
      app_version: version,
      build_number: external_build,
      metadata_path: metadata,
      skip_binary_upload: true,
      skip_screenshots: true,
      submit_for_review: true,
      automatic_release: false,
      phased_release: true,
      force: true,
      # Precheck cannot run its in-app purchase rule with an API key.
      run_precheck_before_submit: false,
      submission_information: { export_compliance_uses_encryption: false }
    )
    UI.success("#{app[:app_identifier]} #{version} (#{external_build}) submitted for App Review; release stays manual")
  end
end
