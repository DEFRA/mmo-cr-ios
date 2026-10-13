module CrRelease
  module PackageChecks
    module_function

    # Fails unless the exported package is the expected app, stage config and build, with unchanged compiled code.
    def verify!(exported_app, app:, config:, build_number:, uuids:)
      plist = File.join(exported_app, "Info.plist")
      expected = [app[:app_identifier], build_number]
      actual = %w[CFBundleIdentifier CFBundleVersion].map { |key| Plist.read(plist, key) }
      CrRelease.fail!("Package mismatch: expected #{expected}, got #{actual}") unless actual == expected
      unless Plist.read_json(plist, AppConfig::PLIST_KEY) == config.values
        CrRelease.fail!("#{AppConfig::PLIST_KEY} in the package differs from this Environment's validated config")
      end

      exported_uuids = Archive.mach_o_uuids(exported_app)
      CrRelease.fail!("No Mach-O UUID found in #{exported_app}") if exported_uuids.empty?
      CrRelease.fail!("Compiled code differs: #{exported_uuids} vs #{uuids}") unless exported_uuids == uuids

      CrRelease.sh("codesign", "--verify", "--deep", "--strict", "--verbose=2", exported_app)
    end

    def expect_no_leaks!(exported_app, internal_only_hosts)
      if internal_only_hosts.empty?
        FastlaneCore::UI.important("Internal and external configs share every host; leak check not applicable")
        return
      end
      leaked = leaked_hosts(exported_app, internal_only_hosts)
      CrRelease.fail!("Internal-only hosts found in the external package: #{leaked.join(', ')}") unless leaked.empty?
    end

    def leaked_hosts(app, hosts)
      files = Dir.glob(File.join(app, "**", "*"), File::FNM_DOTMATCH).select { |path| File.file?(path) }
      hosts.select { |host| files.any? { |path| File.binread(path).include?(host) } }
    end
  end
end
