require File.dirname(__FILE__) + '/test_helper'

class BeanstalkQueuePollerTest < Test::Unit::TestCase
  
  def setup
    @dev_null = stub_everything('output stream')
  end
  
  def test_should_output_messages_to_given_output_object
    message = "Hello"
    poller = Beanstalk::QueuePoller.new(anything, anything, output = stub('output'))
    output.expects(:puts).with(message)
    poller.puts(message)
  end
  
  def test_should_sleep_for_the_given_delay_until_a_non_stale_queue_was_found
    stale_queue = stub('stale queue', :stale? => true)
    fresh_queue = stub('fresh queue', :stale? => false)
    
    stale_manager = stub('manager with stale queues')
    unsuccessful_connection_attempts = [stale_queue, stale_queue, stale_queue]
    stale_manager.stubs(:reset_queue).returns(*(unsuccessful_connection_attempts + [fresh_queue]))
    
    delay = stub('delay')
    poller = Beanstalk::QueuePoller.new(stale_manager, delay, @dev_null)
    
    poller.expects(:sleep).with(delay).times(unsuccessful_connection_attempts.length)
    
    limit_looping(poller, iterations = 4)
    
    poller.load_queue!(:queue_name)
  end
  
  def test_should_set_instance_queue_when_a_non_stale_queue_is_found
    
    manager = stub('queue manager')
    manager.stubs(:reset_queue).with(:queue_name).returns(queue = stub('queue', :stale? => false))
    
    poller = Beanstalk::QueuePoller.new(manager, 1, @dev_null)
    poller.load_queue!(:queue_name)
    
    assert_equal queue, poller.queue
  end
  
  def test_poller_yields_the_message_from_pool
    queue = Beanstalk::Queue.new(pool = stub('pool'))
    queue.stubs(:number_of_pending_messages).returns(1)

    queued_message = stub('message')
    pool.stubs(:reserve).returns(queued_message)
    queued_message.expects(:delete)
    
    manager = stub('queue manager')
    manager.stubs(:reset_queue).with(:queue_name).returns(queue)
    
    poller = Beanstalk::QueuePoller.new(manager, 30, @dev_null)
    
    limit_looping(poller)
    
    poller.poll(:queue_name) do |message|
      assert_equal queued_message, message
    end
  end
  
  def test_message_should_be_deleted_once_it_has_been_successfully_processed  
    poller = Beanstalk::QueuePoller.new(nil, anything, @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).returns(stubbed_message = stub('message'))
    
    poller.retrieve_and_handle_message(:queue_name) do |message|
      assert_equal stubbed_message, message
      
      # Since this expectation doesn't exist until the very end of this block
      # we can be assured that the method has not been called up until now.
      stubbed_message.expects(:delete) # after this block finishes.
    end
  end

  def test_message_should_NOT_be_deleted_if_beanstalk_received_an_unexpected_response
    poller = Beanstalk::QueuePoller.new(nil, 0.1, @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).returns(stubbed_message = stub_everything('message'))
    
    stubbed_message.expects(:delete).never

    poller.retrieve_and_handle_message(:queue_name) do |message|
      assert_equal stubbed_message, message # just to be sure we're checking the right message
      raise Beanstalk::UnexpectedResponse.new("Oh no!")
    end
  end
  
  def test_message_should_be_released_if_a_message_was_found_but_a_beanstalk_error_was_found_anyway
    poller = Beanstalk::QueuePoller.new(nil, 0.1, @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).returns(stubbed_message = stub_everything('message'))
    
    poller.retrieve_and_handle_message(:queue_name) do |message|
      message.expects(:release) # after this block returns
      raise Beanstalk::UnexpectedResponse.new("Oh no!")
    end
  end

  def test_polling_should_wait_if_a_beanstalk_error_occurred_while_polling
    poller = Beanstalk::QueuePoller.new(nil, delay = stub('delay'), @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).returns(stubbed_message = stub_everything('message'))
    
    poller.retrieve_and_handle_message(:queue_name) do |message|
      poller.expects(:sleep).with(delay) # after this block returns
      raise Beanstalk::UnexpectedResponse.new("Oh no!")
    end
  end

  def test_polling_should_sleep_and_reload_the_queue_if_a_EOFerror_occurred_while_retrieving_the_next_message
    poller = Beanstalk::QueuePoller.new(nil, delay = stub('delay'), @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).raises(EOFError)
    
    poller.expects(:puts).with(regexp_matches(/Caught exception/))
    poller.expects(:sleep).with(delay) # after this block returns
    poller.expects(:load_queue!)

    poller.retrieve_and_handle_message(:queue_name) do |message|
      flunk "This block should never get called"
    end
  end
  
  def test_polling_should_sleep_and_reload_the_queue_if_a_connection_reset_error_occurred_while_retrieving_the_next_message
    poller = Beanstalk::QueuePoller.new(nil, delay = stub('delay'), @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).raises(Errno::ECONNRESET)
    
    poller.expects(:puts).with(regexp_matches(/Caught exception/))
    poller.expects(:sleep).with(delay) # after this block returns
    poller.expects(:load_queue!)

    poller.retrieve_and_handle_message(:queue_name) do |message|
      flunk "This block should never get called"
    end
  end
  
  def test_polling_should_sleep_and_reload_the_queue_if_a_connection_refused_error_occurred_while_retrieving_the_next_message
    poller = Beanstalk::QueuePoller.new(nil, delay = stub('delay'), @dev_null)
    poller.stubs(:queue).returns(queue = stub('queue'))
    queue.stubs(:number_of_pending_messages).returns(1)
    queue.stubs(:next_message).raises(Errno::ECONNREFUSED)
    
    poller.expects(:puts).with(regexp_matches(/Caught exception/))
    poller.expects(:sleep).with(delay) # after this block returns
    poller.expects(:load_queue!)

    poller.retrieve_and_handle_message(:queue_name) do |message|
      flunk "This block should never get called"
    end
  end    
  
  private
  
  def limit_looping(object, iterations = 1)
    object.instance_eval %{
      def loop
        #{iterations}.times { yield }
      end
    }
  end
end