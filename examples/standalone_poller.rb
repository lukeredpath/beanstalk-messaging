$:.unshift(File.join(File.dirname(__FILE__), *%w[..]))
$:.unshift(File.join(File.dirname(__FILE__), *%w[.. lib]))

require 'init'
require 'beanstalk_manager'

queue_host = ARGV[0] || '0.0.0.0'
queue_port = ARGV[1] || 33000

$queue_manager = Beanstalk::QueueManager.new({:example => {:host => queue_host, :port => queue_port}})

class MessageProcessor
  attr_reader :messages
  
  def initialize(output)
    @output = output
  end
  
  def process(message)
    File.open(@output, 'w+') { |io| io.write(message) }
  end
end

processor = MessageProcessor.new(File.join(File.dirname(__FILE__), *%w[messages_received.txt]))

puts "Polling #{$queue_manager.queue(:example)}. #{$queue_manager.queue(:example).number_of_pending_messages} pending messages."

poller = Beanstalk::QueuePoller.new($queue_manager)
poller.poll(:example) do |message|
  puts "C: Received - #{message.ybody}"
  processor.process(message.ybody)
end

trap('INT') {
  exit
}
