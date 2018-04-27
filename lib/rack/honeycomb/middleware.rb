require "libhoney"

require "rack/honeycomb/version"

puts 'rack/honeycomb/middleware'

module Rack
  module Honeycomb
    # Prefix for attaching arbitrary metadata to the `env`. Will be deleted from
    # the `env` once it's pulled off of the `env` and onto a Honeycomb event.
    ENV_PREFIX = "honeycomb."

    class Middleware
      ENV_REGEX = /^#{ Regexp.escape ENV_PREFIX }/
      USER_AGENT_SUFFIX = "rack-honeycomb/#{VERSION}"

      attr_reader :app
      attr_reader :options

      ##
      # @param  [#call]                       app
      # @param  [Hash{Symbol => Object}]      options
      # @option options [String]  :writekey   (nil)
      # @option options [String]  :dataset    (nil)
      # @option options [String]  :api_host   (nil)
      def initialize(app, options = {})
        @app, @options = app, options

        @honeycomb = if client = options.delete(:client)
                       puts "client via options"
                       client
                     elsif defined?(::Honeycomb.client)
                       puts "client via global"
                       ::Honeycomb.client
                     else
                       puts "new client"
                       Libhoney::Client.new(options.merge(user_agent_addition: USER_AGENT_SUFFIX))
                     end
        puts "gotaclient #{@honeycomb.class}"

        @service_name = options.delete(:service_name) || :rack
      end

      def add_field(ev, field, value)
        ev.add_field(field, value) if value != nil && value != ''
      end

      def add_env(ev, env, field)
        add_field(ev, field, env[field])
      end

      def call(env)
        ev = @honeycomb.event
        request_started_at = Time.now
        puts "gotareq"
        status, headers, response = adding_span_metadata_if_available(ev, env) do
          @app.call(env)
        end
        request_ended_at = Time.now

        ev.add(headers)
        if headers['Content-Length'] != nil
          # Content-Length (if present) is a string.  let's change it to an int.
          ev.add_field('Content-Length', headers['Content-Length'].to_i)
        end
        add_field(ev, 'HTTP_STATUS', status)
        add_field(ev, 'durationMs', (request_ended_at - request_started_at) * 1000)

        # Pull arbitrary metadata off `env` if the caller attached anything
        # inside the Rack handler.
        env.each_pair do |k, v|
          if k.is_a?(String) && k.match(ENV_REGEX)
            add_field(ev, k.sub(ENV_REGEX, ''), v)
            env.delete(k)
          end
        end

        # we can't use `ev.add(env)` because json serialization fails.
        # pull out some interesting and potentially useful fields.
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

        [status, headers, response]
      rescue Exception => e
        raise
      ensure
        if ev
          if e
            ev.add_field('exception_class', e.class.name)
            ev.add_field('exception_message', e.message)
          end
          ev.send
        end
      end

      private
      def adding_span_metadata_if_available(event, env)
        return yield unless defined?(::Honeycomb.with_trace_id)

        ::Honeycomb.with_trace_id do |trace_id|
          event.add_field :traceId, trace_id
          event.add_field :serviceName, @service_name
          event.add_field :name, "#{env['REQUEST_METHOD']} #{env['REQUEST_PATH']}"
          span_id = trace_id # so this shows up as a root span
          event.add_field :id, span_id
          ::Honeycomb.with_span_id(span_id) do
            yield
          end
        end
      end
    end
  end
end
