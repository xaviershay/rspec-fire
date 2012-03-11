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
end

describe '#fire_replaced_class_double (for a non-existant class)' do
  it 'allows any method to be mocked' do
    double = fire_replaced_class_double("A::B::C")
    double.should_receive(:foo).with("a").and_return(:bar)
    A::B::C.foo("a").should eq(:bar)
  end
end

shared_examples_for "loaded constant stubbing" do |const_name|
  include RSpec::Fire::RecursiveConstMethods
  let!(:original_const_value) { const }
  after { change_const_value_to(original_const_value) }

  define_method :const do
    recursive_const_get(const_name)
  end

  define_method :parent_const do
    recursive_const_get("Object::" + const_name.sub(/(::)?[^:]+\z/, ''))
  end

  define_method :last_const_part do
    const_name.split('::').last
  end

  def change_const_value_to(value)
    parent_const.send(:remove_const, last_const_part)
    parent_const.const_set(last_const_part, value)
  end

  it 'allows it to be stubbed' do
    const.should_not eq(7)
    stub_const(const_name, 7)
    const.should eq(7)
  end

  it 'resets it to its original value when rspec clears its mocks' do
    original_value = const
    original_value.should_not eq(:a)
    stub_const(const_name, :a)
    reset_rspec_mocks
    const.should be(original_value)
  end

  it 'does not reset the value to its original value when rspec clears its mocks if the example modifies the value of the constant' do
    stub_const(const_name, :a)
    change_const_value_to(new_const_value = Object.new)
    reset_rspec_mocks
    const.should be(new_const_value)
  end

  it 'returns the original value' do
    orig_value = const
    returned_value = stub_const(const_name, 7)
    returned_value.should be(orig_value)
  end
end

shared_examples_for "unloaded constant stubbing" do |const_name|
  include RSpec::Fire::RecursiveConstMethods
  before { recursive_const_defined?(const_name).should be_false }

  define_method :const do
    recursive_const_get(const_name)
  end

  define_method :parent_const do
    recursive_const_get("Object::" + const_name.sub(/(::)?[^:]+\z/, ''))
  end

  define_method :last_const_part do
    const_name.split('::').last
  end

  def change_const_value_to(value)
    parent_const.send(:remove_const, last_const_part)
    parent_const.const_set(last_const_part, value)
  end

  it 'allows it to be stubbed' do
    stub_const(const_name, 7)
    const.should eq(7)
  end

  it 'removes the constant when rspec clears its mocks' do
    stub_const(const_name, 7)
    reset_rspec_mocks
    recursive_const_defined?(const_name).should be_false
  end

  it 'does not remove the constant when the example manually sets it' do
    begin
      stub_const(const_name, 7)
      stubber = RSpec::Mocks.space.send(:mocks).first
      change_const_value_to(new_const_value = Object.new)
      reset_rspec_mocks
      const.should equal(new_const_value)
    ensure
      change_const_value_to(7)
      stubber.rspec_reset
    end
  end

  it 'returns nil since it was not originally set' do
    stub_const(const_name, 7).should be_nil
  end
end

describe "#stub_const" do
  context 'for a loaded unnested constant' do
    it_behaves_like "loaded constant stubbing", "TestClass"
  end

  context 'for a loaded nested constant' do
    it_behaves_like "loaded constant stubbing", "TestClass::Nested"
  end

  context 'for a loaded deeply nested constant' do
    it_behaves_like "loaded constant stubbing", "TestClass::Nested::NestedEvenMore"
  end

  context 'for an unloaded unnested constant' do
    it_behaves_like "unloaded constant stubbing", "X"
  end

  context 'for an unloaded nested constant' do
    it_behaves_like "unloaded constant stubbing", "X::Y"

    it 'removes the root constant when rspec clears its mocks' do
      defined?(X).should be_false
      stub_const("X::Y", 7)
      reset_rspec_mocks
      defined?(X).should be_false
    end
  end

  context 'for an unloaded deeply nested constant' do
    it_behaves_like "unloaded constant stubbing", "X::Y::Z"

    it 'removes the root constant when rspec clears its mocks' do
      defined?(X).should be_false
      stub_const("X::Y::Z", 7)
      reset_rspec_mocks
      defined?(X).should be_false
    end
  end

  context 'for an unloaded constant nested within a loaded constant' do
    it_behaves_like "unloaded constant stubbing", "TestClass::X"

    it 'removes the unloaded constant but leaves the loaded constant when rspec resets its mocks' do
      defined?(TestClass).should be_true
      defined?(TestClass::X).should be_false
      stub_const("TestClass::X", 7)
      reset_rspec_mocks
      defined?(TestClass).should be_true
      defined?(TestClass::X).should be_false
    end
  end

  context 'for an unloaded constant nested deeply within a deeply nested loaded constant' do
    it_behaves_like "unloaded constant stubbing", "TestClass::Nested::NestedEvenMore::X::Y::Z"

    it 'removes the first unloaded constant but leaves the loaded nested constant when rspec resets its mocks' do
      defined?(TestClass::Nested::NestedEvenMore).should be_true
      defined?(TestClass::Nested::NestedEvenMore::X).should be_false
      stub_const("TestClass::Nested::NestedEvenMore::X::Y::Z", 7)
      reset_rspec_mocks
      defined?(TestClass::Nested::NestedEvenMore).should be_true
      defined?(TestClass::Nested::NestedEvenMore::X).should be_false
    end
  end
end
