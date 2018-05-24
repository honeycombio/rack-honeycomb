require "libhoney"

require 'rack'
require "rack/honeycomb/version"

module Rack
  module Honeycomb
    # Prefix for attaching custom fields to the `env`. Will be deleted from
    # the `env` once it's pulled off of the `env` and onto a Honeycomb event.
    ENV_PREFIX = "honeycomb."

    # Custom fields added via the `env` will be added to the Honeycomb
    # event under this namespace prefix
    APP_FIELD_NAMESPACE = 'app'.freeze

    RACK_VERSION = ::Rack::VERSION.join('.').freeze

    class Middleware
      ENV_REGEX = /^#{ Regexp.escape ENV_PREFIX }/
      USER_AGENT_SUFFIX = "rack-honeycomb/#{VERSION}"
      EVENT_TYPE = 'http_request'.freeze

      ##
      # @param  [#call]                       app
      # @param  [Hash{Symbol => Object}]      options
      # @option options [String]  :writekey   (nil)
      # @option options [String]  :dataset    (nil)
      # @option options [String]  :api_host   (nil)
      def initialize(app, options = {})
        @app, @options = app, options

        honeycomb = if client = options.delete(:client)
                       client
                     elsif defined?(::Honeycomb.client)
                       ::Honeycomb.client
                     else
                       Libhoney::Client.new(options.merge(user_agent_addition: USER_AGENT_SUFFIX))
                     end
        @builder = honeycomb.builder.
          add(
            'meta.package' => 'rack',
            'meta.package_version' => RACK_VERSION,
            'type' => EVENT_TYPE,
            'local_hostname' => Socket.gethostname,
          )

        @service_name = options.delete(:service_name) || :rack
      end

      def call(env)
        ev = @builder.event

        add_request_fields(ev, env)

        start = Time.now
        status, headers, body = adding_span_metadata_if_available(ev, env) do
          @app.call(env)
        end

        add_app_fields(ev, env)

        add_response_fields(ev, status, headers, body)

        [status, headers, body]
      rescue Exception => e
        if ev
          ev.add_field('request.error', e.class.name)
          ev.add_field('request.error_detail', e.message)
        end
        raise
      ensure
        if ev && start
          finish = Time.now
          ev.add_field('duration_ms', (finish - start) * 1000)

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

      def add_app_fields(event, env)
        # Pull arbitrary metadata off `env` if the caller attached
        # anything inside the Rack handler.
        env.each_pair do |k, v|
          if k.is_a?(String) && k.match(ENV_REGEX)
            namespaced_k = "#{APP_FIELD_NAMESPACE}.#{k.sub(ENV_REGEX, '')}"
            event.add_field(namespaced_k, v)
            env.delete(k)
          end
        end
      end

      def add_response_fields(event, status, headers, body)
        event.add_field('response.status_code', status)
      end

      def adding_span_metadata_if_available(event, env)
        return yield unless defined?(::Honeycomb.with_trace_id)

        ::Honeycomb.with_trace_id do |trace_id|
          event.add_field 'trace.id', trace_id
          span_id = trace_id # so this shows up as a root span
          event.add_field 'trace.span_id', span_id
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
