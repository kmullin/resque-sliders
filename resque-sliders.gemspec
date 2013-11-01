# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "resque-sliders/version"

Gem::Specification.new do |s|
  s.name        = "resque-sliders"
  s.version     = Resque::Plugins::ResqueSliders::Version
  s.authors     = "Kevin Mullin"
  s.email       = "kevin@kpmullin.com"
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.homepage    = "https://github.com/kmullin/resque-sliders"
  s.summary     = %q{Resque-Sliders: a plugin for resque that controls which resque workers are running on each host, from within Resque-web}

  s.add_dependency 'resque', ['>= 1.15.0', '< 2.0']
  s.extra_rdoc_files = ["README.md", "MIT-LICENSE"]

  s.license       = 'MIT'
  s.files         = `git ls-files`.split("\n")
  s.files        -= %w(.gitignore Gemfile Gemfile.lock resque-sliders.gemspec Rakefile .travis.yml)
  s.files        -= s.files.grep(%r{^(misc|helpers)/})
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.executables   = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.description = <<description
    Resque-Sliders is a plugin for Resque that enables you to control multiple hosts'
    running resque workers with a monitor PID watching over them.  From the resque-web UI, you
    can add/delete/change which queues are running on each host running the monitor PID.
    Sliders are in the UI and allow you to adjust how many workers on either host should be running.
description
end
