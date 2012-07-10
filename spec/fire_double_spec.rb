require 'spec_helper'

def use; end
private :use

module TestMethods
  def defined_method
    raise "Y U NO MOCK?"
  end

  def defined_method_one_arg(arg1)
    raise "Y U NO MOCK?"
  end
end

class TestObject
  include TestMethods
end

class TestClass
  include TestMethods
  extend TestMethods

  M = :m
  N = :n

  def self.use
    raise "Y U NO MOCK?"
  end
end

shared_examples_for "verifying named constants" do |double_method|
  def clear_config
    RSpec::Fire.instance_variable_set(:@configuration, nil)
  end

  before(:each) { clear_config }
  after(:all)   { clear_config }

  it "allows mispelled constants by default" do
    double = send(double_method, "TestClas")
    double.should_receive(:undefined_method)
    double.undefined_method
  end

  it "raises an error when constants are mispelled and the appropriate config option is set" do
    RSpec::Fire.configure do |c|
      c.verify_constant_names = true
    end

    expect {
      send(double_method, "TestClas")
    }.to raise_error(/TestClas is not a defined constant/)
  end
end

shared_examples_for 'a fire-enhanced double method' do
  describe 'doubled class is not loaded' do
    let(:doubled_object) { fire_double("UnloadedObject") }
    should_allow(:undefined_method)
  end

  describe 'doubled class is loaded' do
    should_allow(:defined_method)
    should_not_allow(:undefined_method)
  end
end

shared_examples_for 'a fire-enhanced double' do
  def self.should_allow(method_parameters)
    method_to_stub = method_parameters.is_a?(Hash) ?
      method_parameters.keys.first : method_parameters

    it "should allow #{method_to_stub}" do
      lambda {
        doubled_object.send(method_under_test, method_parameters)
      }.should_not raise_error
      doubled_object.rspec_reset
    end
  end

  def self.should_not_allow(method_parameters)
    method_to_stub = method_parameters.is_a?(Hash) ?
      method_parameters.keys.first : method_parameters

    it "should not allow #{method_to_stub}" do
      lambda {
        doubled_object.send(method_under_test, method_parameters)
      }.should fail_matching("does not implement", method_to_stub)
    end
  end

  describe '#should_receive' do
    let(:method_under_test) { :should_receive }
    it_should_behave_like 'a fire-enhanced double method'

    describe '#with' do
      it 'should delegate to RSpec #with method' do
        doubled_object.
          should_receive(:defined_method_one_arg).
          with(1).
          and_return(:value)
        doubled_object.defined_method_one_arg(1).should == :value

        doubled_object.
          should_receive(:defined_method_one_arg).
          with(2) {|x| x + 1 }
        doubled_object.defined_method_one_arg(2).should == 3
      end

      it 'should not allow an arity mismatch for a method with 0 arguments' do
        lambda {
          doubled_object.should_receive(:defined_method).with(:x)
        }.should fail_for_arguments(0, 1)
      end

      it 'should not allow an arity mismatch for a method with 1 argument' do
        lambda {
          doubled_object.should_receive(:defined_method_one_arg).with(:x, :y)
        }.should fail_for_arguments(1, 2)
      end

      it 'should use arity of block when no arguments given' do
        lambda {
          doubled_object.should_receive(:defined_method_one_arg).with {|x, y| }
        }.should fail_for_arguments(1, 2)
      end

      it 'should raise argument error when no arguments or block given' do
        lambda {
          doubled_object.should_receive(:defined_method_one_arg).with
        }.should raise_error(ArgumentError)
      end

      it 'should recognize no_args param as 0 arity and fail' do
        lambda {
          doubled_object.should_receive(:defined_method_one_arg).with(no_args)
        }.should fail_for_arguments(1, 0)
      end

      it 'should recognize any_args param' do
        doubled_object.should_receive(:defined_method).with(any_args)
      end

      after do
        doubled_object.rspec_reset
      end

      def fail_for_arguments(expected, actual)
        fail_matching(
          "Wrong number of arguments for defined_method",
          "Expected #{expected}, got #{actual}"
        )
      end
    end
  end

  describe '#should_not_receive' do
    let(:method_under_test) { :should_not_receive }
    it_should_behave_like 'a fire-enhanced double method'
  end

  [ :stub, :stub! ].each do |stubber|
    describe "##{stubber}" do
      let(:method_under_test) { stubber }
      it_should_behave_like 'a fire-enhanced double method'

      context "RSpec's hash shortcut syntax" do
        context 'doubled class is not loaded' do
          let(:doubled_object) { fire_double("UnloadedObject") }
          should_allow(:undefined_method => 123)
        end

        context 'doubled class is loaded' do
          should_allow(:defined_method => 456)
          should_not_allow(:undefined_method => 789)
        end
      end
    end
  end
end

describe '#fire_double' do
  let(:doubled_object) { fire_double("TestObject") }

  it_should_behave_like 'a fire-enhanced double'
  it_should_behave_like "verifying named constants", :fire_double

  it 'allows stubs to be passed as a hash' do
    double = fire_double("TestObject", :defined_method => 17)
    double.defined_method.should eq(17)
  end
end

