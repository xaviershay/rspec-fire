module RSpec
  module Fire
    class Configuration
      attr_accessor :verify_constant_names
      alias verify_constant_names? verify_constant_names

      def initialize
        self.verify_constant_names = false
      end
    end

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield configuration
    end
  end
end
