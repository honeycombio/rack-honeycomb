require 'rails'
require 'action_controller/railtie'

require 'libhoney'

require 'rack/honeycomb/middleware'

class TestApp < Rails::Application
  FAKEHONEY = Libhoney::TestClient.new

  middleware.use Rack::Honeycomb::Middleware, client: FAKEHONEY, is_rails: true

  # some minimal config Rails expects to be present
  if Rails::VERSION::MAJOR < 4
    config.secret_token = 'test' * 8
  else
    config.secret_key_base = 'test'
  end

  config.eager_load = true

  routes.append do
    get '/hello/:name', to: 'hello#show'
    get '/annotated', to: 'hello#annotated'
    get '/explode', to: 'hello#explode'
    get '/explosions/:message', to: 'hello#explode'

    if Rails::VERSION::MAJOR < 4
      root to: 'hello#index'
    else
      root 'hello#index'
    end
  end
end

class HelloController < ActionController::Base
  def index
    render_plain 'Hello world!'
  end

  def annotated
    Rack::Honeycomb.add_field(request.env, :hovercraft_contents, 'eels')
    render_plain 'hello'
  end

  def show
    render_plain "Hello #{params[:name]}"
  end

  def explode
    Rack::Honeycomb.add_field(request.env, :email, 'test@example.com')
    message = params[:message] || 'kaboom!'
    raise message
  end

  private
  def render_plain(text)
    if Rails::VERSION::MAJOR < 4
      render text: text
    else
      render plain: text
    end
  end
end

if Rails::VERSION::MAJOR >= 5
  class TestAPIApp < Rails::Application
    FAKEHONEY = Libhoney::TestClient.new

    config.api_only = true

    middleware.use Rack::Honeycomb::Middleware, client: FAKEHONEY, is_rails: true

    # some minimal config Rails expects to be present
    config.secret_key_base = 'test'

    config.eager_load = true

    routes.append do
      get '/hello/:name', to: 'hello_api#show'
      get '/annotated', to: 'hello_api#annotated'
      get '/explode', to: 'hello_api#explode'
      get '/explosions/:message', to: 'hello_api#explode'

      root 'hello_api#index'
    end
  end

  class HelloApiController < ActionController::API
    def index
      render json: {status: 'ok', greeting: 'Hello world!'}
    end

    def annotated
      Rack::Honeycomb.add_field(request.env, :hovercraft_contents, 'eels')
      render json: {status: 'ok'}
    end

    def show
      render json: {status: 'ok', greeting: "Hello #{params[:name]}!"}
    end

    def explode
      Rack::Honeycomb.add_field(request.env, :email, 'test@example.com')
      message = params[:message] || 'kaboom!'
      raise message
    end
  end
end

RSpec.shared_examples 'Rails app' do |controller:|
  describe 'routing for a successful request' do
    before { get '/hello/Honeycomb' }

    it 'reports the declared route, as well as the actual URL requested' do
      expect(last_response.body).to include('Hello Honeycomb') # sanity check the test app

      expect(emitted_event.data).to include(
        'request.path' => '/hello/Honeycomb',
        'request.route' => 'GET /hello/:name',
      )
    end

    it 'records the param values matched by the route' do
      expect(emitted_event.data).to include('request.params.name' => 'Honeycomb')
    end

    it 'records the Rails controller and action that were invoked' do
      expect(emitted_event.data).to include(
        'request.controller' => controller,
        'request.action' => 'show',
      )
    end
  end

  describe 'routing for an erroring request' do
    before { get '/explosions/oh_no' }

    it 'reports the declared route, as well as the actual URL requested' do
      expect(last_response).to_not be_ok # sanity check the test app

      expect(emitted_event.data).to include(
        'request.path' => '/explosions/oh_no',
        'request.route' => 'GET /explosions/:message',
      )
    end

    it 'records the param values matched by the route' do
      expect(emitted_event.data).to include('request.params.message' => 'oh_no')
    end

    it 'records the Rails controller and action that were invoked' do
      expect(emitted_event.data).to include(
        'request.controller' => controller,
        'request.action' => 'explode',
      )
    end
  end
end

RSpec.describe "#{Rack::Honeycomb::Middleware} with Rails" do
  before(:all) { TestApp.initialize! }

  after(:each) { TestApp::FAKEHONEY.reset }

  def fakehoney
    TestApp::FAKEHONEY
  end

  let(:app) { TestApp }

  it 'does not interfere with the app running' do
    get '/'

    expect(last_response).to be_ok
    expect(last_response.body).to eq('Hello world!')
  end

  include_examples 'Rack::Honeycomb::Middleware', package: 'rails', package_version: ::Rails::VERSION::STRING

  include_examples 'Rails app', controller: 'hello'
end

if Rails::VERSION::MAJOR >= 5
  RSpec.describe "#{Rack::Honeycomb::Middleware} with Rails in API-only mode" do
    before(:all) { TestAPIApp.initialize! }

    after(:each) { TestAPIApp::FAKEHONEY.reset }

    def fakehoney
      TestAPIApp::FAKEHONEY
    end

    let(:app) { TestAPIApp }

    it 'does not interfere with the app running' do
      get '/'

      expect(last_response).to be_ok
      expect(JSON.parse(last_response.body)).to include('greeting' => 'Hello world!')
    end

  include_examples 'Rack::Honeycomb::Middleware', package: 'rails', package_version: ::Rails::VERSION::STRING

    include_examples 'Rails app', controller: 'hello_api'
  end
end
