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
    
    def method_missing(*args)
      # do nothing
    end
  end
end  