require 'beanstalk-client'
require 'timeout'

module Messaging
  class UnknownQueue < Exception; end
end

module Beanstalk
  
  class_eval do
    attr_writer :connection_timeout
    
    def connection_timeout
      @connection_timeout || 1
    end
  end
  
  class Pool
    def stdout_messages
      @stdout_messages ||= []
    end
    
    def puts(message)
      stdout_messages << message
    end
  end
  
  class ConnectionError < StandardError; end
end

require 'beanstalk/queue'
require 'beanstalk/null_queue'
require 'beanstalk/queue_manager'
require 'beanstalk/queue_poller'