module Resque
  module Plugins
    module ResqueSliders
      module Helpers

        def known_hosts_set_name
          "plugins:resque-sliders:known_hosts"
        end

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
          Resque.redis.hset(key, field, fvalue) == 1
        end

        def redis_del_hash(key, field)
          Resque.redis.hdel(key, field) == 1
        end

        # Return Hash: { queue => # }
        def queue_values(host)
          redis_get_hash("#{key_prefix}:#{host}")
        end

        def register_setting(setting, value)
          redis_set_hash(host_config_key, "#{@hostname}:#{setting}", value)
        end

        def unregister_setting(setting)
          redis_del_hash(host_config_key, "#{@hostname}:#{setting}")
        end

        # Signal Checking

        # Gets signal field in redis config_key for this host. Don't call directly
        def check_signal(host)
          sig = caller[0][/`([^']*)'/, 1].gsub('?', '')
          raise 'Dont call me that' unless %w(reload pause stop).include?(sig)
          if @hostname
            # if instance variable set from running daemon, make a freshy
            redis_get_hash_field(host_config_key, "#{@hostname}:#{sig}").to_i == 1
          else
            # otherwise cache call in a Hash
            @host_signal_map ||= {}
            @host_signal_map[host] ||= {}
            unless @host_signal_map[host].has_key?(sig)
              @host_signal_map[host] = {sig => redis_get_hash_field(host_config_key, "#{host}:#{sig}").to_i == 1}.update(@host_signal_map[host])
            end
            @host_signal_map[host][sig]
          end
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

        # Set signal key given signal, host
        def set_signal_flag(sig, host=@hostname)
          @hostname ||= host
          if sig == 'play'
            %w(pause stop).each { |x| unregister_setting(x) }
          else
            register_setting(sig, 1)
          end
        end

      end
    end
  end
end
