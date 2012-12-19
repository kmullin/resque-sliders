require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require 'tempfile'

context "kewatcher" do
  setup do
    Resque.redis.flushall
    pidfile = Tempfile.new('pidfile')
    @options = {
      :pidfile => pidfile.path,
      :config => '127.0.0.1:9736'
    }
    @kewatcher = Resque::Plugins::ResqueSliders::KEWatcher.new(@options)
  end

  teardown do
    pid = @kewatcher.running?
    Process.kill(:TERM, pid) if pid
  end

  test "kewatcher" do
    assert_instance_of Resque::Plugins::ResqueSliders::KEWatcher, @kewatcher
  end

  test "saves pidfile" do
    assert File.exists?(@kewatcher.pidfile)
  end

  test "kewatcher runs" do
    `(bundle exec kewatcher --config #{@options[:config]}) >/dev/null 2>&1 & sleep 3`
    assert @kewatcher.running?
  end

  test "kewatcher wont run twice" do
    `(bundle exec kewatcher --config #{@options[:config]}) >/dev/null 2>&1 &`
    sleep 3
    output = `bundle exec kewatcher --config #{@options[:config]}`
    assert_match %r{Already running}, output
  end

  test "system forks" do
    assert fork { exit }
  end

end
