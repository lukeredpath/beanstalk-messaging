require File.dirname(__FILE__) + '/test_helper'

class BeanstalkQueuePollerTest < Test::Unit::TestCase
  
  def test_should_output_messages_to_given_output_object
    message = "Hello"
    poller = Beanstalk::QueuePoller.new(anything, anything, output = stub('output'))
    output.expects(:puts).with(message)
    poller.puts(message)
  end
  
  def test_poller_yields_the_deserialized_message_body
    
    queue = Beanstalk::Queue.new(pool = stub('pool'))
    queue.stubs(:number_of_pending_messages).returns(1, 0)

    deserialized_message = [1,2,3]    
    message = stub('message')
    message.stubs(:ybody).returns(deserialized_message)
    pool.stubs(:reserve).returns(message)
    
    manager = stub('queue manager')
    manager.stubs(:reset_queue).with(:queue_name).returns(queue)
    
    poller = poller_with_loop_limit 3, manager, 30, stub_everything('output stream')
    
    poller.poll(:queue_name) do |message|
      assert_equal deserialized_message, message
    end
    
  end
  
  
  # This class needs MUCH more testing, but it's not top priority at the moment.
  
  
  private
  
    def poller_with_loop_limit(loop_limit, *args)
      poller = Beanstalk::QueuePoller.new(*args)
      # redefining the loop behaviour to NOT loop forever
      eval %{ def poller.loop
        #{loop_limit}.times { yield }
        puts "looped #{loop_limit} times"
      end }
      poller      
    end
end