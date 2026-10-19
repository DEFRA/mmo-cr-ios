module CrRelease
  module Signing
    module_function

    def xcargs(team_id, profile_name)
      [
        "DEVELOPMENT_TEAM=#{team_id}",
        "CODE_SIGN_STYLE=Manual",
        "CODE_SIGN_IDENTITY=\"Apple Distribution\"",
        "PROVISIONING_PROFILE_SPECIFIER=\"#{profile_name}\""
      ].join(" ")
    end

    # Match reports success even when the private key fails to import; catch it here, not deep inside xcodebuild.
    def expect_identity!(find_identity_output)
      return unless find_identity_output.include?("0 valid identities found")

      CrRelease.fail!("Signing certificate installed without its private key: the key in the Match repo must be " \
                      "an unencrypted PEM key")
    end
  end
end
