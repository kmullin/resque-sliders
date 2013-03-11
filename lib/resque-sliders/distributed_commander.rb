module Resque
  module Plugins
    module ResqueSliders
      class DistributedCommander < Commander
        include Helpers

        def distributed_change(queue, count)
          host_job_mappings = {}
          host_set = all_hosts

          count.times do |numb|
            current_host = host_set.rotate!.first
            host_job_mappings[current_host] ||= 0
            host_job_mappings[current_host] += 1
          end
          
          distributed_delete(queue)
          host_job_mappings.each do |host, job_count|
            change(host, queue, job_count)
          end
        end

        def clear_queues!
          # If this is performed without re-adding hosts that are currently stale they will be lost!
          all_hosts.each do |host|
            redis.del "plugins:resque-sliders:#{host}"
          end
        end

        def force_host(host_name)
          @stale_hosts << host_name
          @stale_hosts.sort!.uniq!
        end

        def distributed_delete(queue)
          all_hosts.each do |host|
            delete(host, queue)
          end
        end

      end
    end
  end
end
