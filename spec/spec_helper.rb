require 'rspec/fire'

RSpec.configure do |config|
  config.include(RSpec::Fire)

  def fail_matching(*messages)
    raise_error(RSpec::Expectations::ExpectationNotMetError) {|error|
      messages.each {|message|
        error.message.should =~ /#{Regexp.escape(message.to_s)}/
      }
    }
  end
end
