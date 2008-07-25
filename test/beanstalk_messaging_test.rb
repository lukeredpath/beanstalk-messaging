require File.dirname(__FILE__) + '/test_helper'
require 'beanstalk-client/version'

class BeanstalkTest < Test::Unit::TestCase
  def test_should_be_using_version_1_point_0_point_2_of_the_beanstalk_client_gem
    assert_equal '1.0.2', Beanstalk::VERSION::STRING
  end
  
  def test_should_have_a_default_connection_timeout_of_1_second
    Beanstalk.connection_timeout = nil
    assert_equal 1, Beanstalk.connection_timeout
  end
end