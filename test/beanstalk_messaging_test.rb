require File.dirname(__FILE__) + '/../test_helper'
require 'beanstalk-client/version'

class BeanstalkTest < Test::Unit::TestCase
  def test_should_be_using_version_0_point_6_of_the_gem
    assert_equal '0.6.0', Beanstalk::VERSION::STRING,
     "We currently monkey-patch the Pool class - you'll need to check this before upgrading the version"
  end
  
  def test_should_have_a_default_connection_timeout_of_1_second
    Beanstalk.connection_timeout = nil
    assert_equal 1, Beanstalk.connection_timeout
  end
end

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

class BeanstalkQueueManagerTest < Test::Unit::TestCase
  
  def setup
    @config_path = '/tmp/beanstalk.yml'
    
    File.stubs(:open).with(@config_path).returns(config_file = stub('io'))
    YAML.stubs(:load).with(config_file).returns({
      :queue_one => { :host => 'localhost', :port => 12000 },
      :queue_two => { :host => 'localhost', :port => 12001 }
    })
    
    @queue_manager = Beanstalk::QueueManager.new(@config_path)
  end
  
  def test_should_return_a_beanstalk_queue_using_the_config_for_the_requested_queue_if_it_exists_in_the_config
    Beanstalk::Pool.stubs(:new).with(['localhost:12000']).returns(pool = stub('pool'))
    Beanstalk::Queue.stubs(:new).with(pool).returns(queue = stub('queue', :stale? => false))
    
    assert_equal queue, @queue_manager.queue(:queue_one)
  end
  
  def test_should_raise_an_exception_when_trying_to_access_a_queue_which_is_not_defined_in_the_config
    assert_raises(Messaging::UnknownQueue) do
      @queue_manager.queue(:queue_three)
    end
  end
  
  def test_should_return_the_same_instance_of_a_queue_if_asking_for_the_same_queue_more_than_once
    Beanstalk::Pool.stubs(:new).with(['localhost:12000']).returns(pool = stub('pool'))
    Beanstalk::Queue.stubs(:new).with(pool).returns(queue = stub('queue', :stale? => false))
    
    assert_equal queue, @queue_manager.queue(:queue_one)
    assert_equal queue, @queue_manager.queue(:queue_one)
  end
  
  def test_should_return_a_new_instance_of_a_queue_if_existing_queue_has_been_marked_as_stale
    Beanstalk::Pool.stubs(:new).with(['localhost:12000']).returns(pool = stub('pool'))
    Beanstalk::Queue.stubs(:new).with(pool).returns(queue_instance_one = stub('queue 1', :stale? => false))
    
    assert_equal queue_instance_one, @queue_manager.queue(:queue_one)
    
    queue_instance_one.stubs(:stale?).returns(true)
    Beanstalk::Pool.stubs(:new).with(['localhost:12000']).returns(pool_two = stub('pool'))
    Beanstalk::Queue.stubs(:new).with(pool_two).returns(queue_instance_two = stub('queue 2', :stale? => false))
    
    assert_equal queue_instance_two, @queue_manager.queue(:queue_one)
  end
  
  def test_should_return_a_null_queue_if_queue_connection_cannot_be_established
    Beanstalk::Pool.stubs(:new).raises(Errno::ECONNREFUSED)
    
    assert_instance_of Beanstalk::NullQueue, @queue_manager.queue(:queue_two)
  end
  
  def test_should_return_a_null_queue_if_queue_connection_address_is_unavailable
    Beanstalk::Pool.stubs(:new).raises(Errno::EADDRNOTAVAIL)
    
    assert_instance_of Beanstalk::NullQueue, @queue_manager.queue(:queue_two)
  end
  
  def test_should_return_null_queue_if_pool_times_out_while_connecting
    @queue_manager.stubs(:create_pool).raises(Beanstalk::ConnectionTimeout)

    assert_instance_of Beanstalk::NullQueue, @queue_manager.queue(:queue_two)    
  end
  
  def test_should_always_return_the_same_null_queue_for_a_disabled_queue
    @queue_manager.disable(:queue_two)
    
    queue = @queue_manager.queue(:queue_two)
    assert_instance_of Beanstalk::NullQueue, queue
    assert_equal queue, @queue_manager.queue(:queue_two)
  end
  
  def test_should_be_able_to_disable_all_queues
    @queue_manager.expects(:disable).with(:queue_one)
    @queue_manager.expects(:disable).with(:queue_two)
    
    @queue_manager.disable_all!
  end
end

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
  
end