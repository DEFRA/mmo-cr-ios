require "json"
require "uri"

module CrRelease
  # Stage configuration: GitHub Environment variables CR_APP_CFG_<KEY>, allow-listed by Config/app-config.schema.json,
  # packaged as the MMOCRAppConfig Info.plist dictionary.
  module AppConfig
    PREFIX = "CR_APP_CFG_".freeze
    PLIST_KEY = "MMOCRAppConfig".freeze
    SCHEMA_PATH = File.expand_path("../../../Config/app-config.schema.json", __dir__).freeze
    TYPES = %w[url string bool].freeze
    SPEC_FIELDS = %w[type required log tracking description].freeze
    KEY_PATTERN = /\A[A-Z][A-Z0-9_]*\z/
    SECRET_WORDS = %w[SECRET PASSWORD TOKEN PRIVATE CREDENTIAL].freeze
    MAX_URL_LENGTH = 2048
    MAX_STRING_LENGTH = 512

    class Config
      attr_reader :values, :unknown

      def initialize(schema, values, unknown)
        @schema = schema
        @values = values
        @unknown = unknown
      end

      def loggable
        @values.to_h { |key, value| [key, @schema.fetch(key).fetch("log", true) ? value : "(not logged)"] }
      end

      def url_hosts(values = @values)
        values.filter_map do |key, value|
          URI.parse(value).host if @schema.dig(key, "type") == "url"
        end.uniq
      end
    end

    module_function

    # The validated config of this job's GitHub Environment, from CR_APP_CFG_VARS = toJSON(vars).
    def from_env!(vars_json)
      config = resolve(load_schema, vars_json)
      config.unknown.each { |name| FastlaneCore::UI.important("Ignoring #{name}: not declared in Config/app-config.schema.json") }
      config.loggable.each { |key, value| FastlaneCore::UI.message("App config #{key}: #{value}") }
      config
    rescue Error => e
      CrRelease.fail!(e.message)
    end

    def load_schema(path = SCHEMA_PATH)
      build_schema(JSON.parse(File.read(path)))
    rescue JSON::ParserError, Errno::ENOENT => e
      raise Error, "Cannot read #{File.basename(path)}: #{e.class}"
    end

    def build_schema(raw)
      keys = raw.is_a?(Hash) ? raw["keys"] : nil
      raise Error, "App config schema must have a \"keys\" object" unless keys.is_a?(Hash)

      errors = keys.flat_map { |name, spec| spec_errors(name, spec) }
      raise Error, "Invalid app config schema: #{errors.join('; ')}" unless errors.empty?

      keys
    end

    def spec_errors(name, spec)
      return ["#{name}: must be an object"] unless spec.is_a?(Hash)

      errors = []
      errors << "#{name}: must match #{KEY_PATTERN.source}" unless name.match?(KEY_PATTERN)
      if (word = SECRET_WORDS.find { |w| name.include?(w) })
        errors << "#{name}: contains #{word}; secrets must never be packaged in the app"
      end
      errors << "#{name}: unknown fields #{(spec.keys - SPEC_FIELDS).join(', ')}" unless (spec.keys - SPEC_FIELDS).empty?
      errors << "#{name}: type must be one of #{TYPES.join(', ')}" unless TYPES.include?(spec["type"])
      errors << "#{name}: required must be true or false" unless [true, false].include?(spec["required"])
      errors << "#{name}: log must be true or false" unless [nil, true, false].include?(spec["log"])
      errors << "#{name}: tracking must be true or false" unless [nil, true, false].include?(spec["tracking"])
      errors << "#{name}: tracking domains belong in the privacy manifest, not stage config" if spec["tracking"] == true
      errors << "#{name}: description is required" if spec["description"].to_s.strip.empty?
      errors
    end

    # vars_json is toJSON(vars): every variable visible to the job. Error messages never include values.
    def resolve(schema, vars_json)
      vars = JSON.parse(vars_json.to_s.strip.empty? ? "{}" : vars_json)
      raise Error, "CR_APP_CFG_VARS must be a JSON object" unless vars.is_a?(Hash)

      candidates = vars.select { |name, _| name.start_with?(PREFIX) }.transform_keys { |name| name.delete_prefix(PREFIX) }
      values = {}
      errors = []
      schema.each do |key, spec|
        raw = candidates[key].to_s.strip
        if raw.empty?
          errors << "#{PREFIX}#{key} is required; set it as a variable on this GitHub Environment" if spec["required"]
          next
        end
        value, error = parse_value(spec["type"], raw)
        if error
          errors << "#{PREFIX}#{key} #{error}"
        else
          values[key] = value
        end
      end
      raise Error, errors.join("; ") unless errors.empty?

      Config.new(schema, values, (candidates.keys - schema.keys).sort.map { |key| PREFIX + key })
    rescue JSON::ParserError
      raise Error, "CR_APP_CFG_VARS is not valid JSON"
    end

    def parse_value(type, raw)
      case type
      when "url" then parse_url(raw)
      when "bool" then %w[true false].include?(raw) ? [raw == "true", nil] : [nil, "must be true or false"]
      else
        return [nil, "must be a single line"] if raw.match?(/[\r\n]/)
        return [nil, "must be at most #{MAX_STRING_LENGTH} characters"] if raw.length > MAX_STRING_LENGTH

        [raw, nil]
      end
    end

    def parse_url(raw)
      return [nil, "must be at most #{MAX_URL_LENGTH} characters"] if raw.length > MAX_URL_LENGTH

      uri = URI.parse(raw)
      return [nil, "must be an https:// URL with a host"] unless uri.is_a?(URI::HTTPS) && !uri.host.to_s.empty?
      return [nil, "must not contain a user name or password"] if uri.userinfo

      [raw, nil]
    rescue URI::InvalidURIError
      [nil, "is not a valid URL"]
    end
  end
end
