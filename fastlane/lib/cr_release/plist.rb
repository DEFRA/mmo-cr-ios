module CrRelease
  module Plist
    BUDDY = "/usr/libexec/PlistBuddy".freeze

    module_function

    def read(plist, key)
      CrRelease.sh(BUDDY, "-c", "Print :#{key}", plist, log: false).strip
    end

    def set(plist, key_path, value)
      CrRelease.sh(BUDDY, "-c", "Set :#{key_path} #{value}", plist)
    end

    def set_string(plist, key, value)
      CrRelease.sh(BUDDY, "-c", "Delete :#{key}", plist, log: false, error_callback: ->(_) {})
      CrRelease.sh(BUDDY, "-c", "Add :#{key} string #{value}", plist)
    end

    def read_json(plist, key)
      JSON.parse(CrRelease.sh("plutil", "-extract", key, "json", "-o", "-", plist, log: false))
    end

    def write_json(plist, key, value)
      CrRelease.sh("plutil", "-replace", key, "-json", JSON.generate(value), plist, log: false)
    end
  end
end
