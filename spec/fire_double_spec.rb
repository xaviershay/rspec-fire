require 'spec_helper'

class TestObject
  def defined_method
    raise "Y U NO MOCK?"
  end
end

class TestClass
  def self.defined_method
    raise "Y U NO MOCK?"
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
