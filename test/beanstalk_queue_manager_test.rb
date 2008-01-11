require File.dirname(__FILE__) + '/test_helper'

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