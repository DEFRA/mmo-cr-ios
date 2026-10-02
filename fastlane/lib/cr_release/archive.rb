module CrRelease
  module Archive
    UUID_PATTERN = /UUID: ([0-9A-F-]+) \((\w+)\)/

    module_function

    def app_path(archive)
      Dir.glob(File.join(archive, "Products", "Applications", "*.app")).first ||
        CrRelease.fail!("No .app found in #{archive}")
    end

    def app_plist(archive)
      File.join(app_path(archive), "Info.plist")
    end

    def expect_app!(archive, app)
      archived_id = Plist.read(app_plist(archive), "CFBundleIdentifier")
      return if archived_id == app[:app_identifier]

      CrRelease.fail!("Archive is #{archived_id}, expected #{app[:app_identifier]}")
    end

    def set_build_number(archive, build_number)
      Plist.set(app_plist(archive), "CFBundleVersion", build_number)
      Plist.set(File.join(archive, "Info.plist"), "ApplicationProperties:CFBundleVersion", build_number)
    end

    def mach_o_uuids(app)
      executable = File.join(app, Plist.read(File.join(app, "Info.plist"), "CFBundleExecutable"))
      parse_uuids(CrRelease.sh("dwarfdump", "--uuid", executable, log: false))
    end

    def parse_uuids(dwarfdump_output)
      dwarfdump_output.scan(UUID_PATTERN).sort
    end
  end
end
