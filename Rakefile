require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |opts|
  opts.rspec_opts = '--format documentation'
end

desc 'Default: run specs.'
task :default => :spec
