$LOAD_PATH << File.join(File.dirname(__FILE__), *%w[vendor/beanstalk-client-0.6.0])

require 'beanstalk_messaging'