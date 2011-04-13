require 'rake'
require 'rspec/core/rake_task'

desc "Run specs"
task :default => :spec

desc "Run the specs"
RSpec::Core::RakeTask.new(:core) do |t|
  t.pattern = 'spec/**/*_spec.rb'
end