describe '#fire_class_double' do
  let(:doubled_object) { fire_class_double("TestClass") }

  it_should_behave_like 'a fire-enhanced double'
  it_should_behave_like "verifying named constants", :fire_class_double

  it 'uses a module for the doubled object so that it supports nested constants like a real class' do
    doubled_object.should be_a(Module)
  end

  it 'has a readable string representation' do
    doubled_object.to_s.should include("TestClass (fire double)")
    doubled_object.inspect.should include("TestClass (fire double)")
  end

  it 'assigns the class name' do
    TestClass.name.should eq("TestClass")
    doubled_object.name.should eq("TestClass")
  end

  it 'raises a mock expectation error for undefind methods' do
    expect {
      doubled_object.abc
    }.to raise_error(RSpec::Mocks::MockExpectationError)
  end

  it 'allows stubs to be specified as a hash' do
    double = fire_class_double("SomeClass", :a => 5, :b => 8)
    double.a.should eq(5)
    double.b.should eq(8)
  end

  it 'allows private methods to be stubbed, just like on a normal test double (but unlike a partial mock)' do
    mod = Module.new
    mod.stub(:use)
    expect { mod.use }.to raise_error(/private method `use' called/)

    fire_double = fire_class_double("TestClass")
    fire_double.stub(:use)
    fire_double.use # should not raise an error
  end if defined?(::RSpec::Mocks::TestDouble)
end

def reset_rspec_mocks
  ::RSpec::Mocks.space.reset_all
end

describe '#fire_replaced_class_double (for an existing class)' do
  let(:doubled_object) { fire_replaced_class_double("TestClass") }

  it_should_behave_like 'a fire-enhanced double'

  it 'replaces the constant for the duration of the test' do
    orig_class = TestClass
    doubled_object.should_not be(orig_class)
    TestClass.should be(doubled_object)
    reset_rspec_mocks
    TestClass.should be(orig_class)
  end

  it 'supports transferring nested constants to the double' do
    fire_class_double("TestClass").as_replaced_constant(:transfer_nested_constants => true)
    TestClass::M.should eq(:m)
    TestClass::N.should eq(:n)
  end

  def use_doubles(class_double, instance_double)
    instance_double.should_receive(:defined_method).and_return(3)
    class_double.should_receive(:defined_method).and_return(4)

    instance_double.defined_method.should eq(3)
    class_double.defined_method.should eq(4)

    expect { instance_double.should_receive(:undefined_method) }.to fail_matching("does not implement")
    expect { class_double.should_receive(:undefined_method) }.to fail_matching("does not implement")
  end

  it 'can be used after a declared fire_double for the same class' do
    instance_double = fire_double("TestClass")
    class_double = fire_replaced_class_double("TestClass")

    use_doubles class_double, instance_double
  end

  it 'can be used before a declared fire_double for the same class' do
    class_double = fire_replaced_class_double("TestClass")
    instance_double = fire_double("TestClass")

    use_doubles class_double, instance_double
  end
end

describe '#fire_replaced_class_double (for a non-existant class)' do
  it 'allows any method to be mocked' do
    double = fire_replaced_class_double("A::B::C")
    double.should_receive(:foo).with("a").and_return(:bar)
    A::B::C.foo("a").should eq(:bar)
  end

  def use_doubles(class_double, instance_double)
    instance_double.should_receive(:undefined_method).and_return(3)
    class_double.should_receive(:undefined_method).and_return(4)

    instance_double.undefined_method.should eq(3)
    class_double.undefined_method.should eq(4)
  end

  it 'can be used after a declared fire_double for the same class' do
    instance_double = fire_double("A::B::C")
    class_double = fire_replaced_class_double("A::B::C")

    use_doubles class_double, instance_double
  end

  it 'can be used before a declared fire_double for the same class' do
    class_double = fire_replaced_class_double("A::B::C")
    instance_double = fire_double("A::B::C")

    use_doubles class_double, instance_double
  end
end

describe RSpec::Fire::SupportArityMatcher do
  def support_arity(arity)
    RSpec::Fire::SupportArityMatcher.new(arity)
  end

  context "a method with an exact arity" do
    def two_args(a, b); end
    def no_args; end

    it 'passes when given the correct arity' do
      method(:two_args).should support_arity(2)
      method(:no_args).should support_arity(0)
    end

    it 'fails when given the wrong arity' do
      expect {
        method(:no_args).should support_arity(1)
      }.to raise_error(/Expected 0, got 1/)

      expect {
        method(:two_args).should support_arity(1)
      }.to raise_error(/Expected 2, got 1/)
    end
  end

  context "a method with one required arg and two default args" do
    def m(a, b=5, c=2); end

    it 'passes when given 1 to 3 args' do
      method(:m).should support_arity(1)
      method(:m).should support_arity(2)
      method(:m).should support_arity(3)
    end

    let(:can_distinguish_splat_from_defaults?) { method(:method).respond_to?(:parameters) }

    it 'fails when given 0' do
      pending("1.8 cannot distinguish default args from splats", :unless => can_distinguish_splat_from_defaults?) do
        expect {
          method(:m).should support_arity(0)
        }.to raise_error(/Expected 1 to 3, got 0/)
      end
    end

    it 'fails when given more than 3' do
      pending("1.8 cannot distinguish default args from splats", :unless => can_distinguish_splat_from_defaults?) do
        expect {
          method(:m).should support_arity(4)
        }.to raise_error(/Expected 1 to 3, got 4/)
      end
    end
  end

  context "a method with one required arg and a splat" do
    def m(a, *b); end

    it 'passes when given 1 or more' do
      method(:m).should support_arity(1)
      method(:m).should support_arity(20)
    end

    it 'fails when given 0' do
      expect {
        method(:m).should support_arity(0)
      }.to raise_error(/Expected 1 or more, got 0/)
    end
  end

  context "a method with an explicit block arg" do
    def m(a, &b); end

    it 'passes when given 1' do
      method(:m).should support_arity(1)
    end

    it 'fails when given 2' do
      expect {
        method(:m).should support_arity(2)
      }.to raise_error(/Expected 1, got 2/)
    end
  end
end
