module CrRelease
  module ReleaseTag
    PATTERN = /\Av(?<version>\d+(?:\.\d+)*)-BUILD_(?<build>\d+)\z/

    module_function

    # [marketing version, build N]; validate-release-tag.sh has already matched the tag to the code.
    def parse!(ref_name)
      match = ref_name.to_s.match(PATTERN)
      CrRelease.fail!("Run on a release tag v<version>-BUILD_<N>, not '#{ref_name}'") unless match
      [match[:version], match[:build]]
    end
  end
end
