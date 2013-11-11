require 'zlib'
module Resque
  module Plugins
    module ResqueSliders
      class DistributedCommander < Commander
        include Helpers

        def distributed_change(queue, count)
          #we want the starting server for a job-type to be random across all the workers, but consistent so we aren't starting up/shutting things down all the time.  A hash of the queue-name modded by the number of workers should give us a good solution.
          
          host_job_mappings = {}
          host_set = all_hosts
          host_set_size = all_hosts.size
          consistent_random_start_index = Zlib.crc32(queue) % host_set_size

          count.times do |numb|
            current_host = host_set[(numb + consistent_random_start_index) % host_set_size ]
            host_job_mappings[current_host] ||= 0
            host_job_mappings[current_host] += 1
          end
          
          distributed_delete(queue)
          host_job_mappings.each do |host, job_count|
            change(host, queue, job_count, true)
          end
        end

        def all_queue_values
          all_hosts.map{|host| queue_values(host)}.inject({}) do |acc, host|
            acc.merge(host){|key, v1,v2| v1.to_i + v2.to_i}
          end
        end

        def clear_queues!
          # If this is performed without re-adding hosts that are currently stale they will be lost!
          all_hosts.each do |host|
            Resque.redis.del "plugins:resque-sliders:#{host}"
          end
        end

        def distributed_delete(queue)
          all_hosts.each do |host|
            delete(host, queue)
          end
        end

        def stop_all_hosts!
          all_hosts.each do |host|
            redis_set_hash(host_config_key, "#{host}:stop", 1)
          end
        end

        def restart_all_hosts!
          all_hosts.each do |host|
            redis_set_hash(host_config_key, "#{host}:reload", 1)
          end
        end

        def start_all_hosts!
          all_hosts.each do |host|
            redis_del_hash(host_config_key, "#{host}:stop")
          end
        end

        def force_host(host_name)
          @stale_hosts << host_name
          @stale_hosts.sort!.uniq!
        end
      end
    end
  end
end
