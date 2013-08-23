Resque Sliders [![Build Status](https://secure.travis-ci.org/kmullin/resque-sliders.png)](http://travis-ci.org/kmullin/resque-sliders)
==============

[github.com/kmullin/resque-sliders](https://github.com/kmullin/resque-sliders)


Description
-----------

ResqueSliders is a [Resque](https://github.com/defunkt/resque) plugin which allows you
to control Resque workers from the Web-UI.

From the Resque-Web UI, you can:

* Start workers with any queue, or combination of queues on any host, and specify how many of each should be running
* Pause / Stop / Restart ALL running workers

ResqueSliders comes in two parts:

* `KEWatcher`: A daemon that runs on any machine that needs to run Resque workers, watches over the workers and controls which ones are running
* `Resque-Web Plugin`: A bunch of slider bars, with text-input box to specify what queues to run on the workers


Installation
------------

Install as a gem:

    $ gem install resque-sliders

### KEWatcher

This is the daemon component that runs on any host that you want to run Resque workers on. The daemon's job is to manage **how many** Resque workers should be running, and **what** they should be running. It also provides an easy way to stop all workers during maintenance or deploys.

When the daemon first runs, it will register itself, by hostname with Redis:

* Adds a few persistent settings to the hash key `resque:plugins:resque-sliders:host_configs` (max_children, current_children)
* Gets any queues that need to be running on the host by looking at `resque:plugins:resque-sliders:` + `hostname`

```
Usage: kewatcher [options]

Options:
    -c, --config CONFIG              Resque Config (Yaml)
    -q, --queues QUEUE_CONFIG        Worker Queue Config (Yaml)
    -r, --rakefile RAKEFILE          Rakefile location
    -p, --pidfile PIDFILE            PID File location
    -f, --force                      FORCE KILL ANY OTHER RUNNING KEWATCHERS
    -v, --verbose                    Verbosity (Can be specified more than once, -vv)
    -m, --max MAX                    Max Children (default: 10)
    -w, --wait WAIT_TIME             Time (in seconds) to wait for worker to die before sending TERM signal (default: 20 seconds)
    -t, --time MAX_TIME              Max Time (in seconds) to wait for worker to die before sending KILL (-9) signal (FORCE QUIT) (default: 60)
                                     NOTE: With Resque >= 1.22.0 force quit is handled for you so by default this is the same as:
                                           RESQUE_TERM_TIMEOUT=40 or the difference of MAX_TIME and WAIT_TIME
                                           more info: http://hone.heroku.com/resque/2012/08/21/resque-signals.html
    -a, --async                      Do NOT wait for Resque workers to die completely before spawning new workers (default: false)
    -V, --version                    Prints Version
```

#### Important Options

```
    -m|--max MAX            (Max Children): Maximum number of workers to run on host (default: 10)
    -w|--wait WAIT_TIME     (Wait Time): How long to wait before sending TERM to zombies (default: 20 seconds)
    -t|--time TIME          (Total Time): How long to wait before sending KILL to zombies (default: 60 seconds)
                            NOTE: Resque >= 1.22.0 includes signal handling of its own to force quit, so we use it if its there, and override with our own timeout here
    -a|--async              (Async): Should we spawn new workers before old ones have fully terminated (default: false)
    -r|--rakefile RAKEFILE  (Rakefile): Pass along a rakefile to use when calling rake ... resque:work - shouldn't be needed if run from project directory
    -f|--force              (Force): Force any currently running KEWatcher processes to quit, waiting for it to do so, and starting in its place
                            RAILS_ENV: If you're using rails, you need to set your RAILS_ENV variable
```

#### Example YAML

An example of the resque.yml and an example of queues.yaml are included under this gem's config directory

Queues are configured as follows:

    development: 
      'images': 1
      'mail,sms': 1
      '*': 1
    test:
      '*': 1
    staging:
      '*': 1
    production:
      'images': 4
      'mail,sms': 1


#### Controlling the Daemon

Once the daemon is running on each host that is going to run Resque workers, you'll need to tell them which queues to run.

#### Signals

KEWatcher supports all the [same signals as Resque](https://github.com/defunkt/resque#signals):

* `TERM` / `INT` / `QUIT` - Shutdown. Gracefully kill all child Resque workers, and wait for them to finish before exiting
* `HUP`  - Restart all Resque workers by gracefully killing them, and starting new ones in their place
* `USR1` - Stop all Resque workers, and don't start any more
* `USR2` - Pause spawning of new queues, but leave current ones running
* `CONT` - Unpause. Continue spawning/managing child Resque workers

The queue configuration is done via Resque-Web interface

#### Resque-Web

See below for screenshots

Buttons:

* `Play` / `Pause` - Start or Pause
* `Stop` - Stop all workers
* `Reload` - Sends HUP signal to running KEWatcher


### Resque-Web Integration

**Main Screen:** showing 3 hosts, and showing that one of the nodes is not running KEWatcher
![Screen 1](https://github.com/kmullin/resque-sliders/raw/master/misc/resque-sliders_main-view.png)

**Host Screen:** showing different `QUEUE` combinations (comma separated) and slider bars indicating how many of each of them should run
![Screen 2](https://github.com/kmullin/resque-sliders/raw/master/misc/resque-sliders_host-view.png)

To enable the Resque-Web Integration you'll need to load ResqueSliders to enable the Sliders tab. Just add:

```ruby
require 'resque-sliders'
```
to a file, like resque-web_init.rb, and run resque-web:

    resque-web resque-web_init.rb


Works on
--------

`resque-sliders` has been tested on the following platforms:

#### Ruby

* 1.9.3
* 1.8.7 (ree)
* probabaly more...

Contributing
------------

Want to fix a bug? See a new feature?

1. [Fork](https://github.com/kmullin/resque-sliders/fork_select) me
2. Create a new branch
3. Open a [Pull Request](https://github.com/kmullin/resque-sliders/pull/new)
