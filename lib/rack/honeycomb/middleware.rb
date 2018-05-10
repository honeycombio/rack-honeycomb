require "libhoney"

require "rack/honeycomb/version"

module Rack
  module Honeycomb
    # Prefix for attaching arbitrary metadata to the `env`. Will be deleted from
    # the `env` once it's pulled off of the `env` and onto a Honeycomb event.
    ENV_PREFIX = "honeycomb."

    class Middleware
      ENV_REGEX = /^#{ Regexp.escape ENV_PREFIX }/
      USER_AGENT_SUFFIX = "rack-honeycomb/#{VERSION}"

      ##
      # @param  [#call]                       app
      # @param  [Hash{Symbol => Object}]      options
      # @option options [String]  :writekey   (nil)
      # @option options [String]  :dataset    (nil)
      # @option options [String]  :api_host   (nil)
      def initialize(app, options = {})
        @app, @options = app, options

        @honeycomb = if client = options.delete(:client)
                       client
                     elsif defined?(::Honeycomb.client)
                       ::Honeycomb.client
                     else
                       Libhoney::Client.new(options.merge(user_agent_addition: USER_AGENT_SUFFIX))
                     end

        @service_name = options.delete(:service_name) || :rack
      end

      def call(env)
        ev = @honeycomb.event

        add_request_fields(ev, env)

        request_started_at = Time.now
        status, headers, body = adding_span_metadata_if_available(ev, env) do
          @app.call(env)
        end
        request_ended_at = Time.now

        # Pull arbitrary metadata off `env` if the caller attached anything
        # inside the Rack handler.
        env.each_pair do |k, v|
          if k.is_a?(String) && k.match(ENV_REGEX)
            add_field(ev, k.sub(ENV_REGEX, ''), v)
            env.delete(k)
          end
        end

        add_response_fields(ev, status, headers, body)

        ev.add_field('duration_ms', (request_ended_at - request_started_at) * 1000)

        [status, headers, body]
      rescue Exception => e
        if ev
          ev.add_field('request.error', e.class.name)
          ev.add_field('request.error_detail', e.message)
        end
        raise
      ensure
        if ev
          ev.send
        end
      end

      private
      def add_request_fields(event, env)
        event.add_field('name', "#{env['REQUEST_METHOD']} #{env['PATH_INFO']}")

        event.add_field('request.method', env['REQUEST_METHOD'])
        event.add_field('request.path', env['PATH_INFO'])
        event.add_field('request.protocol', env['rack.url_scheme'])

        if env['QUERY_STRING'] && !env['QUERY_STRING'].empty?
          event.add_field('request.query_string', env['QUERY_STRING'])
        end

        event.add_field('request.http_version', env['HTTP_VERSION'])
        event.add_field('request.host', env['HTTP_HOST'])
        event.add_field('request.remote_addr', env['REMOTE_ADDR'])
        event.add_field('request.header.user_agent', env['HTTP_USER_AGENT'])
      end

      def add_response_fields(event, status, headers, body)
        event.add_field('response.status_code', status)
      end

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

    class << self
      def add_field(env, field, value)
        env["#{ENV_PREFIX}#{field}"] = value
      end
    end
  end
end
