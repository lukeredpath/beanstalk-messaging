module Beanstalk
  class QueueManager    
    def initialize(config)
      @config = config
      @queues = {}
    end
    
    def self.load(config_path)
      config = YAML.load(File.open(config_path))
      new(config)
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
          Queue.connect(host, port, Beanstalk.connection_timeout)
        rescue ConnectionError
          NullQueue.new
        rescue Timeout::Error
          NullQueue.new
        end
      end
  end
end