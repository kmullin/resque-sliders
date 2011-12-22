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

        def redis_set_hash(key, xkey, xvalue)
          Resque.redis.hset(key, xkey, xvalue) == 1 ? true : false
        end

        def redis_del_hash(key, xkey)
          Resque.redis.hdel(key, xkey) == 1 ? true : false
        end

      end
    end
  end
end
