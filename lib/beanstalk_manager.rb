require 'rubygems'
require 'fileutils'
require 'beanstalk-client'

module Beanstalk
  
  class Daemon
    attr_reader :port
    
    def initialize(host, port)
      @host, @port = host, port
    end
    
    def run(daemonize = true)
      optstring = "-l #{@host} -p #{@port}"
      optstring << " -d" if daemonize
      if system("beanstalkd #{optstring}")
        return api_connection
      else
        return false
      end
    end
    
    def api_connection
      RawConnection.new("#{@host}:#{@port}")
    rescue Errno::ECONNREFUSED
      nil
    end
  end
  
  class UnknownDaemon < StandardError; end
  
  class DaemonManager
    def initialize(pid_folder)
      @pid_folder = pid_folder
      @daemons = {}
    end
    
    def register_daemon(name, host, port)
      @daemons[name] = Daemon.new(host, port)
    end
    
    def run_all
      @daemons.keys.map { |name| run(name) }
    end
    
    def run(daemon_name)
      if daemon = @daemons[daemon_name]
        if conn = daemon.run
          pid = conn.stats['pid']
          pid_path = File.join(@pid_folder, "beanstalk_#{daemon.port}.pid")
          File.open(pid_path, 'w') { |io| io.write(pid) }
          pid
        else
          nil
        end
      else
        raise UnknownDaemon
      end
    end
    
    def configured_queues
      @daemons.keys
    end
    
    def kill(daemon_name)
      kill_daemon(File.join(@pid_folder, "beanstalk_#{@daemons[daemon_name].port}.pid"))
    end
    
    def stats
      @daemons.inject({}) do |hash, (name, daemon)| 
        begin
          stats = daemon.api_connection.stats rescue nil || "Not running"
        rescue EOFError
          stats = "Not running"
        end
        hash[name] = stats
        hash
      end
    end
    
    def kill_all
      Dir[File.join(@pid_folder, "beanstalk_*.pid")].each { |pid_file| kill_daemon(pid_file) }
    end
    
    private
      def kill_daemon(pid_file)
        system("kill -9 #{File.read(pid_file)}")
        FileUtils.rm_f(pid_file)
      end
  end
end