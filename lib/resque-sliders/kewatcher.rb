require 'resque'
require 'timeout'
require 'fileutils'

require 'resque-sliders/helpers'

module Resque
  module Plugins
    module ResqueSliders
      # KEWatcher class provides a daemon to run on host that are running resque workers.
      class KEWatcher
        include Helpers

        # Verbosity level (Integer)
        attr_accessor :verbosity

        # Initialize daemon with options from command-line.
        def initialize(options={})
          @verbosity = (options[:verbosity] || 0).to_i
          @hostile_takeover = options[:force]
          @rakefile = File.expand_path(options[:rakefile]) rescue nil
          @rakefile = File.exists?(@rakefile) ? @rakefile : nil if @rakefile
          @pidfile = File.expand_path(options[:pidfile]) rescue nil
          @pidfile = @pidfile =~ /\.pid/ ? @pidfile : @pidfile + '.pid' if @pidfile
          save_pid!

          @max_children = (options[:max_children] || 5).to_i
          @hostname = `hostname -s`.chomp.downcase
          @pids = Hash.new # init pids array to track running children
          @need_queues = Array.new # keep track of pids that are needed
          @dead_queues = Array.new # keep track of pids that are dead
          @zombie_pids = Array.new # keep track of zombie's we kill and dont watch()

          Resque.redis = options[:config]
        end

        # run the daemon
        def run!(interval=0.1)
          interval = Float(interval)
          if running?
            (puts "Already running. Restart Not Forced exiting..."; exit) unless @hostile_takeover
            restart_running!
          end
          $0 = "KEWatcher: Starting"
          startup

          count = 0
          old = 0 # know when to tell redis we have new different current pids
          loop do
            break if shutdown?
            count += 1
            log! ["watching:", @pids.keys.join(', '), "(#{@pids.keys.length})"].delete_if { |x| x == (nil || '') }.join(' ') if count % (10 / interval) == 1

            if not (paused? || shutdown?)
              if count % (20 / interval) == 1
                # do first and also about every 20 seconds so we can throttle calls to redis
                queue_diff!
                signal_hup if check_reload and not count == 1
                procline @pids.keys.join(', ')
              end

              while @pids.keys.length < @max_children && (@need_queues.length > 0 || @dead_queues.length > 0)
                queue = @dead_queues.shift || @need_queues.shift
                @pids.store(fork { exec("rake#{' -f ' + @rakefile if @rakefile}#{' environment' if ENV['RAILS_ENV']} resque:work QUEUE=#{queue}") }, queue) # store offset if linux fork() ?
                procline @pids.keys.join(', ')
              end
            end

            register_setting('current_children', @pids.keys.length) if old != @pids.length
            old = @pids.length

            sleep(interval) # microsleep
            kill_zombies! # need to cleanup ones we've killed
            @pids.keys.each do |pid|
              begin
                # check to see if pid is running, by waiting for it, with a timeout
                # Im sure Ruby 1.9 has some better helpers here
                Timeout::timeout(interval / 100) { Process.wait(pid) }
              rescue Timeout::Error
                # Timeout expired, goto next pid
                next
              rescue Errno::ECHILD
                # if no pid exists to wait for, remove it
                log! (paused? || shutdown?) ? "#{pid} (#{@pids[pid]}) child died; no one cares..." : "#{pid} (#{@pids[pid]}) child died; spawning another..."
                remove pid
                break
              end
            end
          end
        end

        # Returns PID if already running, false otherwise
        def running?
          pid = `ps x -o pid,command|grep [K]EWatcher|awk '{print $1}'`.to_i
          pid == 0 ? false : pid
        end

        private

        def check_reload
          (unregister_setting('reload'); return true) if reload?(@hostname)
          false
        end

        def unregister_setting(setting)
          redis_del_hash(host_config_key, "#{@hostname}:#{setting}")
        end

        # Forces (via signal QUIT) any KEWatcher process running, located by ps and grep
        def restart_running!
          count = 0
          while pid = running?
            (puts "#{pid} wont die; giving up"; exit 2) if count > 6
            count += 1
            if count % 5 == 1
              puts "Killing running KEWatcher: #{pid}"
              Process.kill('QUIT', pid)
            end
            s = 3 * count
            puts "Waiting #{s}s for it to die..."
            sleep(s)
          end
        end

        def startup
          log! "Found RAILS_ENV=#{ENV['RAILS_ENV']}" if ENV['RAILS_ENV']
          enable_gc_optimizations
          register_signal_handlers
          register_setting('max_children', @max_children)
          log! "Registered Max Children with Redis"
          $stdout.sync = true
        end

        def enable_gc_optimizations
          if GC.respond_to?(:copy_on_write_friendly=)
            GC.copy_on_write_friendly = true
          end
        end

        def register_signal_handlers
          trap('TERM') { shutdown! }
          trap('INT') { shutdown! }

          begin
            trap('QUIT') { shutdown! }
            trap('HUP') { signal_hup }
            trap('USR1') { signal_usr1 }
            trap('USR2') { signal_usr2 }
            trap('CONT') { signal_cont }
          rescue ArgumentError
            warn "Signals QUIT, USR1, USR2, and/or CONT not supported."
          end

          log! "Registered signals"
        end

        def procline(string)
          $0 = "KEWatcher (#{@pids.keys.length}): #{string}"
          log! $0
        end

        def queue_diff!
          # Forces queue diff
          # Overrides what needs to start from Redis
          diff = queue_diff
          to_start = diff.first
          to_kill = diff.last
          to_kill.each { |pid| remove! pid }
          @need_queues = to_start # authoritative answer from redis of what needs to be running
        end

        def queue_diff
          # Queries Redis to get Hash of what should running
          # figures what is running and does a diff
          # returns an Array of 2 Arrays: to_start, to_kill

          goal, to_start, to_kill = [], [], []
          queue_values(@hostname).each_pair { |queue,count| goal += [queue] * count.to_i }
          # to sort or not to sort?
          # goal.sort!

          running_queues = @pids.values # check list
          goal.each do |q|
            if running_queues.include?(q)
              # delete from checklist cause its already running
              running_queues.delete_at(running_queues.index(q))
            else
              # not included in running queue, need to start
              to_start << q
            end
          end

          @pids.dup.each_pair do |k,v|
            if running_queues.include?(v)
              # whatever is left over in this checklist shouldn't be running
              to_kill << k
              running_queues.delete_at(running_queues.index(v))
            end
          end

          if (to_start.length + @pids.keys.length - to_kill.length) > @max_children
            # if to_start with existing minus whats to be killed is still greater than max children
            log "WARN: need to start too many children, please raise max children"
          end

          kill_queues = to_kill.map { |x| @pids[x] }
          log! ["GOTTA START:", to_start.map { |x| "#{x} (#{to_start.count(x)})" }.uniq.join(', '), "= #{to_start.length}"].delete_if { |x| x == (nil || '') }.join(' ')
          log! ["GOTTA KILL:", kill_queues.map { |x| "#{x} (#{kill_queues.count(x)})" }.uniq.join(', '), "= #{to_kill.length}"].delete_if { |x| x == (nil || '') }.join(' ')

          [to_start, to_kill] # return whats left
        end

        def remove!(pid)
          # removes pid completely, ignores its queues
          kill_child pid
          @pids.delete(pid)
          procline @pids.keys.join(', ')
        end

        def remove(pid)
          # remove pid, and respawn same queues
          @dead_queues.unshift(@pids[pid]) # keep track of queues that pid was running, put it at front of list
          @pids.delete(pid)
          procline @pids.keys.join(', ')
        end

        def shutdown!
          log "Exiting..."
          @shutdown = true
          kill_children
          %w(current max).each { |x| unregister_setting("#{x}_children") }
          log! "Unregistered Max Children"
          Process.waitall()
          remove_pidfile!
        end

        def shutdown?
          @shutdown
        end

        def paused?
          @paused
        end

        def signal_hup
          log "HUP received; purging children..."
          kill_children
          @paused = false # unpause after kill (restart child)
        end

        def signal_usr1
          log "USR1 received; killing little children..."
          kill_children
          @paused = true # pause after kill cause we're paused
        end

        def signal_usr2
          log "USR2 received; not making babies"
          @paused = true # paused again
        end

        def signal_cont
          log "CONT received; making babies..."
          @paused = false # unpause
        end

        def kill_zombies!
          @zombie_pids.dup.each do |pid|
            begin
              log! "Waiting for Zombie: #{pid}"
              # Issue wait() to make sure pid isn't forgotten
              Process.wait(@zombie_pids.pop)
            rescue Errno::ECHILD
              next
            end
          end
        end

        def kill_child(pid)
          begin
            Process.kill("QUIT", pid) # try graceful shutdown
            log! "Child #{pid} killed. (#{@pids.keys.length-1})"
          rescue Object => e # dunno what this does but it works; dont know exception
            log! "Child #{pid} already dead, sad day. (#{@pids.keys.length-1}) #{e}"
          ensure
            # Keep track of ones we issued QUIT to
            @zombie_pids << pid
          end
        end

        def kill_children
          @pids.dup.keys.each do |pid|
            kill_child pid
            remove pid
          end
        end


        def log(message)
          if verbosity == 1
            puts "* #{message}"
          elsif verbosity > 1
            time = Time.now.strftime('%H:%M:%S %Y-%m-%d')
            puts "*** [#{time}] #$$: #{message}"
          end
        end

        def log!(message)
          log message if verbosity > 1
        end

        def save_pid!
          if @pidfile
            begin
              log "Saving pid to => #{@pidfile}"
              File.open(@pidfile, 'w') { |f| f.write(Process.pid) }
            rescue Errno::EACCES => e
              puts "Cannot write pidfile => #{e}"
              exit 1
            rescue Errno::ENOENT => e
              dir = File.dirname(@pidfile)
              begin
                log! "#{dir} doesnt exist; Creating it..."
                FileUtils.mkdir_p(dir)
              rescue Errno::EACCES => e
                puts "Cannot create directory => #{e}"
                exit 1
              end
              begin
                save_pid! # after creating dir, do save again
              rescue # rescue anything else to stop loop
                exit 2
              end
            end
          end
        end

        def remove_pidfile!
          File.exists?(@pidfile) && File.delete(@pidfile) if @pidfile
        end

      end
    end
  end
end
