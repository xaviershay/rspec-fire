require 'spec_helper'

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
  extend TestMethods

  class Nested
    class NestedEvenMore
    end
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
  def self.should_allow(method_name)
    it "should allow #{method_name}" do
      lambda {
        doubled_object.send(method_under_test, method_name)
      }.should_not raise_error
      doubled_object.rspec_reset
    end
  end

  def self.should_not_allow(method_name)
    it "should not allow #{method_name}" do
      lambda {
        doubled_object.send(method_under_test, method_name)
      }.should fail_matching("does not implement", method_name)
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

  describe '#stub' do
    let(:method_under_test) { :stub }
    it_should_behave_like 'a fire-enhanced double method'
  end
end

describe '#fire_double' do
  let(:doubled_object) { fire_double("TestObject") }

  it_should_behave_like 'a fire-enhanced double'
end

describe '#fire_class_double' do
  let(:doubled_object) { fire_class_double("TestClass") }

  it_should_behave_like 'a fire-enhanced double'
end

def reset_double(double)
  double.rspec_reset
  # manually remove it from the list that will be reset,
  # so it doesn't get double-reste
  ::RSpec::Mocks.space.send(:mocks).delete(double)
end

describe '#fire_replaced_class_double (for an existing class)' do
  let(:doubled_object) { fire_replaced_class_double("TestClass") }
  it_should_behave_like 'a fire-enhanced double'

  it 'replaces the given constant with the double' do
    orig_class = TestClass
    double = doubled_object

    TestClass.should be(double)
    TestClass.should_not be(orig_class)
  end

  it 'returns the constant to its original value when reset' do
    orig_class = TestClass
    double = doubled_object
    reset_double double

    TestClass.should be(orig_class)
    TestClass.should_not be(double)
  end

  it 'handles deep nesting' do
    orig_class = TestClass::Nested::NestedEvenMore
    double = fire_replaced_class_double("TestClass::Nested::NestedEvenMore")

    TestClass::Nested::NestedEvenMore.should be(double)
    TestClass::Nested::NestedEvenMore.should_not be(orig_class)

    reset_double double

    TestClass::Nested::NestedEvenMore.should_not be(double)
    TestClass::Nested::NestedEvenMore.should be(orig_class)
  end

  it 'adds the double to rspec-mocks space so that it gets reset between examples' do
    double = doubled_object
    ::RSpec::Mocks.space.send(:mocks).should include(double)
  end
end

describe '#fire_replaced_class_double (for a non-existant class)' do
  it 'sets the constant' do
    defined?(A::B::C).should be_false
    double = fire_replaced_class_double("A::B::C")
    A::B::C.should be(double)
  end

  it 'removes all generated constants' do
    double = fire_replaced_class_double("A::B::C")
    reset_double(double)
    defined?(A::B::C).should be_false
    defined?(A::B).should be_false
    defined?(A).should be_false
  end

  it 'handles a single, unnested undefined constant' do
    defined?(Goo).should be_false
    double = fire_replaced_class_double("Goo")
    Goo.should be(double)
    reset_double(double)
    defined?(Goo).should be_false
  end

  it 'handles constants with some nestings that are set' do
    defined?(TestClass::Nested).should be_true
    defined?(TestClass::Nested::X::Y::Z).should be_false
    double = fire_replaced_class_double("TestClass::Nested::X::Y::Z")
    TestClass::Nested::X::Y::Z.should be(double)

    reset_double(double)

    defined?(TestClass::Nested::X::Y::Z).should be_false
    defined?(TestClass::Nested::X::Y).should be_false
    defined?(TestClass::Nested::X).should be_false
    defined?(TestClass::Nested).should be_true
  end

  it 'allows any method to be mocked' do
    double = fire_replaced_class_double("A::B::C")
    double.should_receive(:foo).with("a").and_return(:bar)
    A::B::C.foo("a").should eq(:bar)
  end

  it 'adds the double to rspec-mocks space so that it gets reset between examples' do
    double = fire_replaced_class_double("A::B::C")
    ::RSpec::Mocks.space.send(:mocks).should include(double)
  end
end

