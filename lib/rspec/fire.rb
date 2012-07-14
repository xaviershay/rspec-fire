require 'rspec/mocks'
require 'rspec/expectations'
require 'delegate'

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

    Error = Class.new(StandardError)
    UndefinedConstantError = Class.new(Error)

    class SupportArityMatcher
      def initialize(arity)
        @arity = arity
      end

      attr_reader :arity, :method

      def matches?(method)
        @method = method
        min_arity <= arity && arity <= max_arity
      end

      def failure_message_for_should
        "Wrong number of arguments for #{method.name}. " +
          "Expected #{arity_description}, got #{arity}."
      end

    private

      INFINITY = 1/0.0

      if method(:method).respond_to?(:parameters)
        def max_arity
          params = method.parameters
          return INFINITY if params.any? { |(type, name)| type == :rest } # splat
          params.count { |(type, name)| type != :block }
        end
      else
        # On 1.8, Method#parameters does not exist.
        # There's no way to distinguish between default and splat args, so
        # there's no way to have it work correctly for both default and splat args,
        # as far as I can tell.
        # The best we can do is consider it INFINITY (to be tolerant of splat args).
        def max_arity
          method.arity < 0 ? INFINITY : method.arity
        end
      end

      def min_arity
        return method.arity if method.arity >= 0
        # ~ inverts the one's complement and gives us the number of required args
        ~method.arity
      end

      def arity_description
        return min_arity if min_arity == max_arity
        return "#{min_arity} or more" if max_arity == INFINITY
        "#{min_arity} to #{max_arity}"
      end
    end

    module RecursiveConstMethods
      def recursive_const_get name
        name.split('::').inject(Object) {|klass,name| klass.const_get name }
      end

      def recursive_const_defined? name
        !!name.split('::').inject(Object) {|klass,name|
          if klass && klass.const_defined?(name)
            klass.const_get name
          end
        }
      end
    end

    class ShouldProxy < SimpleDelegator
      include RecursiveConstMethods

      AM = RSpec::Mocks::ArgumentMatchers

      def initialize(double, method_finder, backing)
        @double             = double
        @method_finder      = method_finder
        @backing            = backing
        @sym = backing.respond_to?(:sym) ? @backing.sym : @backing.message
        super(backing)
      end

      def with(*args, &block)
        unless AM::AnyArgsMatcher === args.first
          expected_arity = if AM::NoArgsMatcher === args.first
            0
          elsif args.length > 0
            args.length
          elsif block
            block.arity
          else
            raise ArgumentError.new("No arguments nor block given.")
          end
          ensure_arity(expected_arity)
        end
        __getobj__.with(*args, &block)
      end

      protected

      def ensure_arity(actual)
        @double.with_doubled_class do |klass|
          klass.send(@method_finder, @sym).should support_arity(actual)
        end
      end

      def support_arity(arity)
        SupportArityMatcher.new(arity)
      end
    end

    module FireDoublable
      extend RSpec::Matchers::DSL
      include RecursiveConstMethods

      def should_receive(method_name)
        ensure_implemented(method_name)
        ShouldProxy.new(self, @__method_finder, super)
      end

      def should_not_receive(method_name)
        ensure_implemented(method_name)
        super
      end

      def stub(method_name)
        ensure_implemented(method_name) unless method_name.is_a?(Hash)
        super
      end

      def stub!(method_name)
        stub(method_name)
      end

      def with_doubled_class
        ::RSpec::Fire.find_original_value_for(@__doubled_class_name) do |value|
          yield value if value
          return
        end

        if recursive_const_defined?(@__doubled_class_name)
          yield recursive_const_get(@__doubled_class_name)
        end
      end

      protected

      # This cache gives a decent speed up when a class is doubled a lot.
      def implemented_methods(doubled_class, checked_methods)
        @@_implemented_methods_cache ||= {}

        # to_sym for non-1.9 compat
        @@_implemented_methods_cache[[doubled_class, checked_methods]] ||=
          doubled_class.send(checked_methods).map(&:to_sym)
      end

      def unimplemented_methods(doubled_class, expected_methods, checked_methods)
        expected_methods.map(&:to_sym) -
          implemented_methods(doubled_class, checked_methods)
      end

      def ensure_implemented(*method_names)
        with_doubled_class do |doubled_class|
          methods = unimplemented_methods(
            doubled_class,
            method_names,
            @__checked_methods
          )

          if methods.any?
            implemented_methods =
              Object.public_methods -
                implemented_methods(doubled_class, @__checked_methods)

            msg = "%s does not implement:\n%s" % [
              doubled_class,
              methods.sort.map {|x|
                "  #{x}"
              }.join("\n")

            ]
            raise RSpec::Expectations::ExpectationNotMetError, msg
          end
        end
      end

      def verify_constant_name
        return if recursive_const_defined?(@__doubled_class_name)

        raise UndefinedConstantError, "#{@__doubled_class_name} is not a defined constant."
      end
    end

    class FireObjectDouble < RSpec::Mocks::Mock
      include FireDoublable

      def initialize(doubled_class, *args)
        args << {} unless Hash === args.last

        @__doubled_class_name = doubled_class
        verify_constant_name if RSpec::Fire.configuration.verify_constant_names?

        # __declared_as copied from rspec/mocks definition of `double`
        args.last[:__declared_as] = 'FireDouble'

        @__checked_methods = :public_instance_methods
        @__method_finder   = :instance_method

        super
      end
    end

    class FireClassDoubleBuilder
      def self.build(doubled_class, stubs = {})
        Module.new do
          extend FireDoublable

          @__doubled_class_name = doubled_class
          @__checked_methods = :public_methods
          @__method_finder   = :method

          verify_constant_name if RSpec::Fire.configuration.verify_constant_names?

          # TestDouble was added after rspec 2.9.0, and allows proper mocking
          # of public methods that have clashing private methods. See spec for
          # details.
          if defined?(::RSpec::Mocks::TestDouble)
            ::RSpec::Mocks::TestDouble.extend_onto self,
              doubled_class, stubs.merge(:__declared_as => "FireClassDouble")
          else
            stubs.each do |message, response|
              stub(message).and_return(response)
            end

            def self.method_missing(name, *args)
              __mock_proxy.raise_unexpected_message_error(name, *args)
            end
          end

          def self.as_replaced_constant(options = {})
            RSpec::Mocks::ConstantStubber.stub(@__doubled_class_name, self, options)
            @__original_class = RSpec::Mocks::Constant.original(@__doubled_class_name).original_value

            extend AsReplacedConstant
            self
          end

          def self.to_s
            @__doubled_class_name + " (fire double)"
          end

          def self.inspect
            to_s
          end

          def self.name
            @__doubled_class_name
          end
        end
      end

      module AsReplacedConstant
        def with_doubled_class
          yield @__original_class if @__original_class
        end
      end
    end

    def self.find_original_value_for(constant_name)
      const = ::RSpec::Mocks::Constant.original(constant_name)
      yield const.original_value if const.stubbed?
    end

    def fire_double(*args)
      FireObjectDouble.new(*args)
    end

    def fire_class_double(*args)
      FireClassDoubleBuilder.build(*args)
    end

    def fire_replaced_class_double(*args)
      fire_class_double(*args).as_replaced_constant
    end
  end
end
