# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "resque-sliders/version"

Gem::Specification.new do |s|
  s.name        = "resque-sliders"
  s.version     = ResqueSliders::Version
  s.authors     = "Kevin Mullin"
  s.email       = "kevin@kpmullin.com"
  s.date        = Time.now.strftime('%Y-%m-%d')
  s.homepage    = "https://github.com/kmullin/resque-sliders"
  s.summary     = %q{Write a gem summary}

  s.add_runtime_dependency 'resque', '~> 1.15.0'
  s.extra_rdoc_files = ["README.md", "MIT-LICENSE"]

  s.files         = `git ls-files`.split("\n")
  s.files        -= ['.rvmrc', '.gitignore'] + `git ls-files -- helpers/*`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.description = <<description
    Resque-Sliders is a plugin for Resque
description
end
