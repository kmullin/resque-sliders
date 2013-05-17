module Resque
  module Plugins
    module ResqueSliders
      class ResquePid

        attr_reader :queue, :pid, :start_time

        def initialize(exec_string, queue, env_opts={})
           @queue = queue
           exec_args = if RUBY_VERSION < '1.9'
             [exec_string, env_opts.map {|k,v| "#{k}=#{v}"}].flatten.join(' ')
           else
             [env_opts, exec_string] # 1.9.x exec
           end
           @pid = fork do
             srand # seed
             exec(*exec_args)
           end
           @start_time = Time.now
        end

        # TODO implement to string, so return pid # as most used

      end
    end
  end
end
