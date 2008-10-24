require File.join(File.dirname(__FILE__), *%w[.. test_helper])
require 'beanstalk_manager'

class QueueManagementTest < Test::Unit::TestCase
  
  def setup
    @daemon_manager = Beanstalk::DaemonManager.new(File.dirname(__FILE__))
    @daemon_manager.register_daemon('test_queue_1', '0.0.0.0', 33000)
    @queue_manager = Beanstalk::QueueManager.new({
      :test_queue_1 => {:host => '0.0.0.0', :port => 33000},
      :test_queue_2 => {:host => '1.1.1.1', :port => 33000},
    })
  end
  
  def teardown
    @daemon_manager.kill_all
  end
  
  def test_we_can_connect_to_a_running_daemon
    @daemon_manager.run('test_queue_1')
    assert !@queue_manager.queue(:test_queue_1).stale?
  end
  
  def test_our_code_will_not_fall_over_if_we_try_to_use_a_queue_that_isnt_running
    Beanstalk.connection_timeout = 0.3
    
    assert_nothing_raised do
      @queue_manager.queue(:test_queue_2) << "hello world"
    end
  end
  
  def test_a_freshly_started_queue_has_no_pending_messages
    @daemon_manager.run('test_queue_1')
    assert_equal 0, @queue_manager.queue(:test_queue_1).number_of_pending_messages
  end
  
  def test_our_queue_client_code_will_not_fallover_if_we_suddenly_lose_a_connection
    @daemon_manager.run('test_queue_1')
    queue = @queue_manager.queue(:test_queue_1)
    
    assert_nothing_raised do
      5.times { queue << 'some message' }
      @daemon_manager.kill('test_queue_1') # oh noes!
      5.times { queue << 'some message' }
    end
  end
  
  def test_our_queue_client_code_will_continue_working_seamlessley_once_we_reestablish_a_broken_connection
    @daemon_manager.run('test_queue_1')
    queue = @queue_manager.queue(:test_queue_1)

    5.times { queue << 'some message' }
    @daemon_manager.kill('test_queue_1') # oh noes!
    5.times { queue << 'some message' }
    @daemon_manager.run('test_queue_1')
    5.times { queue << 'some_message' }
    
    assert_equal 5, queue.number_of_pending_messages
  end
  
  def test_we_can_detect_when_a_daemon_is_running
    @daemon_manager.run('test_queue_1')
    assert @daemon_manager.running?('test_queue_1')
    @daemon_manager.kill('test_queue_1')
    assert !@daemon_manager.running?('test_queue_1')
  end
  
end
