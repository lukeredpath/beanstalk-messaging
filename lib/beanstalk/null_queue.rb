module Beanstalk
  class NullQueue
    def initialize(stale = true)
      @stale = stale
    end
    
    def stale?
      @stale
    end
    
    def number_of_pending_messages
      0
    end
    
    def total_jobs
      0
    end
    
    def number_of_processed_messages
      0
    end
    
    def push(message); end
    
    alias :<< :push
    
    def next_message(&block)
      nil
    end
    
    def raw_stats
      {}
    end
    
    def use_tube(tube_name); end
    def current_tube; end
    def use_default_tube; end
  end
end  