require "libhoney"

module Rack
  module Honey

    class Middleware
      attr_reader :app
      attr_reader :options

      ##
      # @param  [#call]                       app
      # @param  [Hash{Symbol => Object}]      options
      # @option options [String]  :cache      (Hash.new)
      # @option options [String]  :key        (nil)
      # @option options [String]  :key_prefix (nil)
      # @option options [Integer] :code       (403)
      # @option options [String]  :message    ("Rate Limit Exceeded")
      # @option options [String]  :type       ("text/plain; charset=utf-8")
      def initialize(app, options = {})
        @app, @options = app, options

        @honey = LibHoney.new(:writekey => options['writekey'],
                              :dataset  => options['dataset'],
                              :api_host => options['api_host'])
      end

      def add_field(ev, field, value)
        ev.add_field(field, value) if value != nil && value != ''
      end
      
      def add_env(ev, env, field)
        add_field(ev, field, env[field])
      end

      def call(env)
        ev = @honey.event
        request_started_on = Time.now
        @status, @headers, @response = @app.call(env)
        request_ended_on = Time.now

        ev.add(@headers)
        add_field(ev, 'HTTP_STATUS', @status)
        add_field(ev, 'RESPONSE_CONTENT_LENGTH', @response.body.length)
        add_field(ev, 'REQUEST_TIME_MS', (request_ended_on - request_started_on) * 1000)
        add_env(ev, env, 'rack.version')
        add_env(ev, env, 'rack.multithread')
        add_env(ev, env, 'rack.multiprocess')
        add_env(ev, env, 'rack.run_once')
        add_env(ev, env, 'SCRIPT_NAME')
        add_env(ev, env, 'QUERY_STRING')
        add_env(ev, env, 'SERVER_PROTOCOL')
        add_env(ev, env, 'SERVER_SOFTWARE')
        add_env(ev, env, 'GATEWAY_INTERFACE')
        add_env(ev, env, 'REQUEST_METHOD')
        add_env(ev, env, 'REQUEST_PATH')
        add_env(ev, env, 'REQUEST_URI')
        add_env(ev, env, 'HTTP_VERSION')
        add_env(ev, env, 'HTTP_HOST')
        add_env(ev, env, 'HTTP_CONNECTION')
        add_env(ev, env, 'HTTP_CACHE_CONTROL')
        add_env(ev, env, 'HTTP_UPGRADE_INSECURE_REQUESTS')
        add_env(ev, env, 'HTTP_USER_AGENT')
        add_env(ev, env, 'HTTP_ACCEPT')
        add_env(ev, env, 'HTTP_ACCEPT_LANGUAGE')
        add_env(ev, env, 'REMOTE_ADDR')
        ev.send

        [@status, @headers, @response]
      end
    end
  end
end
