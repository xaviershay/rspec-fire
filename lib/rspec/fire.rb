require 'rspec/mocks'
require 'rspec/expectations'

if RSpec::Mocks::Version::STRING.to_f >= 3
  warn "rspec-fire functionality is now provided by rspec-mocks and is " +
    "no longer required. You can remove it from your dependencies."
else
  require 'rspec/fire/legacy'
end

require 'rspec/fire/configuration'
