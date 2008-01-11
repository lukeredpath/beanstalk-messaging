module Beanstalk
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
end