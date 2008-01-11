require File.dirname(__FILE__) + '/test_helper'

class NullQueueTest < Test::Unit::TestCase
  
  def test_should_be_stale_by_default
    assert Beanstalk::NullQueue.new.stale?
  end
  
  def test_should_be_able_to_initialized_with_custom_stale_state
    assert !Beanstalk::NullQueue.new(stale = false).stale?
  end
  
  def test_should_respond_to_push
    assert_respond_to Beanstalk::NullQueue.new, :push
  end
  
  def test_should_respond_to_shift_operator
    assert_respond_to Beanstalk::NullQueue.new, :<<
  end
  
  def test_should_always_have_zero_pending_messages
    assert_equal 0, Beanstalk::NullQueue.new.number_of_pending_messages
  end
  
end