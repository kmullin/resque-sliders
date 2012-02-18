#!/usr/bin/env ruby

require 'rubygems'
require 'resque'

require File.expand_path(File.dirname(__FILE__) + "/resque_job")

Resque.enqueue(Jobs::Stuff, rand(1000))
Resque.enqueue(Jobs::Things, 3000)
Resque.enqueue(Jobs::Support, rand(1000))
Resque.enqueue(Jobs::Email, rand(1000))
Resque.enqueue(Jobs::Notification, rand(1000))
