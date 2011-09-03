require 'rspec/mocks'

module RSpec
  module Fire
    class FireDouble < RSpec::Mocks::Mock
      def initialize(doubled_class, *args)
        args << {} unless Hash === args.last

        @__doubled_class_name = doubled_class
        @__checked_methods    = :public_instance_methods

        # __declared_as copied from rspec/mocks definition of `double`
        args.last[:__declared_as] = 'FireDouble'
        super(doubled_class, *args)
      end

      def should_receive(method_name)
        ensure_implemented(method_name)
        super
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

      def implement(expected_methods, checked_methods)
        RSpec::Matchers::Matcher.new(:implement, expected_methods, checked_methods) do |expected_methods, checked_methods|
          unimplemented_methods = lambda {|doubled_class|
            implemented_methods = doubled_class.send(checked_methods)
            expected_methods - implemented_methods
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

    def fire_double(*args)
      FireDouble.new(*args)
    end
  end
end
