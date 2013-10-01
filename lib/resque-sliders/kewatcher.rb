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

        attr_reader :pidfile, :zombie_term_wait, :zombie_kill_wait, :max_children

        # Initialize daemon with options from command-line.
        def initialize(options={})
          @verbosity = (options[:verbosity] || 0).to_i # verbosity level
          @zombie_term_wait = options[:zombie_term_wait] || 20 # time to wait before TERM
          @zombie_kill_wait = ENV['RESQUE_TERM_TIMEOUT'].to_i + @zombie_term_wait unless ENV['RESQUE_TERM_TIMEOUT'].nil?
          @zombie_kill_wait ||= options[:zombie_kill_wait] || 60 # time to wait before -9
          @hostile_takeover = options[:force] # kill running kewatcher?
          @rakefile = File.expand_path(options[:rakefile]) rescue nil
          @rakefile = File.exists?(@rakefile) ? @rakefile : nil if @rakefile
          @pidfile = File.expand_path(options[:pidfile]) rescue nil
          @pidfile = @pidfile =~ /\.pid$/ ? @pidfile : @pidfile + '.pid' if @pidfile
          save_pid!

          @max_children = options[:max_children] || 10
          @hostname = `hostname -s`.chomp.downcase
          @max_running_time = options[:max_run_time] || 60*60 # kill child processes after an hour
          @pids = Hash.new # init pids array to track running children
          @need_queues = Array.new # keep track of pids that are needed
          @dead_queues = Array.new # keep track of pids that are dead
          @zombie_pids = Hash.new # keep track of zombie's we kill and dont watch(), with elapsed time we've waited for it to die
          @async = options[:async] || false # sync and wait by default
          @hupped = 0

          Resque.redis = case options[:config]
            when Hash
              [options[:config]['host'], options[:config]['port'], options[:config]['db'] || 0].join(':')
            else
              options[:config]
          end
        end

        def kill_long_running_processes!
          #$1 is the pid of the parent resque process,
          #$NF is the time the child resque process was created
          resque_parent_processes_str = `ps -A -o pid,command | grep -P -e "Forked [[:digit:]]+ at [[:digit:]]+" | awk '{print $1 ":" $(NF-1)}'`
          pids_times = resque_parent_processes_str.split("\n").map do |pid_time|
            #starts as "12345:123456789876543"
            pid_time.split(":").map{|n| n.to_i}
          end
          pids_times.each do |pid, start_time|
            begin
              log! ["killing", pid, "at #{Time.now} because it started at #{Time.at(start_time)} (#{start_time})"].join(" ")
              Process.kill(:KILL, pid) if Time.now.to_i > start_time + @max_running_time
            rescue Errno::ESRCH => e
              #do nothing because the process doesn't exist
            end
          end
        end

        # run the daemon
        def run!(interval=0.1)
          interval = Float(interval)
          if running?
            unless @hostile_takeover
              puts "Already running. Restart Not Forced exiting..."
              exit
            end
            restart_running!
          end
          $0 = "KEWatcher: Starting"
          startup

          count = 0
          old = 0 # know when to tell redis we have new different current pids
          loop do
            break if shutdown?
            kill_long_running_processes!
            count += 1
            log! ["watching:", @pids.keys.join(', '), "(#{@pids.keys.length})"].delete_if { |x| x == (nil || '') }.join(' ') if count % (10 / interval) == 1

            tick = count % (20 / interval) == 1
            (log! "checking signals..."; check_signals) if tick
            if not (paused? || shutdown?)
              queue_diff! if tick # do first and also about every 20 seconds so we can throttle calls to redis

              while @pids.keys.length < @max_children && (@need_queues.length > 0 || @dead_queues.length > 0)
                queue = @dead_queues.shift || @need_queues.shift
                exec_string = ""
                exec_string << 'rake'
                exec_string << " -f #{@rakefile}" if @rakefile
                exec_string << ' environment' if ENV['RAILS_ENV']
                exec_string << ' resque:work'
                env_opts = {"QUEUE" => queue}
                if Resque::Version >= '1.22.0' # when API changed for signals
                  term_timeout = @zombie_kill_wait - @zombie_term_wait
                  term_timeout = term_timeout > 0 ? term_timeout : 1
                  env_opts.merge!({
                    'TERM_CHILD' => '1',
                    'RESQUE_TERM_TIMEOUT' => term_timeout.to_s # use new signal handling
                  })
                end
                exec_args = if RUBY_VERSION < '1.9'
                  [exec_string, env_opts.map {|k,v| "#{k}=#{v}"}].flatten.join(' ')
                else
                  [env_opts, exec_string] # 1.9.x exec
                end
                pid = fork do
                  srand # seed
                  exec(*exec_args)
                end
                @pids.store(pid, queue) # store pid and queue its running if fork() ?
                procline
              end
            end
            if @pidfile
              write_children_pids
            end

            register_setting('current_children', @pids.keys.length) if old != @pids.length
            old = @pids.length

            procline if tick

            sleep(interval) # microsleep
            kill_zombies! unless shutdown? # need to cleanup ones we've killed
            if @hupped > 0
              log "HUP received; purging children..."
              signal_hup
              do_reload!
              @hupped -= 1
            end

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

        def child_pid_file_name
          "#{@pidfile}_children.pid"
        end

        def write_children_pids
          File.open(child_pid_file_name, 'w') {|f| f.write(MultiJson.encode(@pids.keys))}
        end

        def kill_orphans
          begin
            orphan_pids = MultiJson.decode(IO.read(child_pid_file_name))
            orphan_pids.each do |orphan|
              kill_child(orphan)
            end
          rescue 
            nil
          end
        end

        # Returns PID if already running, false otherwise
        def running?
          pid = `ps x -o pid,command|grep [K]EWatcher|awk '{print $1}'`.to_i
          pid == 0 ? false : pid
        end

        private

        # Forces (via signal QUIT) any KEWatcher process running, located by ps and grep
        def restart_running!
          count = 0
          while pid = running?
            (puts "#{pid} wont die; giving up"; exit 2) if count > 6
            count += 1
            case count 
            when 1
              puts "Killing running KEWatcher: #{pid}"
              Process.kill(:TERM, pid)
            when 5
              puts "Killing running KEWatcher: #{pid}.. with FIRE!"
              Process.kill(:KILL, pid)
            end
            s = 2 * count
            puts "Waiting #{s}s for it to die..."
            sleep(s)
          end
        end

        def startup
          log! "Found RAILS_ENV=#{ENV['RAILS_ENV']}" if ENV['RAILS_ENV']
          kill_orphans
          enable_gc_optimizations
          register_signal_handlers
          clean_signal_settings
          register_setting('max_children', @max_children)
          log! "Registered Max Children with Redis #{max_children}"
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
            trap('HUP') { @hupped += 1 }
            trap('USR1') { log "USR1 received; killing little children..."; set_signal_flag('stop'); signal_usr1 }
            trap('USR2') { log "USR2 received; not making babies"; set_signal_flag('pause'); signal_usr2 }
            trap('CONT') { log "CONT received; making babies..."; set_signal_flag('play'); signal_cont }
          rescue ArgumentError
            warn "Signals QUIT, USR1, USR2, and/or CONT not supported."
          end

          log! "Registered signals"
        end

        def clean_signal_settings
          %w(pause stop reload).each { |x| unregister_setting(x) }
        end

        # Check signals, do appropriate thing
        def check_signals
          if reload?(@hostname)
            log ' -> RELOAD from web-ui'
            signal_hup
            do_reload!
          elsif stop?(@hostname)
            log ' -> STOPPED from web-ui' if not paused? or @pids.keys.length > 0
            signal_usr1
          elsif pause?(@hostname)
            log ' -> PAUSED from web-ui' unless paused?
            signal_usr2
          else
            log! ' -> Continuing; no signal found'
            signal_cont
          end
        end

        def procline
          status ||= 'stopped' if paused? and (@pids.keys.empty? and @zombie_pids.keys.empty?)
          status ||= 'paused' if paused?
          status = "#{[@pids.keys.length, @zombie_pids.keys.length, status].compact.join('-')}" unless status == 'stopped'
          name = "KEWatcher"
          pid_str = []
          pid_str << "R:#{@pids.keys.join(',')}" unless @pids.keys.empty?
          pid_str << "Z:#{@zombie_pids.keys.join(',')}" unless @zombie_pids.keys.empty?
          $0 = "#{name} (#{status}): #{pid_str.join(' ')}"
          log! $0
        end

        def queue_diff!
          # Forces queue diff
          # Overrides what needs to start from Redis
          to_start, to_kill = queue_diff
          to_kill.each { |pid| remove! pid }
          @need_queues = to_start # authoritative answer from redis of what needs to be running
          @dead_queues = Array.new
        end

        def queue_diff
          # Queries Redis to get Hash of what should running
          # figures what is running and does a diff
          # returns an Array of 2 Arrays: to_start, to_kill

          goal, to_start, to_kill = [], [], []
          queue_values(@hostname).each_pair { |queue,count| goal += [queue] * count.to_i }

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

        # removes pid completely, ignores its queues
        def remove!(pid)
          kill_child pid
          @pids.delete(pid)
          procline
        end

        # remove pid, and respawn same queues
        def remove(pid)
          @dead_queues.unshift(@pids[pid]) # keep track of queues that pid was running, put it at front of list
          @pids.delete(pid)
          procline
        end

        def do_reload!
          while not @async and @zombie_pids.length > 0
            kill_zombies!
          end
        end

        def shutdown!
          log "Exiting..."
          @shutdown = true
          kill_children
          while @zombie_pids.keys.length > 0
            kill_zombies!
          end
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

        # Reload
        def signal_hup
          clean_signal_settings
          kill_children
          @paused = false # unpause after kill (restart child)
        end

        # Stop
        def signal_usr1
          kill_children
          @paused = true # pause after kill cause we're paused
        end

        # Pause
        def signal_usr2
          @paused = true # paused again
        end

        # Continue
        def signal_cont
          @paused = false # unpause
        end

        def kill_zombies!
          return if @zombie_pids.empty?
          local_zombies = @zombie_pids.dup
          to_delete = []
          local_zombies.each do |pid,kill_data|
            begin
              when_killed, times_killed = kill_data
              elapsed = Time.now - when_killed
              sig = if elapsed >= @zombie_term_wait and times_killed == 1
                :TERM
              elsif elapsed >= @zombie_kill_wait and not Resque::Version >= '1.22.0'
                :KILL
              else
                nil
              end
              unless sig.nil?
                log "Waited more than #{@zombie_term_wait} seconds for #{pid}. Sending #{sig}..."
                Process.kill(sig, pid)
                @zombie_pids.merge!({pid => [when_killed, times_killed + 1]})
              end
              wait = !@async ? (@zombie_term_wait - elapsed) / @zombie_pids.length : 0.01
              wait = wait > 0 ? wait : 0.01
              # Issue wait() to make sure pid isn't forgotten
              Timeout::timeout(wait) { Process.wait(pid) }
              to_delete << pid
              next
            rescue Timeout::Error
              # waited too long so just catch and ignore, and continue
            rescue Errno::ESRCH, Errno::ECHILD # child is gone
              to_delete << pid
              next
            end
          end
          to_delete.each { |pid| @zombie_pids.delete(pid) }
        end

        def kill_child(pid)
          begin
            Process.kill(:QUIT, pid) # try graceful shutdown
            log! "Child #{pid} killed. (#{@pids.keys.length-1})"
          rescue Object => e # dunno what this does but it works; dont know exception
            log! "Child #{pid} already dead, sad day. (#{@pids.keys.length-1}) #{e}"
          ensure
            # Keep track of ones we've killed
            @zombie_pids[pid] = [Time.now, 1] # set to current time, killed #
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
