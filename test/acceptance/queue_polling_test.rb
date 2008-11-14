require File.join(File.dirname(__FILE__), *%w[.. test_helper])
require 'beanstalk_manager'

class QueuePollingTest < Test::Unit::TestCase
  
  def setup
    @manager = Beanstalk::DaemonManager.new(File.dirname(__FILE__))
    @manager.register_daemon('testqueue', '0.0.0.0', 33000)
    @manager.run('testqueue')
    @queue_manager = Beanstalk::QueueManager.new({:testqueue => {:host => '0.0.0.0', :port => 33000}})
  end
  
  def teardown
    @manager.kill_all
  end
  
  def test_should_collect_messages_as_they_are_received
    collected = []
    
    consumer = Thread.new do
      poller = Beanstalk::QueuePoller.new(@queue_manager, timeout = 30, output = stub_everything('output stream'))
      poller.poll(:testqueue) do |message|
        collected << message
      end
    end
    
    queue = Beanstalk::Queue.connect('0.0.0.0', 33000)
    sleep 0.5 # give the poller and queue connection time to start up

    10.times do
      queue << 'message'
    end
    
    sleep 1
    consumer.kill
    
    assert_equal 10, collected.length
  end
  
end