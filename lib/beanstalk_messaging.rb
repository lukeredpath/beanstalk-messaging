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
  
  # File lib/beanstalk-client/connection.rb, line 199
  # monkey-patch for version 0.6 of beanstalk-client gem
  class Pool
    def connect()
      @connections ||= {}
      @addrs.each do |addr|
        begin
          if !@connections.include?(addr)
            puts "connecting to beanstalk at #{addr}"
            @connections[addr] = CleanupWrapper.new(addr, self)
          end
        # WE WANT THE EXCEPTIONS TO BE RAISED
        # rescue Exception => ex
        #   puts "#{ex.class}: #{ex}"
        #   #puts begin ex.fixed_backtrace rescue ex.backtrace end
        end
      end
      @connections.size
    end
  end
  
  class ConnectionTimeout < Exception; end
end

require 'beanstalk/queue'
require 'beanstalk/null_queue'
require 'beanstalk/queue_manager'
require 'beanstalk/queue_poller'