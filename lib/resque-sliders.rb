$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'resque'
require 'resque/server'

require 'resque-sliders/helpers'
require 'resque-sliders/commander'
require 'resque-sliders/server'
require 'resque-sliders/version'
require 'resque-sliders/distributed_commander'

