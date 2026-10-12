require "minitest/autorun"
require "plist"
require "xcodeproj"
require_relative "../lib/cr_release"

# The app configuration standard (ADR-0020): stage values never in git, templates only in Config/.
class ProjectConfigTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  APP_TARGET = "record-catch".freeze
  RELEASE_TEMPLATE = "Config/Info.plist".freeze
  DEBUG_TEMPLATE = "Config/Info-Debug.plist".freeze
  IDENTITY_XCCONFIGS = %w[Base.xcconfig Dev.xcconfig Test.xcconfig Prod.xcconfig].freeze

  def template(path)
    Plist.parse_xml(File.join(ROOT, path))
  end

  def app_configurations
    project = Xcodeproj::Project.open(File.join(ROOT, "record-catch.xcodeproj"))
    project.targets.find { |target| target.name == APP_TARGET }.build_configurations
  end

  def test_templates_declare_exactly_the_schema_keys
    expected = CrRelease::AppConfig.load_schema.keys.to_h { |key| [key, "$(#{CrRelease::AppConfig::PREFIX}#{key})"] }
    [RELEASE_TEMPLATE, DEBUG_TEMPLATE].each do |path|
      assert_equal expected, template(path)[CrRelease::AppConfig::PLIST_KEY], "#{path} is out of step with the schema"
    end
  end

  def test_release_template_has_no_transport_exceptions
    refute template(RELEASE_TEMPLATE).key?("NSAppTransportSecurity")
  end

  def test_debug_template_only_allows_plain_http_to_localhost
    ats = template(DEBUG_TEMPLATE).fetch("NSAppTransportSecurity")
    assert_equal ["NSExceptionDomains"], ats.keys
    assert_equal({ "localhost" => { "NSExceptionAllowsInsecureHTTPLoads" => true } }, ats["NSExceptionDomains"])
  end

  def test_no_info_plist_templates_inside_the_app_folder
    assert_empty Dir.glob(File.join(ROOT, "record-catch", "**", "Info*.plist"))
  end

  def test_committed_xcconfigs_are_identity_files_without_stage_values
    committed = Dir.glob(File.join(ROOT, "Config", "*.xcconfig")).reject { |path| path.end_with?("/Local.xcconfig") }
    committed.each do |path|
      assert_includes IDENTITY_XCCONFIGS, File.basename(path)
      refute_match(/^\s*(#{CrRelease::AppConfig::PREFIX}|API_BASE_URL)/, File.read(path), "#{path} sets a stage value")
    end
  end

  def test_every_app_configuration_uses_the_config_folder_standard
    app_configurations.each do |config|
      debug = config.name.start_with?("Debug")
      settings = config.build_settings
      assert_equal "Base.xcconfig", config.base_configuration_reference&.path, config.name
      assert_equal (debug ? DEBUG_TEMPLATE : RELEASE_TEMPLATE), settings["INFOPLIST_FILE"], config.name
      assert_equal "YES", settings["GENERATE_INFOPLIST_FILE"], config.name
      assert_equal debug, settings.key?("INFOPLIST_KEY_NSLocalNetworkUsageDescription"),
                   "#{config.name}: the local-network prompt is for Debug builds only"
    end
  end
end
