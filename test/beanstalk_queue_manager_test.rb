require File.dirname(__FILE__) + '/test_helper'

class BeanstalkQueueManagerTest < Test::Unit::TestCase
  
  def setup    
    @queue_manager = Beanstalk::QueueManager.new({
      :queue_one => { :host => 'localhost', :port => 12000 },
      :queue_two => { :host => 'localhost', :port => 12001 }
    })
  end
  
  def test_should_return_a_beanstalk_queue_using_the_config_for_the_requested_queue_if_it_exists_in_the_config
    Beanstalk::Queue.expects(:connect).with('localhost', 12000, anything).returns(queue = stub('queue', :stale? => false))
    assert_equal queue, @queue_manager.queue(:queue_one)
  end
  
  def test_should_use_connection_timeout_when_connecting_to_a_queue
    Beanstalk.connection_timeout = 2
    Beanstalk::Queue.expects(:connect).with(anything, anything, 2).returns(stub_everything('queue'))
    @queue_manager.queue(:queue_one)
  end
  
  def test_should_raise_an_exception_when_trying_to_access_a_queue_which_is_not_defined_in_the_config
    assert_raises(Messaging::UnknownQueue) do
      @queue_manager.queue(:queue_three)
    end
  end
  
  def test_should_return_the_same_instance_of_a_queue_if_asking_for_the_same_queue_more_than_once
    Beanstalk::Queue.expects(:connect).once.returns(queue = stub('queue', :stale? => false))
    assert_equal queue, @queue_manager.queue(:queue_one)
    assert_equal queue, @queue_manager.queue(:queue_one)
  end
  
  def test_should_return_a_new_instance_of_a_queue_if_existing_queue_has_been_marked_as_stale
    Beanstalk::Queue.stubs(:connect).returns(queue_instance_one = stub('queue 1', :stale? => false))
    assert_equal queue_instance_one, @queue_manager.queue(:queue_one)
    
    queue_instance_one.stubs(:stale?).returns(true)

    Beanstalk::Queue.expects(:connect).returns(queue_instance_two = stub('queue 2', :stale? => false))
    assert_equal queue_instance_two, @queue_manager.queue(:queue_one)
  end
  
  def test_should_return_a_null_queue_if_a_connection_error_occurs
    Beanstalk::Queue.stubs(:connect).raises(Beanstalk::ConnectionError)
    assert_instance_of Beanstalk::NullQueue, @queue_manager.queue(:queue_two)
  end
  
  def test_should_return_null_queue_if_pool_times_out_while_connecting
    Beanstalk::Queue.stubs(:connect).raises(Timeout::Error)
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