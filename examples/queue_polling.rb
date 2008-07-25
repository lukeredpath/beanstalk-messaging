$:.unshift(File.join(File.dirname(__FILE__), *%w[.. lib]))

require 'init'
require 'beanstalk_manager'

# start up a beanstalk queue
daemon_manager = Beanstalk::DaemonManager.new(File.dirname(__FILE__))
daemon_manager.register_daemon('dummy', '0.0.0.0', 33000)
daemon_manager.run('dummy')

# create a global queue manager
$queue_manager = Beanstalk::QueueManager.new({:dummy => {:host => '0.0.0.0', :port => 33000}})

# set up a queue poller
class MessageProcessor
  attr_reader :messages
  
  def initialize
    @messages = []
  end
  
  def process(message)
    @messages << message
  end
end

consumer = Thread.new do
  processor = MessageProcessor.new
  poller = Beanstalk::QueuePoller.new($queue_manager)
  poller.poll(:dummy) do |message|
    puts "C: Received - #{message.ybody}"
    processor.process(message.ybody)
    if processor.messages.length == 50
      $stdout.puts "Received 50 messages...exiting."
      daemon_manager.kill_all
      exit
    end
  end
end

producer = Thread.new do
  queue = $queue_manager.queue(:dummy)
  51.times do |x|
    queue << "Message #{x}"
    sleep 0.1
    puts "P: Sent message #{x}"
  end
end

producer.join
consumer.join
