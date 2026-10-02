platform :ios do
  desc "Sync every app's signing assets from the Match repo into the local keychain (read-only)."
  lane :certificates do
    match(
      type: "appstore",
      app_identifier: CrRelease::APPS.values.map { |app| app[:app_identifier] },
      readonly: true
    )
  end

  desc "App Store Connect API key from the Environment's ASC_* secrets."
  private_lane :asc_api_key do
    app_store_connect_api_key(
      key_id: ENV.fetch("ASC_KEY_ID"),
      issuer_id: ENV.fetch("ASC_ISSUER_ID"),
      key_content: ENV.fetch("ASC_KEY_CONTENT"),
      is_key_content_base64: true
    )
  end

  desc "Temporary keychain + read-only Match for one app; returns its App Store profile name."
  private_lane :sync_signing do |options|
    app_identifier = options.fetch(:app_identifier)
    setup_ci
    match(
      type: "appstore",
      app_identifier: app_identifier,
      readonly: true,
      api_key: options.fetch(:api_key),
      # Path to the SSH deploy key written by the workflow; nil locally, where the agent's key is used.
      git_private_key: ENV["MATCH_GIT_PRIVATE_KEY"]
    )
    CrRelease::Signing.expect_identity!(sh("security", "find-identity", "-v", "-p", "codesigning", log: false))
    (lane_context[SharedValues::MATCH_PROVISIONING_PROFILE_MAPPING] || {})[app_identifier] ||
      ENV.fetch("sigh_#{app_identifier}_appstore_profile-name")
  end
end
