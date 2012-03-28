Gem::Specification.new do |s|
  s.name     = 'rspec-fire'
  s.version  = '0.3.0'
  s.summary  = 'More resilient test doubles for RSpec.'
  s.platform = Gem::Platform::RUBY
  s.authors  = ["Xavier Shay"]
  s.email    = ["hello@xaviershay.com"]
  s.homepage = "http://github.com/xaviershay/rspec-fire"
  s.has_rdoc = false

  s.require_path = 'lib'
  s.files        = Dir.glob("{spec,lib}/**/*.rb") +
                   %w(
                     Gemfile
                     README.md
                     HISTORY
                     Rakefile
                     rspec-fire.gemspec
                   )

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec', '~> 2.6'
end
