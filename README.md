Resque Sliders
==============

[github.com/kmullin/resque-sliders](https://github.com/kmullin/resque-sliders)

Description
-----------

ResqueSliders is a [Resque](https://github.com/defunkt/resque) plugin which allows you
to control Resque workers from the Web-UI.

Allows you to (all from the Resque-Web UI):

* Start workers with any queue, or combination of queues on any host, and specify how many of each should be running
* Pause / Stop / Restart ALL running workers


ResqueSliders comes with two parts:

* `KEWatcher`: A daemon that runs on any machine that needs to run Resque workers, watches over the workers and controls which ones are running
* `Resque-Web Plugin`: A bunch of slider bars, with text-input box to specify what queues to run on the workers


Resque-Web Integration
----------------------
![Screen 1](https://github.com/kmullin/resque-sliders/raw/master/misc/resque-sliders_main-view.png)
![Screen 2](https://github.com/kmullin/resque-sliders/raw/master/misc/resque-sliders_host-view.png)

You have to load ResqueSliders to enable the Sliders tab.

```ruby
require 'resque-sliders'
```
