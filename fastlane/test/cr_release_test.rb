require "minitest/autorun"
require "tmpdir"
require_relative "../lib/cr_release"

# Pure release logic; runs without macOS tools.
class CrReleaseTest < Minitest::Test
  UserError = FastlaneCore::Interface::FastlaneError

  def test_known_app_resolves_from_string_or_symbol
    assert_equal "mmo.catchrecordingdev.ios", CrRelease.app!("dev")[:app_identifier]
    assert_equal CrRelease.app!(:dev), CrRelease.app!("dev")
  end

  def test_unknown_app_fails_with_known_list
    error = assert_raises(UserError) { CrRelease.app!("staging") }
    assert_match(/Unknown app 'staging'. Known: dev/, error.message)
  end

  def test_release_paths_sit_under_the_repository_build_folder
    assert CrRelease::RELEASE_DIR.end_with?("/build/release")
    assert File.directory?(File.expand_path("..", File.dirname(CrRelease::RELEASE_DIR)) + "/fastlane")
  end

  def test_release_tag_gives_version_and_build
    assert_equal ["2.0.0", "14"], CrRelease::ReleaseTag.parse!("v2.0.0-BUILD_14")
    assert_equal ["1", "3"], CrRelease::ReleaseTag.parse!("v1-BUILD_3")
  end

  def test_release_tag_rejects_branches_and_malformed_tags
    [nil, "main", "v2.0.0", "v2.0.0-BUILD_14.1", "2.0.0-BUILD_14", "v2.0.0-BUILD_14x"].each do |ref|
      error = assert_raises(UserError) { CrRelease::ReleaseTag.parse!(ref) }
      assert_match(/Run on a release tag/, error.message)
    end
  end

  def test_uuids_are_parsed_per_architecture_and_sorted
    output = "UUID: BBBB-2222 (x86_64) /x/App\nUUID: AAAA-1111 (arm64) /x/App\n"
    assert_equal [%w[AAAA-1111 arm64], %w[BBBB-2222 x86_64]], CrRelease::Archive.parse_uuids(output)
    assert_empty CrRelease::Archive.parse_uuids("no uuids here")
  end

  def test_signing_xcargs_force_manual_distribution_signing
    assert_equal 'DEVELOPMENT_TEAM=T1 CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Distribution" ' \
                 'PROVISIONING_PROFILE_SPECIFIER="match AppStore x"',
                 CrRelease::Signing.xcargs("T1", "match AppStore x")
  end

  def test_missing_signing_identity_fails
    assert_nil CrRelease::Signing.expect_identity!("  1) ABC \"Apple Distribution: X\"\n     1 valid identities found")
    error = assert_raises(UserError) { CrRelease::Signing.expect_identity!("     0 valid identities found") }
    assert_match(/unencrypted PEM key/, error.message)
  end

  def test_leaked_hosts_finds_hosts_in_any_file_including_hidden_and_binary
    Dir.mktmpdir do |app|
      File.write(File.join(app, "Info.plist"), "https://prod.example.gov.uk")
      FileUtils.mkdir_p(File.join(app, "Frameworks", ".hidden"))
      File.binwrite(File.join(app, "Frameworks", ".hidden", "blob"), "\x00\x01int.example.gov.uk\x02".b)

      assert_equal ["int.example.gov.uk"],
                   CrRelease::PackageChecks.leaked_hosts(app, %w[int.example.gov.uk uat.example.gov.uk])
      assert_empty CrRelease::PackageChecks.leaked_hosts(app, ["uat.example.gov.uk"])
    end
  end
end
