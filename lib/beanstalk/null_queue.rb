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
    
    def push(message); end
    
    alias :<< :push
    
    def next_message(&block)
      nil
    end
  end
end  