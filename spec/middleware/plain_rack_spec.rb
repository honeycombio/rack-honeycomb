require 'libhoney'
require 'socket'

require 'rack/honeycomb/middleware'

require 'support/shared_examples_for_middleware'


RACK_APP = lambda do |env|
  case env['PATH_INFO']
  when '/'
    [200, {}, ['narf']]
  when '/explode'
    raise 'kaboom!'
  when '/annotated'
    Rack::Honeycomb.add_field(env, :hovercraft_contents, 'eels')
    [200, {}, ['hello']]
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

  include_examples 'Rack::Honeycomb::Middleware'
end
