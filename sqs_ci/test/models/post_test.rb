require 'test_helper'

class PostTest < ActiveSupport::TestCase
  test "passing test" do
    sleep 60
    assert true
  end

  test "failing test" do
    sleep 60
    assert false
  end
end
