module Beanstalk
  
  class QueuePoller
    def initialize(queue_manager, retry_delay = 30, output = STDOUT)
      @queue_manager = queue_manager
      @output = output
      @retry_delay = retry_delay
    end
    
    def puts(object)
      @output.puts(object)
    end
    
    def load_queue!(queue_name)
      retry_attempts = 0
      loop do
        retry_attempts += 1
        puts "Attempting to establish connection to queue (attempt #{retry_attempts})"
        @queue = @queue_manager.reset_queue(queue_name)
        unless @queue.stale?
          puts "Connection established."
          break
        end
        sleep @retry_delay
      end
    end
    
    def poll(queue_name, &block)
      load_queue!(queue_name)
      
      loop do
        if(pending_messages = @queue.number_of_pending_messages) && pending_messages > 0
          begin
            @queue.next_message(&block)
          rescue Beanstalk::UnexpectedResponse => e
            puts "Unexpected response received from Beanstalk (#{e.message}) Waiting before continuing.".
            message.release if message
            sleep @retry_delay
            next
          rescue EOFError, Errno::ECONNRESET, Errno::ECONNREFUSED => e
            puts "Caught exception: '#{e.message}'. Beanstalk daemon has probably gone away."
            retry_attempts = 0
            sleep @retry_delay
            load_queue!(queue_name)
          end
        end
      end # end loop
    end # end def   
  end # end class
  
end