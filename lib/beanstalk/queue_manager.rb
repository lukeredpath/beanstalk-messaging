module Beanstalk
  class QueueManager    
    def initialize(config_path)
      @config = YAML.load(File.open(config_path))
      @queues = {}
    end
    
    def available_queues
      @config.keys
    end

    def queue(queue_name)
      queue = @queues[queue_name] ||= create_queue(queue_name)
      queue.stale? ? reset_queue(queue_name) : queue
    end
  
    def disable(queue_name)
      @queues[queue_name] = NullQueue.new(stale = false)
    end
  
    def disable_all!
      available_queues.each { |queue| disable(queue) }
    end
  
    def reset_queue(queue_name)
      @queues[queue_name] = create_queue(queue_name)
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
  end
end