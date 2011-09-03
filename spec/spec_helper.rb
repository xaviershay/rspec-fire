require 'rspec/fire'

RSpec.configure do |config|
  config.include(RSpec::Fire)

  def fail_matching(*messages)
    raise_error(RSpec::Expectations::ExpectationNotMetError) {|error|
      messages.all? {|message|
        error.message =~ /#{Regexp.escape(message)}/
      }
    }
  end
end
