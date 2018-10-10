require 'rails'

module Rack
  module Honeycomb
    class Railtie < ::Rails::Railtie
      class << self
        attr_reader :honeycomb_client, :logger

        def init(honeycomb_client:, logger: nil)
          @honeycomb_client = honeycomb_client
          @logger = logger

          logger.debug "#{self}: initialized with #{honeycomb_client.class}" if logger
        end
      end

      initializer 'honeycomb.add_rack_middleware' do |app|
        app.middleware.use ::Rack::Honeycomb::Middleware,
          client: Railtie.honeycomb_client,
          logger: Railtie.logger,
          is_rails: true
        Railtie.logger.debug "#{Railtie}: Added rack-honeycomb middleware to #{app.class}" if Railtie.logger
      end
    end
  end
end
