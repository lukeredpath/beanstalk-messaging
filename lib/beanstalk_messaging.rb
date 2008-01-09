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
  
  class Queue
    def initialize(pool)
      @pool = pool
      @stale = false
    end
    
    def stale?
      @stale
    end
    
    def push(message)
      Timeout.timeout(Beanstalk.connection_timeout) do
        @pool.yput(message)
      end
    rescue Timeout::Error
      @stale = true
    rescue Beanstalk::UnexpectedResponse
      @stale = true
    rescue EOFError, Errno::ECONNRESET, Errno::EPIPE
      @stale = true
    rescue RuntimeError
      @stale = true
    end

    alias :<< :push
    
    def number_of_pending_messages
      raw_stats['current-jobs-ready']
    end
    
    def total_jobs
      raw_stats['total-jobs']
    end
    
    def raw_stats
      @pool.stats
    end
    
    def next_message
      if number_of_pending_messages > 0
        job = @pool.reserve
        if block_given?
          yield job.ybody
          job.delete
        else
          return job
        end
      end
    end
  end
  
  class NullQueue
    def initialize(stale = true)
      @stale = stale
    end
    
    def stale?
      @stale
    end
    
    def push(message)
    end
    alias :<< :push
  end
  
  class ConnectionTimeout < Exception; end
  
  class QueueManager    
    def initialize(config_path)
      @config = YAML.load(File.open(config_path))
      @queues = {}
    end

    def queue(queue_name)
      queue = @queues[queue_name] ||= create_queue(queue_name)
      queue.stale? ? reset_queue(queue_name) : queue
    end
    
    def disable(queue_name)
      @queues[queue_name] = NullQueue.new(stale = false)
    end
    
    def disable_all!
      @config.keys.each { |queue| disable(queue) }
    end

    private
      def create_queue(queue_name)
        raise Messaging::UnknownQueue.new("Unknown queue: #{queue_name}. Check your configuration.") unless @config[queue_name]
        host, port  = @config[queue_name][:host], @config[queue_name][:port]
        begin
          Queue.new(create_pool(host, port))
        rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL
          NullQueue.new
        rescue ConnectionTimeout
          NullQueue.new
        end
      end
      
      def create_pool(host, port)
        begin
          Timeout::timeout(Beanstalk.connection_timeout) do
            Beanstalk::Pool.new(["#{host}:#{port}"])
          end
        rescue Timeout::Error
          raise ConnectionTimeout
        end
      end
      
      def reset_queue(queue_name)
        @queues[queue_name] = create_queue(queue_name)
      end
  end
  
end