require 'libhoney'
require 'socket'

require 'rack/honeycomb/middleware'

require 'support/shared_examples_for_middleware'


RACK_APP = lambda do |env|
  case env['PATH_INFO']
  when '/'
    [200, {}, ['narf']]
  when '/explode'
    Rack::Honeycomb.add_field(env, :email, 'test@example.com')
    raise 'kaboom!'
  when '/annotated'
    Rack::Honeycomb.add_field(env, :hovercraft_contents, 'eels')
    [200, {}, ['hello']]
  when %r{^/hello/(\w+)$}
    [200, {}, ["Hello #{$1}"]]
  else
    [404, {}, ['what?']]
  end
end

RSpec.describe "#{Rack::Honeycomb::Middleware} with plain Rack app" do
  let(:fakehoney) { Libhoney::TestClient.new }

  let(:app) do
    Rack::Honeycomb::Middleware.new(RACK_APP, client: fakehoney)
  end

  it 'does not interfere with the app running' do
    get '/'

    expect(last_response).to be_ok
    expect(last_response.body).to eq('narf')
  end

  include_examples 'Rack::Honeycomb::Middleware', package: 'rack', package_version: ::Rack::VERSION.join('.')

  describe 'URL patterns' do
    # Pure Rack does not define any routing mechanism and thus doesn't have a
    # notion of "URL patterns". The test app above includes an example
    # routing implementation using a regex. This test just serves as
    # documentation that we don't (and can't) do anything clever with the URLs
    # in this case. Contrast with sinatra_spec where we report the URL pattern
    # from the route rather than the literal URL.

    before { get '/hello/Honeycomb' }

    it 'reports the actual URL requested, not the URL pattern declared in the app' do
      expect(last_response.body).to eq('Hello Honeycomb') # sanity check the test app

      expect(emitted_event.data).to include('request.path' => '/hello/Honeycomb')
      expect(emitted_event.data).to_not include('request.route')
    end
  end
end
