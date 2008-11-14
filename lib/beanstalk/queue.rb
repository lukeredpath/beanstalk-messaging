module Beanstalk
  class Queue
    DEFAULT_TUBE = 'default'
    
    attr_reader :current_tube
    
    def initialize(pool)
      @pool = pool
      @stale = false
      @current_tube = 'default'
    end
    
    def self.connect(host, port, timeout = 10000)
      Timeout.timeout(timeout) do
        pool = Beanstalk::Pool.new(["#{host}:#{port}"])
        if pool.open_connections.length >= 1
          new(pool)
        else
          raise ConnectionError.new("Beanstalk::Pool connection failed")
        end
      end
    end
    
    def use_tube(tubename)
      @current_tube = tubename
      @pool.watch(tubename)
      @pool.use(tubename)
    end
    
    def use_default_tube
      use_tube(DEFAULT_TUBE)
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
    rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::ECONNREFUSED
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
    
    def number_of_processed_messages
      total_jobs - number_of_pending_messages
    end
  
    def raw_stats
      @pool.stats_tube(@current_tube)
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
end