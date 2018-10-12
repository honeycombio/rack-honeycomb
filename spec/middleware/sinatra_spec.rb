require 'libhoney'
require 'sinatra/base'

require 'rack/honeycomb/middleware'

class SinatraApp < Sinatra::Base
  FAKEHONEY = Libhoney::TestClient.new
  use Rack::Honeycomb::Middleware, client: FAKEHONEY, is_sinatra: true

  get('/') { 'narf' }

  get('/explode') { raise 'kaboom!' }

  get '/annotated' do
    Rack::Honeycomb.add_field(env, :hovercraft_contents, 'eels')
    'hello'
  end

  get '/hello/:name' do
    "Hello #{params[:name]}"
  end
end

RSpec.describe "#{Rack::Honeycomb::Middleware} with Sinatra" do
  after(:each) { SinatraApp::FAKEHONEY.reset }

  def fakehoney
    SinatraApp::FAKEHONEY
  end

  let(:app) { SinatraApp }

  it 'does not interfere with the app running' do
    get '/'

    expect(last_response).to be_ok
    expect(last_response.body).to eq('narf')
  end

  include_examples 'Rack::Honeycomb::Middleware', package: 'sinatra', package_version: ::Sinatra::VERSION

  describe 'URL patterns' do
    before { get '/hello/Honeycomb' }

    it 'reports the declared route, as well as the actual URL requested' do
      expect(last_response.body).to eq('Hello Honeycomb') # sanity check the test app

      expect(emitted_event.data).to include(
        'request.path' => '/hello/Honeycomb',
        'request.route' => 'GET /hello/:name',
      )
    end

    it 'uses the URL pattern as the "name" field of the event' do
      expect(emitted_event.data).to include('name' => 'GET /hello/:name')
    end

    it 'records the param values matched by the route' do
      pending 'probably need to hook into Sinatra more deeply'

      expect(emitted_event.data).to include('request.params.name' => 'Honeycomb')
    end
  end
end
