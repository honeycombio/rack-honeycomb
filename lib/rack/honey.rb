require 'rack'

require 'honey/middleware'
module Rack
  module Honey
    autoload :Middleware, ::File.expand_path(::File.dirname(__FILE__)) + '/honey/middleware'
  end
end
