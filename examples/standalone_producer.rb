$:.unshift(File.join(File.dirname(__FILE__), *%w[.. lib]))

require 'init'
require 'beanstalk_manager'

messages_to_produce = ARGV[0].to_i || 100

# start up a beanstalk queue
daemon_manager = Beanstalk::DaemonManager.new(File.dirname(__FILE__))
daemon_manager.register_daemon('dummy', '0.0.0.0', 33000)
daemon_manager.run('dummy')

$queue_manager = Beanstalk::QueueManager.new({:dummy => {:host => '0.0.0.0', :port => 33000}})

queue = $queue_manager.queue(:dummy)
messages_to_produce.times do |i|
  queue << "message #{i}, #{Time.now}"
end
