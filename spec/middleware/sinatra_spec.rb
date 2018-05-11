require 'libhoney'
require 'sinatra/base'

require 'rack/honeycomb/middleware'

class SinatraApp < Sinatra::Base
  FAKEHONEY = Libhoney::TestClient.new
  use Rack::Honeycomb::Middleware, client: FAKEHONEY

  get('/') { 'narf' }

  get('/explode') { raise 'kaboom!' }

  get('/annotated') do
    Rack::Honeycomb.add_field(env, :hovercraft_contents, 'eels')
    'hello'
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

  include_examples 'Rack::Honeycomb::Middleware'
end
