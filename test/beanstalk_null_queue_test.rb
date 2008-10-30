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
  
  def test_should_return_nil_when_requesting_next_message
    assert_nil Beanstalk::NullQueue.new.next_message
  end
  
  def test_should_return_a_hash_like_object_for_raw_stats
    assert Beanstalk::NullQueue.new.raw_stats.respond_to?(:[])
  end
  
  def test_should_always_respond_like_a_real_queue
    null_queue = Beanstalk::NullQueue.new
    (Beanstalk::Queue.new(stub).public_methods - Object.public_methods).each do |method|
      assert null_queue.respond_to?(method), "NullQueue should respond to #{method} like a normal Queue"
    end
  end
  
end