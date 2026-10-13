module CrRelease
  PROJECT = "record-catch.xcodeproj".freeze
  SCHEME = "record-catch".freeze
  SIMULATOR = "iPhone 17".freeze
  RELEASE_DIR = File.expand_path("../../../build/release", __dir__).freeze
  ARCHIVE_PATH = File.join(RELEASE_DIR, "record-catch.xcarchive").freeze
  UUIDS_PATH = File.join(RELEASE_DIR, "mach-o-uuids.json").freeze

  # Test and Prod join this table once their xcconfig files and schemes exist.
  APPS = {
    dev: { app_identifier: "mmo.catchrecordingdev.ios", scheme: SCHEME, configuration: "Release" }
  }.freeze

  module_function

  def app!(key)
    APPS.fetch(key.to_s.to_sym) { fail!("Unknown app '#{key}'. Known: #{APPS.keys.join(', ')}") }
  end
end
