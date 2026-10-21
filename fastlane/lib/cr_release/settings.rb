module CrRelease
  PROJECT = "record-catch.xcodeproj".freeze
  SCHEME = "record-catch".freeze
  SIMULATOR = "iPhone 17".freeze
  RELEASE_DIR = File.expand_path("../../../build/release", __dir__).freeze
  ARCHIVE_PATH = File.join(RELEASE_DIR, "record-catch.xcarchive").freeze
  UUIDS_PATH = File.join(RELEASE_DIR, "mach-o-uuids.json").freeze

  # Identity is set at compile time by build-setting overrides (ADR-0020 amendment); nil display name keeps PRODUCT_NAME.
  APPS = {
    dev: { app_identifier: "mmo.catchrecordingdev.ios", display_name: "CR Dev", scheme: SCHEME,
           configuration: "Release", external_on_upload: true },
    test: { app_identifier: "mmo.catchrecordingtest.ios", display_name: "CR Test", scheme: SCHEME,
            configuration: "Release" },
    prod: { app_identifier: "mmo.catchrecording.ios", display_name: nil, scheme: SCHEME, configuration: "Release",
            app_store: true }
  }.freeze

  module_function

  def app!(key)
    APPS.fetch(key.to_s.to_sym) { fail!("Unknown app '#{key}'. Known: #{APPS.keys.join(', ')}") }
  end

  def expect_archive!
    return ARCHIVE_PATH if File.directory?(ARCHIVE_PATH) && File.file?(UUIDS_PATH)

    fail!("No archive in #{RELEASE_DIR}; download and decrypt this run's archive artifact first")
  end
end
