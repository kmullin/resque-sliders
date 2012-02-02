Resque Sliders
==============

[github.com/kmullin/resque-sliders](https://github.com/kmullin/resque-sliders)

Description
-----------

ResqueSliders is a [Resque](https://github.com/defunkt/resque) plugin which allows you
to control Resque workers from the Web-UI.

From the Resque-Web UI, you can:

* Start workers with any queue, or combination of queues on any host, and specify how many of each should be running
* Pause / Stop / Restart ALL running workers


ResqueSliders comes with two parts:

* `KEWatcher`: A daemon that runs on any machine that needs to run Resque workers, watches over the workers and controls which ones are running
* `Resque-Web Plugin`: A bunch of slider bars, with text-input box to specify what queues to run on the workers

Installation
------------

Install as a gem:

```
$ gem install resque-sliders
```

KEWatcher
---------
This is the daemon component that runs on any host that you want to run Resque workers on. The daemon's job is to manage how many Resque workers should be running, and what they should be running. It also provides an easy way to stop all workers during maintenance or deploys.

When the daemon first runs, it will register itself, by hostname with Redis:

* Adds a few persistent settings to the hash key `resque:plugins:resque-sliders:host_configs` (max_children, current_children)
* Gets any queues that need to be running on the host by looking at `resque:plugins:resque-sliders:` + `hostname`

```
Usage: kewatcher [options]

Options:
    -c, --config CONFIG              Resque Config (Yaml)
    -r, --rakefile RAKEFILE          Rakefile location
    -p, --pidfile PIDFILE            PID File location
    -f, --force                      FORCE KILL ANY OTHER RUNNING KEWATCHERS
    -v, --verbose                    Verbosity (Can be specified more than once, -vv)
    -m, --max MAX                    Max Children
    -h, --help                       This help
```

**Important Options**

* `Max Children (-m|--max MAX)`: Maximum number of workers to run on host (default: 10)
* `Rakefile (-r|--rakefile RAKEFILE)`: Pass along a rakefile to use when calling `rake ... resque:work` - shouldn't be needed if run from project directory
* `Force (-f|--force)`: Force any currently running KEWatcher processes to QUIT, waiting for it to do so, and starting in its place
* `RAILS_ENV`: If you're using rails, you need to set your RAILS_ENV variable

**Controlling the Daemon**

`KEWatcher` supports all the same signals as `Resque`:

* `TERM`, `INT`, `QUIT`: Shutdown. Gracefully kill all child Resque workers, and wait for them to finish before exiting
* `HUP`: Restart all Resque workers by gracefully killing them, and starting new ones in their place
* `USR1`: Stop all Resque workers, and don't start any more
* `USR2`: Pause spawning of new queues, but leave current ones running
* `CONT`: Unpause. Continue spawning/managing child Resque workers


Resque-Web Integration
----------------------
**Main Screen:** showing 3 hosts (node01-03), and showing that nodes 1 and 3 aren't running their KEWatchers
![Screen 1](https://github.com/kmullin/resque-sliders/raw/master/misc/resque-sliders_main-view.png)

**Host Screen:** showing 3 different `QUEUE` combinations (comma separated) and slider bars indicating how many of each of them should run on node02
![Screen 2](https://github.com/kmullin/resque-sliders/raw/master/misc/resque-sliders_host-view.png)

To enable the Resque-Web Integration you'll need to load ResqueSliders to enable the Sliders tab. Just add:

```ruby
require 'resque-sliders'
```
to a file, like resque-web_init.rb, and run resque-web:

```
resque-web resque-web_init.rb
```
