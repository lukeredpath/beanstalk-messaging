$LOAD_PATH << File.join(File.dirname(__FILE__), *%w[../vendor/mocha-0.9.0])

require File.dirname(__FILE__) + '/../init'
require 'rubygems'
require 'test/unit'
require 'mocha'
