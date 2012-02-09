require 'resque'

# Include resque-sliders
if RUBY_VERSION > '1.8.7'
  require_relative '../lib/resque-sliders'
else
  require File.join(File.dirname(__FILE__), '../lib/resque-sliders')
end
