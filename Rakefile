require 'bundler/gem_tasks'
require 'resque/tasks'
#
# Setup
#

$LOAD_PATH.unshift 'lib'

def command?(command)
  system("type #{command} > /dev/null 2>&1")
end


#
# Tests
#

task :default => :test

desc "Run the test suite"
task :test do
  rg = command?(:rg)
  Dir['test/**/*_test.rb'].each do |f|
    rg ? sh("rg #{f}") : ruby(f)
  end
end
