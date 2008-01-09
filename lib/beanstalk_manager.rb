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
  
  class DaemonManager
    def initialize(pid_folder)
      @pid_folder = pid_folder
      @daemons = []
    end
    
    def register_daemon(host, port)
      @daemons << Daemon.new(host, port)
    end
    
    def run_all
      @daemons.map do |daemon|
        if conn = daemon.run
          pid = conn.stats['pid']
          pid_path = File.join(@pid_folder, "beanstalk_#{daemon.port}.pid")
          File.open(pid_path, 'w') { |io| io.write(pid) }
          pid
        else
          nil
        end
      end
    end
    
    def stats
      @daemons.inject({}) do |hash, daemon| 
        begin
          stats = daemon.api_connection.stats rescue nil || "Not running"
        rescue EOFError
          stats = "Not running"
        end
        hash[daemon.port] = stats
        hash
      end
    end
    
    def kill_all
      Dir[File.join(@pid_folder, "beanstalk_*.pid")].each do |pid_file|
        system("kill -9 #{File.read(pid_file)}")
        FileUtils.rm_f(pid_file)
      end
    end
  end
  
end