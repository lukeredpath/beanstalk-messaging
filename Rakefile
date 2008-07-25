require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

desc 'Default: run unit tests.'
task :default => 'test:unit'

namespace :test do
  desc 'Test the beanstalk_messaging plugin.'
  Rake::TestTask.new(:unit) do |t|
    t.libs << 'lib'
    t.pattern = 'test/*_test.rb'
    t.verbose = true
  end

  desc 'End to end acceptance tests, requires beanstalkd daemon.'
  Rake::TestTask.new(:acceptance) do |t|
    t.libs << 'lib'
    t.pattern = 'test/acceptance/*_test.rb'
    t.verbose = true
  end
  
  desc 'Run all tests'
  task :all => [:unit, :acceptance]
end

desc 'Generate documentation for the beanstalk_messaging plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'BeanstalkMessaging'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
