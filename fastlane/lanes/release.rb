platform :ios do
  desc "Compile the app ONCE with its internal stage config, upload build N to internal TestFlight, keep the archive."
  lane :build_internal do |options|
    app = CrRelease.app!(options[:app])
    config = CrRelease::AppConfig.from_env!(ENV.fetch("CR_APP_CFG_VARS", ""))
    team_id = ENV.fetch("APPLE_TEAM_ID")
    api_key = asc_api_key

    version, build_number = CrRelease::ReleaseTag.parse!(ENV["GITHUB_REF_NAME"])
    if CrRelease::TestFlight.build_exists?(app[:app_identifier], version, build_number)
      # A recompile would not be the code already uploaded as build N, so promotion could not prove compile-once.
      UI.user_error!("Build #{version} (#{build_number}) is already in TestFlight for #{app[:app_identifier]}. " \
                     "Re-run only the failed jobs; if this build job failed after uploading, bump the version.")
    end

    profile_name = sync_signing(app_identifier: app[:app_identifier], api_key: api_key)

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
      xcargs: CrRelease::Signing.xcargs(team_id, profile_name)
    )
    CrRelease::Archive.expect_app!(archive, app)

    app_plist = CrRelease::Archive.app_plist(archive)
    build_number = CrRelease::Plist.read(app_plist, "CFBundleVersion")
    commit = ENV["GITHUB_SHA"].to_s[0, 7]
    CrRelease::Plist.set_string(app_plist, "GitCommitSHA", commit) unless commit.empty?

    uuids = CrRelease::Archive.mach_o_uuids(CrRelease::Archive.app_path(archive))
    File.write(CrRelease::UUIDS_PATH, JSON.generate(uuids))

    ipa, exported_app = export_package(
      archive: archive, name: "internal", config: config, build_number: build_number,
      team_id: team_id, profile_name: profile_name, app: app
    )
    CrRelease::PackageChecks.verify!(exported_app, app: app, config: config, build_number: build_number, uuids: uuids)

    upload_to_testflight(
      api_key: api_key,
      ipa: ipa,
      app_identifier: app[:app_identifier],
      distribute_external: false,
      skip_waiting_for_build_processing: true
    )
    UI.success("#{app[:app_identifier]} build #{build_number} -> internal TestFlight")
  end

  desc "Re-package the kept archive with this Environment's stage config as build N.1 and send it to external TestFlight. No recompile."
  lane :promote_external do |options|
    app = CrRelease.app!(options[:app])
    config = CrRelease::AppConfig.from_env!(ENV.fetch("CR_APP_CFG_VARS", ""))
    team_id = ENV.fetch("APPLE_TEAM_ID")
    groups = ENV.fetch("ASC_EXTERNAL_TESTING_GROUPS", "").split(",").map(&:strip).reject(&:empty?)
    UI.user_error!("ASC_EXTERNAL_TESTING_GROUPS is empty") if groups.empty?

    archive = CrRelease::ARCHIVE_PATH
    unless File.directory?(archive) && File.file?(CrRelease::UUIDS_PATH)
      UI.user_error!("No archive in #{CrRelease::RELEASE_DIR}; download and decrypt the build job's artifact first")
    end
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
      upload_to_testflight(**distribution, distribute_only: true, app_version: version, build_number: external_build)
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
end
