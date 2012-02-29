require 'rspec/mocks'
require 'rspec/expectations'
require 'delegate'

module RSpec
  module Fire
    module RecursiveConstMethods
      def recursive_const_get object, name
        name.split('::').inject(Object) {|klass,name| klass.const_get name }
      end

      def recursive_const_defined? object, name
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
          klass.send(@method_finder, sym).should have_arity(actual)
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

    class FireDouble < RSpec::Mocks::Mock
      extend RSpec::Matchers::DSL
      include RecursiveConstMethods

      def initialize(doubled_class, *args)
        args << {} unless Hash === args.last

        @__doubled_class_name = doubled_class

        # __declared_as copied from rspec/mocks definition of `double`
        args.last[:__declared_as] = 'FireDouble'
        super(doubled_class, *args)
      end

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
        if recursive_const_defined?(Object, @__doubled_class_name)
          yield recursive_const_get(Object, @__doubled_class_name)
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

    class FireObjectDouble < FireDouble
      def initialize(*args)
        super
        @__checked_methods = :public_instance_methods
        @__method_finder   = :instance_method
      end
    end

    class FireClassDouble < FireDouble
      def initialize(*args)
        super
        @__checked_methods = :public_methods
        @__method_finder   = :method
      end
    end

    class FireReplacedClassDouble < FireClassDouble
      def initialize(*args)
        super

        if recursive_const_defined?(Object, @__doubled_class_name)
          __replace_defined_constant
        else
          __set_undefined_constant
        end

        ::RSpec::Mocks.space.add(self)
      end

      def with_doubled_class
        yield @__orig_class if @__orig_class
      end

      def rspec_reset
        super
        @__resetter.call
      end

    private

      def __replace_defined_constant
        *context_parts, const_name = @__doubled_class_name.split('::')
        context = recursive_const_get(Object, context_parts.join('::'))
        @__orig_class = context.send(:remove_const, const_name)
        context.const_set(const_name, self)

        @__resetter = lambda do
          context.send(:remove_const, const_name)
          context.const_set(const_name, @__orig_class)
        end
      end

      def __set_undefined_constant
        @__orig_class = nil
        *context_parts, const_name = @__doubled_class_name.split('::')

        remaining_parts = context_parts.dup
        deepest_defined_const = context_parts.inject(Object) do |klass, name|
          break klass unless klass.const_defined?(name)
          remaining_parts.shift
          klass.const_get(name)
        end

        context = remaining_parts.inject(deepest_defined_const) do |klass, name|
          klass.const_set(name, Module.new)
        end

        @__resetter = lambda { deepest_defined_const.send(:remove_const, remaining_parts.first) }
        context.const_set(const_name, self)
      end
    end

    def fire_double(*args)
      FireObjectDouble.new(*args)
    end

    def fire_class_double(*args)
      FireClassDouble.new(*args)
    end

    def fire_replaced_class_double(*args)
      FireReplacedClassDouble.new(*args)
    end
  end
end
