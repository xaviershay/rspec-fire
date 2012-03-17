require 'rspec/mocks'
require 'rspec/expectations'
require 'delegate'

module RSpec
  module Fire
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
      extend RSpec::Matchers::DSL
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
          klass.send(@method_finder, @sym).should have_arity(actual)
        end
      end

      define :have_arity do |actual|
        match do |method|
          method.arity >= 0 && method.arity == actual
        end

        failure_message_for_should do |method|
          "Wrong number of arguments for #{method.name}. " +
            "Expected #{method.arity}, got #{actual}."
        end
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
        ensure_implemented(method_name)
        super
      end

      def with_doubled_class
        if recursive_const_defined?(@__doubled_class_name)
          yield recursive_const_get(@__doubled_class_name)
        end
      end

      protected

      def ensure_implemented(*method_names)
        with_doubled_class do |klass|
          klass.should implement(method_names, @__checked_methods)
        end
      end

      define :implement do |expected_methods, checked_methods|
        unimplemented_methods = lambda {|doubled_class|
          implemented_methods = doubled_class.send(checked_methods)
          # to_sym for non-1.9 compat
          expected_methods - implemented_methods.map(&:to_sym)
        }

        match do |doubled_class|
          unimplemented_methods[ doubled_class ].empty?
        end

        failure_message_for_should do |doubled_class|
          implemented_methods =
            Object.public_methods - doubled_class.send(checked_methods)
          "%s does not implement:\n%s" % [
            doubled_class,
            unimplemented_methods[ doubled_class ].sort.map {|x|
            "  #{x}"
          }.join("\n")
          ]
        end
      end
    end

    class FireObjectDouble < RSpec::Mocks::Mock
      include FireDoublable

      def initialize(doubled_class, *args)
        args << {} unless Hash === args.last

        @__doubled_class_name = doubled_class

        # __declared_as copied from rspec/mocks definition of `double`
        args.last[:__declared_as] = 'FireDouble'
        super
        @__checked_methods = :public_instance_methods
        @__method_finder   = :instance_method
      end
    end

    class FireClassDoubleBuilder
      def self.build(doubled_class, stubs = {})
        Module.new do
          extend FireDoublable

          @__doubled_class_name = doubled_class
          @__checked_methods = :public_methods
          @__method_finder   = :method

          stubs.each do |message, response|
            stub(message).and_return(response)
          end

          def self.as_replaced_constant(options = {})
            @__original_class = ConstantStubber.stub!(@__doubled_class_name, self, options)
            extend AsReplacedConstant
            self
          end

          def self.to_s
            @__doubled_class_name + " (fire double)"
          end

          def self.name
            @__doubled_class_name
          end

          def self.method_missing(name, *args)
            __mock_proxy.raise_unexpected_message_error(name, *args)
          end
        end
      end

      module AsReplacedConstant
        def with_doubled_class
          yield @__original_class if @__original_class
        end
      end
    end

    class ConstantStubber
      extend RecursiveConstMethods

      class DefinedConstantReplacer
        include RecursiveConstMethods
        attr_reader :original_value

        def initialize(full_constant_name, stubbed_value, transfer_nested_constants)
          @full_constant_name        = full_constant_name
          @stubbed_value             = stubbed_value
          @transfer_nested_constants = transfer_nested_constants
        end

        def stub!
          context_parts = @full_constant_name.split('::')
          @const_name = context_parts.pop
          @context = recursive_const_get(context_parts.join('::'))
          @original_value = @context.const_get(@const_name)

          constants_to_transfer = verify_constants_to_transfer!

          @context.send(:remove_const, @const_name)
          @context.const_set(@const_name, @stubbed_value)

          transfer_nested_constants(constants_to_transfer)
        end

        def rspec_reset
          if recursive_const_get(@full_constant_name).equal?(@stubbed_value)
            @context.send(:remove_const, @const_name)
            @context.const_set(@const_name, @original_value)
          end
        end

        def transfer_nested_constants(constants)
          constants.each do |const|
            @stubbed_value.const_set(const, original_value.const_get(const))
          end
        end

        def verify_constants_to_transfer!
          return [] unless @transfer_nested_constants

          { @original_value => "the original value", @stubbed_value => "the stubbed value" }.each do |value, description|
            unless value.respond_to?(:constants)
              raise ArgumentError,
                "Cannot transfer nested constants for #{@full_constant_name} " +
                "since #{description} is not a class or module and only classes " +
                "and modules support nested constants."
            end
          end

          if @transfer_nested_constants.is_a?(Array)
            @transfer_nested_constants = @transfer_nested_constants.map(&:to_s) if RUBY_VERSION == '1.8.7'
            undefined_constants = @transfer_nested_constants - @original_value.constants

            if undefined_constants.any?
              available_constants = @original_value.constants - @transfer_nested_constants
              raise ArgumentError,
                "Cannot transfer nested constant(s) #{undefined_constants.join(' and ')} " +
                "for #{@full_constant_name} since they are not defined. Did you mean " +
                "#{available_constants.join(' or ')}?"
            end

            @transfer_nested_constants
          else
            @original_value.constants
          end
        end
      end

      class UndefinedConstantSetter
        include RecursiveConstMethods

        def initialize(full_constant_name, stubbed_value)
          @full_constant_name = full_constant_name
          @stubbed_value      = stubbed_value
        end

        def original_value
          # always nil
        end

        def stub!
          context_parts = @full_constant_name.split('::')
          const_name = context_parts.pop

          remaining_parts = context_parts.dup
          @deepest_defined_const = context_parts.inject(Object) do |klass, name|
            break klass unless klass.const_defined?(name)
            remaining_parts.shift
            klass.const_get(name)
          end

          context = remaining_parts.inject(@deepest_defined_const) do |klass, name|
            klass.const_set(name, Module.new)
          end

          @const_to_remove = remaining_parts.first || const_name
          context.const_set(const_name, @stubbed_value)
        end

        def rspec_reset
          if recursive_const_get(@full_constant_name).equal?(@stubbed_value)
            @deepest_defined_const.send(:remove_const, @const_to_remove)
          end
        end
      end

      def self.stub!(constant_name, value, options = {})
        stubber = if recursive_const_defined?(constant_name)
          DefinedConstantReplacer.new(constant_name, value, options[:transfer_nested_constants])
        else
          UndefinedConstantSetter.new(constant_name, value)
        end

        stubber.stub!
        ::RSpec::Mocks.space.add(stubber)
        stubber.original_value
      end
    end

    def stub_const(name, value, options = {})
      ConstantStubber.stub!(name, value, options)
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
