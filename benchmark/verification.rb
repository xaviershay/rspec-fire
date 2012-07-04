require 'rspec/fire'

class A
  def method_1
  end

  def method_2; end
end

describe 'verification' do
  include RSpec::Fire

  it 'blah' do
    1000.times do
      fire_double('A', method_1: 1, method_2: 2)
    end
  end
end
