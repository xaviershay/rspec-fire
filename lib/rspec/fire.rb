require 'rspec/mocks'
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
      include RecursiveConstMethods

      def initialize(doubled_class_name, method_finder, backing)
        @doubled_class_name = doubled_class_name
        @method_finder      = method_finder
        @backing            = backing
        super(backing)
      end

      def with(*args, &block)
        unless RSpec::Mocks::ArgumentMatchers::AnyArgsMatcher === args.first
          expected_arity = if RSpec::Mocks::ArgumentMatchers::NoArgsMatcher === args.first
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
        if recursive_const_defined?(Object, @doubled_class_name)
          recursive_const_get(Object, @doubled_class_name).send(@method_finder, sym).should have_arity(actual)
        end
      end

      def have_arity(actual)
        RSpec::Matchers::Matcher.new(:have_arity, actual) do |actual|
          match do |method|
            method.arity >= 0 && method.arity == actual
          end

          failure_message_for_should do |method|
            "Wrong number of arguments for #{method.name}. Expected #{method.arity}, got #{actual}."
          end
        end
      end
    end

    class FireDouble < RSpec::Mocks::Mock
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
        ShouldProxy.new(@__doubled_class_name, @__method_finder, super)
      end

      def should_not_receive(method_name)
        ensure_implemented(method_name)
        super
      end

      def stub(method_name)
        ensure_implemented(method_name)
        super
      end

      protected

      def ensure_implemented(*method_names)
        if recursive_const_defined?(Object, @__doubled_class_name)
          recursive_const_get(Object, @__doubled_class_name).
            should implement(method_names, @__checked_methods)
        end
      end

      def implement(expected_methods, checked_methods)
        RSpec::Matchers::Matcher.new(:implement, expected_methods, checked_methods) do |expected_methods, checked_methods|
          unimplemented_methods = lambda {|doubled_class|
            implemented_methods = doubled_class.send(checked_methods)
            expected_methods - implemented_methods.map(&:to_sym) # to_sym for non-1.9 compat
          }

          match do |doubled_class|
            unimplemented_methods[ doubled_class ].empty?
          end

          failure_message_for_should do |doubled_class|
            implemented_methods   = Object.public_methods - doubled_class.send(checked_methods)
            "%s does not implement:\n%s" % [
              doubled_class,
              unimplemented_methods[ doubled_class ].sort.map {|x|
                "  #{x}"
              }.join("\n")
            ]
          end
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

    def fire_double(*args)
      FireObjectDouble.new(*args)
    end

    def fire_class_double(*args)
      FireClassDouble.new(*args)
    end
  end
end
