require File.dirname(__FILE__) + '/test_helper'

class BeanstalkQueuePollerTest < Test::Unit::TestCase
  
  def test_should_output_messages_to_given_output_object
    message = "Hello"
    poller = Beanstalk::QueuePoller.new(anything, anything, output = stub('output'))
    output.expects(:puts).with(message)
    poller.puts(message)
  end
  
  # This class needs MUCH more testing, but it's not top priority at the moment.
  
end