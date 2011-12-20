$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'resque'
require 'resque/server'

require 'resque-sliders/server'
require 'resque-sliders/version'

module Resque
  module Plugins
    class ResqueSliders

      attr_reader :stale_hosts

      def initialize
        @host_map = Resque.redis.hgetall("plugins:resque-sliders:hosts")
        @resque_key = "plugins:resque-sliders"
        @stale_hosts = Resque.redis.keys("#{@resque_key}:*").select { |x| Resque.redis.type(x) == 'hash' }.map { |x| x = x.split(':').last; x unless x == 'hosts' or hosts.include?(x) }.compact.sort
      end

      def hosts
        # Return Array of currently online hosts
        @host_map.keys.sort
      end

      def all_hosts
        # Array of all hosts
        (hosts + stale_hosts).sort
      end

      def max_children(host)
        # Return max children count
        @host_map[host].to_i == 0 ? nil : @host_map[host].to_i
      end

      def max_children!(host, count)
        # Override max_children on host (Dangerous!)
        key = "#{@resque_key}:hosts"
        Resque.redis.hset(key, host, count) if Resque.redis.hexists(key, host)
      end

      def queues_on(host)
        # Return Array of queues on host
        Resque.redis.hkeys("#{@resque_key}:#{host}") if all_hosts.include?(host)
      end

      def queue_values(host)
        # Return Hash: { queue => # }
        Resque.redis.hgetall("#{@resque_key}:#{host}")
      end

      def change(host, queue, quantity)
        # Returns boolean
        queue.strip!
        Resque.redis.hset("#{@resque_key}:#{host}", queue, quantity) unless queue.empty?
      end

      def delete(host, queue)
        # Returns boolean
        Resque.redis.hdel("#{@resque_key}:#{host}", queue) == 1 ? true : false
      end

    end
  end
end
