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

desc "Bump version"
task :git_tag_version do
  require 'resque-sliders/version'
  git_tags = `git tag -l`.split.map { |x| x.gsub(/v/, '') }
  version = Resque::Plugins::ResqueSliders::Version
  commit_sha = `git log -1 HEAD|head -n1|awk '{print $2}'`
  (puts version, commit_sha; `git tag v#{version} #{commit_sha}`) unless git_tags.include?(version)
end
