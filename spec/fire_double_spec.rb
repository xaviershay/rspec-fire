require 'spec_helper'

class TestObject
  def defined_method
    raise "Y U NO MOCK?"
  end
end

describe '#fire_double' do
  def self.should_allow(method_name)
    it "should allow #{method_name}" do
      object = fire_double("UnloadedObject")
      lambda {
        object.send(method_under_test, method_name)
      }.should_not raise_error
      object.rspec_reset
    end
  end

  def self.should_not_allow(method_name)
    it "should not allow #{method_name}" do
      object = fire_double("TestObject")
      lambda {
        object.send(method_under_test, method_name)
      }.should fail_matching("#{method_name} does not implement", method_name)
    end
  end

  shared_examples_for 'a fire-enhanced double' do
    describe 'doubled class is not loaded' do
      should_allow(:undefined_method)
    end

    describe 'doubled class is loaded' do
      should_allow(:defined_method)
      should_not_allow(:undefined_method)
    end
  end

  describe '#should_receive' do
    let(:method_under_test) { :should_receive }
    it_should_behave_like 'a fire-enhanced double'
  end

  describe '#should_not_receive' do
    let(:method_under_test) { :should_not_receive }
    it_should_behave_like 'a fire-enhanced double'
  end

  describe '#stub' do
    let(:method_under_test) { :stub }
    it_should_behave_like 'a fire-enhanced double'
  end
end
