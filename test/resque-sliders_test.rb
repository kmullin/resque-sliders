require File.expand_path(File.dirname(__FILE__) + '/test_helper')

context "ResqueSliders" do
  setup do
    Resque.redis.flushall
  end

  test "sliders" do
    ret = 1
    assert_equal 1, ret
  end
end
