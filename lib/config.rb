require "json"

module Swift
  module Marathon
    class Config
      def initialize
        config_file = "config.json"
        if File.readable?(config_file)
          config_file_contents = File.open(config_file, "r").read
          begin
            @config = JSON.parse(config_file_contents, :symbolize_names => true)
          rescue JSON::ParserError => error
            raise "Config file must be valid JSON: #{error}"
          end
        else
          raise "Config file does not exist or is not readable: #{config_file}"
        end
      end

      def read
        @config
      end
    end
  end
end
