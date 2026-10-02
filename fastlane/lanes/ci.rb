platform :ios do
  desc "Compile the app and test bundle without running tests — the CI compile gate."
  lane :build do
    run_tests(
      project: CrRelease::PROJECT,
      scheme: CrRelease::SCHEME,
      devices: [CrRelease::SIMULATOR],
      build_for_testing: true,
      skip_testing: ["record-catchUITests"],
      derived_data_path: "DerivedData"
    )
  end

  desc "Build and run the unit tests with code coverage (used by CI). UI tests are excluded for now."
  lane :test do
    run_tests(
      project: CrRelease::PROJECT,
      scheme: CrRelease::SCHEME,
      devices: [CrRelease::SIMULATOR],
      skip_testing: ["record-catchUITests"],
      code_coverage: true,
      result_bundle: true,
      output_directory: "fastlane/test_output",
      derived_data_path: "DerivedData"
    )
  end
end
