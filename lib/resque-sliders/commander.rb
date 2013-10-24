module Resque
  module Plugins
    module ResqueSliders
      class Commander

        include Helpers

        # Hosts that have config data (queues and values), but the host is not running the daemon.
        attr_reader :stale_hosts

        def initialize
          @host_status = redis_get_hash(host_config_key)
          @stale_hosts = Resque.redis.smembers(known_hosts_key) - hosts
        end

        # Return Array of currently online hosts
        def hosts
          Set.new.tap do |l|
            @host_status.keys.each do |x|
              x = x.split(':')
              l << x.first unless %w(reload pause stop).include?(x.last)
            end
          end.to_a.sort
        end

        # Array of all hosts (current + stale)
        def all_hosts
          (hosts + stale_hosts).sort
        end

        # Remove all keys for a host (clean)
        def remove_all_host_keys(hostname)
          # expensive process O(N)
          keys_to_delete = Resque.redis.keys("#{key_prefix}:*").select { |k| name = k.split(':').last; hostname == name }
          # look at config hash, remove fields if relate to this hostname
          fields_to_delete = redis_get_hash(host_config_key).keys.select { |k| name = k.split(':').first; hostname == name }
          # do delete
          Resque.redis.del(keys_to_delete) unless keys_to_delete.empty?
          redis_del_hash(host_config_key, fields_to_delete) unless fields_to_delete.empty?
          del_from_known_hosts(hostname)
        end

        # Return current children count or nil if Host hasn't registered itself.
        def current_children(host)
          @host_status["#{host}:current_children"].to_i if max_children(host)
        end

        # Return max children count or nil if Host hasn't registered itself.
        def max_children(host)
          max = @host_status["#{host}:max_children"].to_i
          max == 0 ? nil : max # if Max isn't set its not running
        end

        # Override max_children on host (Dangerous!)
        def max_children!(host, count)
          @hostname = host
          register_setting('max_children', count)
        end

        # Return Array of queues on host
        def queues_on(host)
          queue_values(host).keys if all_hosts.include?(host)
        end

        # Changes queues to quantiy for host.
        # Returns boolean.
        def change(host, queue, quantity)
          # queue is sanitized by:
          # replacing punctuation with spaces, strip end spaces, split on remaining whitespace, and join again on comma.
          queue2 = queue.gsub(/['":]/, '').strip.gsub(/\s+/, ',').split(/, */).reject { |x| x.nil? or x.empty? }.join(',')
          raise 'Queue Different' unless queue == queue2
          redis_set_hash("#{key_prefix}:#{host}", queue2, quantity) unless queue2.empty?
        end

        # Deletes queue for host.
        # Returns boolean.
        def delete(host, queue)
          redis_del_hash("#{key_prefix}:#{host}", queue)
        end

      end
    end
  end
end
