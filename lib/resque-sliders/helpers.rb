module Resque
  module Plugins
    module ResqueSliders
      module Helpers

        def key_prefix
          "plugins:resque-sliders"
        end

        def host_config_key
          "plugins:resque-sliders:host_configs"
        end

        def redis_get_hash(key)
          Resque.redis.hgetall(key)
        end

        def redis_get_hash_field(key, field)
          Resque.redis.hget(key, field)
        end

        def redis_set_hash(key, field, fvalue)
          Resque.redis.hset(key, field, fvalue) == 1 ? true : false
        end

        def redis_del_hash(key, field)
          Resque.redis.hdel(key, field) == 1 ? true : false
        end

        # Return Hash: { queue => # }
        def queue_values(host)
          redis_get_hash("#{key_prefix}:#{host}")
        end

        def register_setting(setting, value)
          redis_set_hash(host_config_key, "#{@hostname}:#{setting}", value)
        end


        # Signal Checking


        # Gets signal field in redis config_key for this host. Don't call directly
        def check_signal(host)
          sig = caller[0][/`([^']*)'/, 1].gsub('?', '')
          raise 'Dont call me that' unless %w(reload pause stop).include?(sig)
          redis_get_hash_field(host_config_key, "#{host}:#{sig}").to_i == 1 ? true : false
        end

        def reload?(host)
          check_signal(host)
        end

        def pause?(host)
          check_signal(host)
        end

        def stop?(host)
          check_signal(host)
        end

        # Return Hash of signals for host and their values
        #def check_redis_for_signals(host)
        #  configs = redis_get_hash(host_config_key)
        #  signals = %w(reload pause stop).map { |x| [host,x].join(':') }
        #  Hash[configs.delete_if { |k,v| ! signals.include?(k) }.map { |k,v| [k.split(':').last.to_sym ,v] }]
        #end

      end
    end
  end
end
