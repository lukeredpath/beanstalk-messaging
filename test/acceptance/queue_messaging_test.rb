require File.join(File.dirname(__FILE__), *%w[.. test_helper])
require 'beanstalk_manager'

class QueueMessagingTest < Test::Unit::TestCase
  
  def setup
    @manager = Beanstalk::DaemonManager.new(File.dirname(__FILE__))
    @manager.register_daemon('testqueue', '0.0.0.0', 33000)
    @manager.run('testqueue')
    @queue = Beanstalk::Queue.connect('0.0.0.0', 33000)
  end
  
  def teardown
    @manager.kill_all
  end
  
  def test_should_be_able_to_send_a_message_to_the_queue_and_consume_it
    @queue << "Hello World"

    @queue.next_message do |message|
      assert_equal "Hello World", message
    end
    
    assert_equal 0, @queue.number_of_pending_messages
  end
  
  def test_should_allow_fine_grained_control_of_a_messages_life_cycle
    @queue << "Hello World"
    message = @queue.next_message
    assert_equal "Hello World", message.ybody
    message.release
    assert_equal 1, @queue.number_of_pending_messages
  end
  
end