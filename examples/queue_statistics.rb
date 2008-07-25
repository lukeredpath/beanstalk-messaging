$:.unshift(File.join(File.dirname(__FILE__), *%w[.. lib]))

require 'init'
require 'beanstalk_manager'
require 'beanstalk/statistics_table_printer'

queue_host = ARGV[0] || '0.0.0.0'
queue_port = ARGV[1] || 33000

$stdout = StringIO.new

queue_manager = Beanstalk::QueueManager.new({:example => {:host => queue_host, :port => queue_port}})
stats_printer = Beanstalk::StatisticsTablePrinter.new(queue_manager, "Beanstalk Queue Statistics")
rendered_table = stats_printer.render(:example)

$stdout = STDOUT

puts rendered_table
