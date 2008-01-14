require File.dirname(__FILE__) + '/test_helper'

class BeanstalkQueueTest < Test::Unit::TestCase
  
  def setup
    @connection_pool = mock('pool')
    @queue = Beanstalk::Queue.new(@connection_pool)
  end
  
  def test_should_not_be_marked_as_stale_after_creation
    assert !@queue.stale?
  end
  
  def test_should_push_message_on_to_queue_as_yaml_when_calling_push
    @connection_pool.expects(:yput).with('foobar')
    @queue.push('foobar')
  end
  
  def test_should_respond_to_the_shift_operator_as_an_alias_of_push
    @connection_pool.expects(:yput).with('foobar')
    @queue << 'foobar'
  end
  
  def test_should_mark_queue_as_stale_if_connection_pool_raises_unexpected_response
    @connection_pool.stubs(:yput).raises(Beanstalk::UnexpectedResponse)
    @queue.push('foobar')
    assert @queue.stale?
  end
  
  def test_should_mark_queue_as_stale_if_connection_pool_raises_end_of_file_error
    @connection_pool.stubs(:yput).raises(EOFError)
    @queue.push('foobar')
    assert @queue.stale?
  end
  
  def test_should_mark_queue_as_stale_if_connection_pool_connection_is_reset
    @connection_pool.stubs(:yput).raises(Errno::ECONNRESET)
    @queue.push('foobar')
    assert @queue.stale?
  end
  
  def test_should_mark_queue_as_stale_if_connection_pool_connection_is_refused
    @connection_pool.stubs(:yput).raises(Errno::ECONNREFUSED)
    @queue.push('foobar')
    assert @queue.stale?
  end
  
  def test_should_mark_queue_as_stale_if_connection_pool_raises_broken_pipe_error
    @connection_pool.stubs(:yput).raises(Errno::EPIPE)
    @queue.push('foobar')
    assert @queue.stale?
  end
  
  def test_should_mark_queue_as_stale_if_connection_pool_raises_a_runtime_error
    @connection_pool.stubs(:yput).raises(RuntimeError)
    @queue.push('foobar')
    assert @queue.stale?
  end
  
  def test_should_return_the_number_of_pending_messages
    @connection_pool.stubs(:stats).returns({'current-jobs-ready' => 15})
    assert_equal 15, @queue.number_of_pending_messages
  end
  
  def test_should_return_the_total_number_of_messages_added_to_the_queue
    @connection_pool.stubs(:stats).returns({'total-jobs' => 1500})
    assert_equal 1500, @queue.total_jobs
  end
  
  def test_should_reserve_and_yield_the_next_available_job_body_then_delete_it_when_calling_next_message_with_a_block
    @queue.stubs(:number_of_pending_messages).returns(1)
    @connection_pool.expects(:reserve).once.returns(job = stub('job', :ybody => 'yaml contents'))
    job.expects(:delete).once
    @queue.next_message { |next_message| assert_equal 'yaml contents', next_message }
  end
  
  def test_should_reserve_and_return_the_next_available_job_without_deleting_if_calling_next_message_without_a_block
    @queue.stubs(:number_of_pending_messages).returns(1)
    @connection_pool.expects(:reserve).once.returns(job = stub('job'))
    job.expects(:delete).never
    assert_equal job, @queue.next_message
  end
  
  def test_should_return_nil_for_next_message_if_there_are_no_available_jobs
    @queue.stubs(:number_of_pending_messages).returns(0)
    assert_nil @queue.next_message
  end
end

class LazyConnectionPool
  attr_accessor :sleep_time
  
  def yput(message)
    sleep sleep_time
    throw :yo_momma_from_the_train
  end
end

class BeanstalkQueueWithTimingOutConnectionPool < Test::Unit::TestCase
  
  def setup
    @connection_pool = LazyConnectionPool.new
    @queue = Beanstalk::Queue.new(@connection_pool)
  end
  
  def test_should_mark_queue_as_stale_if_a_push_call_takes_longer_than_the_configured_timeout
    Beanstalk.connection_timeout = 0.05
    @connection_pool.sleep_time = 0.1
    @queue.push('foobar')
    assert @queue.stale?
  end
  
end