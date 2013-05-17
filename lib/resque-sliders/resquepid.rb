module Resque
  module Plugins
    module ResqueSliders
      class ResquePid

        attr_reader :queue, :pid, :start_time, :env

        def initialize(exec_string, env_opts)
           @queue = env_opts['QUEUE']
           @env = env_opts
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

        def to_s
          @pid.to_s
        end

        def inspect
          @pid
        end

        def to_i
          @pid
        end

      end
    end
  end
end
