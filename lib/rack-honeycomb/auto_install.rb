module Rack
  module Honeycomb
    # @api private
    module AutoInstall
      class << self
        def available?(logger: nil)
          @logger = logger

          unless has_gem? 'rack'
            debug 'not autoinitialising rack-honeycomb'
            return false
          end

          @has_sinatra = has_gem? 'sinatra'
          @has_rails = has_gem? 'rails'

          unless @has_sinatra || @has_rails
            debug "Couldn't detect web framework, not autoinitialising rack-honeycomb"
            return false
          end

          true
        end

        def auto_install!(honeycomb_client:, logger: nil)
          @logger = logger

          require 'rack'
          require 'rack-honeycomb'

          auto_install_sinatra!(honeycomb_client, logger) if @has_sinatra
          auto_install_rails!(honeycomb_client, logger) if @has_rails
        end

        def auto_install_sinatra!(honeycomb_client, logger)
          require 'sinatra/base'

          class << ::Sinatra::Base
            alias build_without_honeycomb build
          end

          ::Sinatra::Base.define_singleton_method(:build) do |*args, &block|
            if !AutoInstall.already_added
              AutoInstall.debug "Adding Rack::Honeycomb::Middleware to #{self}"

              self.use Rack::Honeycomb::Middleware, client: honeycomb_client, logger: logger, is_sinatra: true
              AutoInstall.already_added = true
            else
              # In the case of nested Sinatra apps - apps composed of other apps
              # (in addition to just handlers and middleware) - our .build hook
              # above will fire multiple times, for the parent app and also for
              # each child app. In that case, it's hard to hook in our
              # middleware reliably - so instead, we just want to warn the user
              # and avoid doing anything silly.
              unless AutoInstall.already_warned
                AutoInstall.warn 'Honeycomb auto-instrumentation of Sinatra will probably not work, try manual installation'
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

        def auto_install_rails!(honeycomb_client, logger)
          require 'rack-honeycomb/railtie'
          ::Rack::Honeycomb::Railtie.init(
            honeycomb_client: honeycomb_client,
            logger: logger,
          )
          debug 'Loaded Railtie'
        end

        attr_accessor :already_added
        attr_accessor :already_warned

        def debug(msg)
          @logger.debug "#{self.name}: #{msg}" if @logger
        end

        def warn(msg)
          @logger.warn "#{self.name}: #{msg}" if @logger
        end

        private
        def has_gem?(gem_name)
          gem gem_name
          debug "detected #{gem_name}"
          true
        rescue Gem::LoadError => e
          debug "#{gem_name} not detected (#{e.class}: #{e.message})"
          false
        end
      end
    end
  end
end
