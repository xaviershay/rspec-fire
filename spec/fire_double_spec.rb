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
        doubled_object.should_receive(:defined_method_one_arg).with(1).and_return(:value)
        doubled_object.defined_method_one_arg(1).should == :value

        doubled_object.should_receive(:defined_method_one_arg).with(2) {|x| x + 1 }
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
        fail_matching("Wrong number of arguments for defined_method", "Expected #{expected}, got #{actual}")
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
