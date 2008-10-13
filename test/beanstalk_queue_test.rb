require File.dirname(__FILE__) + '/test_helper'

class BeanstalkQueueTest < Test::Unit::TestCase
  
  def setup
    @connection_pool = stub_everything('pool')
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
    @connection_pool.stubs(:stats_tube).returns({'current-jobs-ready' => 15})
    assert_equal 15, @queue.number_of_pending_messages
  end
  
  def test_should_return_the_total_number_of_messages_added_to_the_queue
    @connection_pool.stubs(:stats_tube).returns({'total-jobs' => 1500})
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
  
  def test_should_tell_the_connection_pool_to_use_and_watch_tube_when_calling_use_tube
    @connection_pool.expects(:use).with('tubename')
    @connection_pool.expects(:watch).with('tubename')
    @queue.use_tube('tubename')
  end
  
  def test_should_report_the_current_tube_name
    @connection_pool.stubs(:use)
    @connection_pool.stubs(:watch)
    @queue.use_tube('tubename')
    assert_equal 'tubename', @queue.current_tube
  end
  
  def test_should_use_default_tube_by_default
    assert_equal 'default', @queue.current_tube
  end
end

class BeanstalkQueueConnectedToTubeTest < Test::Unit::TestCase
  
  def setup
    @connection_pool = stub_everything('pool')
    @queue = Beanstalk::Queue.new(@connection_pool)
    @queue.use_tube('dummy')
  end
  
  def test_should_return_number_of_pending_messages_for_the_current_tube
    @connection_pool.stubs(:stats_tube).with('dummy').returns({'current-jobs-ready' => 5})
    assert_equal 5, @queue.number_of_pending_messages
  end
  
  def test_should_return_total_jobs_for_the_current_tube
    @connection_pool.stubs(:stats_tube).with('dummy').returns({'total-jobs' => 50})
    assert_equal 50, @queue.total_jobs
  end
  
end

class LazyConnectionPool
  attr_accessor :sleep_time
  
  def yput(message)
    sleep sleep_time
    throw :yo_momma_from_the_train
  end
  
  def watch(tube)    
  end
  
  def use(tube)    
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

class BeanstalkQueueConnectionTest < Test::Unit::TestCase
  
  def test_should_establish_a_pool_connection_and_return_a_new_queue_instance
    Beanstalk::Pool.expects(:new).with(["localhost:4000"]).returns(pool = stub(:open_connections => [stub]))
    Beanstalk::Queue.stubs(:new).with(pool).returns(queue = stub)
    assert_equal queue, Beanstalk::Queue.connect('localhost', 4000)
  end
  
  def test_should_raise_a_connection_error_if_beanstalk_pool_has_no_open_connections_after_creating
    Beanstalk::Pool.stubs(:new).returns(pool = stub(:open_connections => []))    
    assert_raises(Beanstalk::ConnectionError) do
      Beanstalk::Queue.connect('localhost', 4000)
    end
  end
  
  def test_should_raise_timeout_error_if_connection_cannot_be_established_in_the_specified_time
    Timeout.expects(:timeout).with(5).raises(Timeout::Error)
    assert_raises(Timeout::Error) do
      Beanstalk::Queue.connect('localhost', 4000, timeout = 5)
    end
  end
  
  def test_should_use_a_really_long_timeout_duration_to_simulate_no_timeout_if_not_specified
    Timeout.expects(:timeout).with(long_time = 10000).yields
    Beanstalk::Pool.stubs(:new).returns(stub_everything(:open_connections => [stub]))
    Beanstalk::Queue.connect('localhost', 4000)
  end
  
end