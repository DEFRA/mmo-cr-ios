module CrRelease
  module TestFlight
    module_function

    # Needs the App Store Connect API key to be set first.
    def build_exists?(app_identifier, version, build_number)
      asc_app = Spaceship::ConnectAPI::App.find(app_identifier) ||
                CrRelease.fail!("No App Store Connect app for #{app_identifier}")
      !Spaceship::ConnectAPI::Build.all(app_id: asc_app.id, version: version, build_number: build_number).first.nil?
    end
  end
end
