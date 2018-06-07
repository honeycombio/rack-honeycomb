module Rack
  module Honeycomb
    # @api private
    module AutoInstall
      class << self
        def available?(logger: nil)
          gem 'rack'
          logger.debug "#{self.name}: detected rack" if logger
          gem 'sinatra'
          logger.debug "#{self.name}: detected sinatra, okay to autoinitialise" if logger
          true
        rescue Gem::LoadError => e
          if e.name == 'sinatra'
            logger.debug "Couldn't detect web framework (#{e.class}: #{e.message}), not autoinitialising rack-honeycomb" if logger
          else
            logger.debug "Rack not detected (#{e.class}: #{e.message}), not autoinitialising rack-honeycomb" if logger
          end
          false
        end

        def auto_install!(honeycomb_client:, logger: nil)
          require 'rack'
          require 'sinatra/base'

          require 'rack-honeycomb'

          class << ::Sinatra::Base
            alias build_without_honeycomb build
          end

          ::Sinatra::Base.define_singleton_method(:build) do |*args, &block|
            if !AutoInstall.already_added
              logger.debug "Adding Rack::Honeycomb::Middleware to #{self}" if logger

              self.use Rack::Honeycomb::Middleware, client: honeycomb_client, logger: logger
              AutoInstall.already_added = true
            else
              # In the case of nested Sinatra apps - apps composed of other apps
              # (in addition to just handlers and middleware) - our .build hook
              # above will fire multiple times, for the parent app and also for
              # each child app. In that case, it's hard to hook in our
              # middleware reliably - so instead, we just want to warn the user
              # and avoid doing anything silly.
              unless AutoInstall.already_warned
                logger.warn "Honeycomb auto-instrumentation of Sinatra will probably not work, try manual installation" if logger
                AutoInstall.already_warned = true
              end
            end
            build_without_honeycomb(*args, &block)
          end

          ::Sinatra::Base.include(Module.new do
            def add_honeycomb_field(field, value)
              ::Rack::Honeycomb.add_field(env, field, value)
            end
          end)
        end

        attr_accessor :already_added
        attr_accessor :already_warned
      end
    end
  end
end
