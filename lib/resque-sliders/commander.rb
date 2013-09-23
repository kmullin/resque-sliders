module Resque
  module Plugins
    module ResqueSliders
      class Commander

        include Helpers

        # Hosts that have config data (queues and values), but the host is not running the daemon.
        attr_reader :stale_hosts

        def initialize
          @host_status = redis_get_hash(host_config_key)
          @stale_hosts = Resque.redis.smembers(known_hosts_set_name).map { |x| y = x.split(':').last; y unless x == host_config_key or hosts.include?(y) }.compact.sort
        end

        # Return Array of currently online hosts
        def hosts
          @host_status.keys.select { |x| x unless %w(reload pause stop).include? x.split(':').last }.map { |x| x.split(':').first }.uniq.sort
        end

        # Array of all hosts (current + stale)
        def all_hosts
          (hosts + stale_hosts).sort
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
        def change(host, queue, quantity, force = false)
          # queue is sanitized by:
          # replacing punctuation with spaces, strip end spaces, split on remaining whitespace, and join again on comma.
          queue2 = queue.gsub(/['":]/, '').strip.gsub(/\s+/, ',').split(/, */).reject { |x| x.nil? or x.empty? }.join(',')
          raise 'Queue Different' unless (force || queue == queue2)
          Resque.redis.sadd(known_hosts_set_name, "#{key_prefix}:#{host}")
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
