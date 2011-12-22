$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))

require 'resque'
require 'resque/server'

require 'resque-sliders/helpers'
require 'resque-sliders/server'
require 'resque-sliders/version'

include ResqueSliders::Helpers

module Resque
  module Plugins
    # ResqueSliders class provides an interface for reading ResqueSliders::KEWatcher host config data.
    class ResqueSliders

      # Hosts that have config data (queues and values), but the host is not running the daemon.
      attr_reader :stale_hosts

      def initialize
        @host_status = redis_get_hash(host_config_key)
        @stale_hosts = Resque.redis.keys("#{key_prefix}:*").select { |x| Resque.redis.type(x) == 'hash' }.map { |x| y = x.split(':').last; y unless x == host_config_key or hosts.include?(y) }.compact.sort
      end

      # Return Array of currently online hosts
      def hosts
        @host_status.keys.select { |x| x unless x.split(':').last == 'reload' }.map { |x| x.split(':').first }.uniq.sort
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
        key = "#{host}:max_children"
        redis_set_hash(host_config_key, key, count) unless stale_hosts.include?(host)
      end

      # Return Array of queues on host
      def queues_on(host)
        queue_values(host).keys if all_hosts.include?(host)
      end

      # Return Hash: { queue => # }
      def queue_values(host)
        redis_get_hash("#{key_prefix}:#{host}")
      end

      # Changes queues to quantiy for host.
      # Returns boolean.
      def change(host, queue, quantity)
        # queue is sanitized by:
        # replacing punctuation with spaces, strip end spaces, split on remaining whitespace, and join again on comma.
        queue = queue.downcase.gsub(/[^a-z 0-9]/, ' ').strip.split(' ').join(',')
        redis_set_hash("#{key_prefix}:#{host}", queue, quantity) unless queue.empty?
      end

      # Deletes queue for host.
      # Returns boolean.
      def delete(host, queue)
        redis_del_hash("#{key_prefix}:#{host}", queue)
      end

      # Sets Key to reload host's KEWatcher
      def reload(host)
        redis_set_hash(host_config_key, "#{host}:reload", 1)
      end

      def reload?(host)
        redis_get_hash_field(host_config_key, "#{host}:reload").to_i == 1 ? true : false
      end

    end
  end
end
