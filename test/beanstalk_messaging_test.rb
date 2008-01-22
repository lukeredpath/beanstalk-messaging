require File.dirname(__FILE__) + '/test_helper'
require 'beanstalk-client/version'

class BeanstalkTest < Test::Unit::TestCase
  def test_should_be_using_version_0_point_6_of_the_gem
    assert_equal '0.6.0', Beanstalk::VERSION::STRING,
     "We currently monkey-patch the Pool class - you'll need to check this before upgrading the version"
  end
  
  def test_should_have_a_default_connection_timeout_of_1_second
    Beanstalk.connection_timeout = nil
    assert_equal 1, Beanstalk.connection_timeout
  end
  
  def test_should_make_the_rabbit_cry
    flunk("You suck")
  end
end