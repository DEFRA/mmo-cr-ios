platform :ios do
  desc "Write the stage config and build number into the archive, then export (re-sign) it. The compiler never runs here."
  private_lane :export_package do |options|
    archive = options.fetch(:archive)
    name = options.fetch(:name)
    app = options.fetch(:app)

    CrRelease::Plist.write_json(
      CrRelease::Archive.app_plist(archive), CrRelease::AppConfig::PLIST_KEY, options.fetch(:config).values
    )
    CrRelease::Archive.set_build_number(archive, options.fetch(:build_number))

    output_dir = File.join(CrRelease::RELEASE_DIR, name)
    ipa_name = "record-catch-#{name}.ipa"
    build_app(
      project: CrRelease::PROJECT,
      scheme: app[:scheme],
      skip_build_archive: true,
      archive_path: archive,
      export_method: "app-store",
      output_directory: output_dir,
      output_name: ipa_name,
      export_options: {
        signingStyle: "manual",
        teamID: options.fetch(:team_id),
        # Stop Xcode rewriting CFBundleVersion during export; the N / N.1 values are ours.
        manageAppVersionAndBuildNumber: false,
        provisioningProfiles: { app[:app_identifier] => options.fetch(:profile_name) }
      }
    )

    ipa = File.join(output_dir, ipa_name)
    unzipped = File.join(output_dir, "unzipped")
    sh("unzip", "-q", "-o", ipa, "-d", unzipped)
    exported_app = Dir.glob(File.join(unzipped, "Payload", "*.app")).first || UI.user_error!("No .app in #{ipa}")
    [ipa, exported_app]
  end
end
