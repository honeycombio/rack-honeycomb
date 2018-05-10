require 'libhoney'
require 'socket'

require 'rack/honeycomb/middleware'

RSpec.describe Rack::Honeycomb::Middleware do
  let(:fakehoney) { Libhoney::TestClient.new }
  def with_middleware(app)
    Rack::Honeycomb::Middleware.new(app, client: fakehoney)
  end

  let(:app) do
    base_app = ->(_) { [200, {}, ['narf']] }
    with_middleware(base_app)
  end

  def emitted_event
    events = fakehoney.events
    expect(events.size).to eq(1)
    events[0]
  end

  it 'does not interfere with the app running' do
    get '/'

    expect(last_response).to be_ok
    expect(last_response.body).to eq('narf')
  end

  describe 'after the app processes a request' do
    before { get '/' }
    let(:event) { emitted_event }

    it 'sends an http_request event' do
      expect(event.data).to include(
        'type' => 'http_request',
        'name' => 'GET /',
      )
    end

    it 'includes basic request and response fields' do
      expect(event.data).to include(
        'request.method' => 'GET',
        'request.path' => '/',
        'request.protocol' => 'http',
        'response.status_code' => 200,
      )
    end

    it 'records how long request processing took' do
      expect(event.data).to include('duration_ms')
      expect(event.data['duration_ms']).to be_a Numeric
    end

    it 'includes meta fields in the event' do
      expect(event.data).to include(
        'meta.package' => 'rack',
        'meta.package_version' => '1.3',
      )
    end
  end

  describe 'more detailed request fields' do
    before do
      get 'https://search.example.org/', {q: 'bees', password: 'secret'}, {'REMOTE_ADDR' => '127.1.2.3'}
    end

    subject { emitted_event.data }

    it { is_expected.to include('request.protocol' => 'https') }

    it { is_expected.to include('local_hostname' => Socket.gethostname) }

    it { is_expected.to include('request.host' => 'search.example.org') }

    it { is_expected.to include('request.remote_addr' => '127.1.2.3') }

    it 'records the querystring' do
      expect(subject).to include('request.query_string' => 'q=bees&password=secret')
      # no masking of sensitive params yet!
    end
  end

  describe 'exception handling' do
    let(:app) do
      base_app = ->(_) { raise RuntimeError, 'kaboom!' }
      with_middleware(base_app)
    end

    before do
      expect { get '/explode' }.to raise_error RuntimeError
    end

    let(:event) { emitted_event }

    it 'still includes request fields' do
      expect(event.data).to include('request.method', 'request.path', 'request.protocol')
    end

    it 'still includes duration' do
      expect(event.data).to include('duration_ms')
      expect(event.data['duration_ms']).to be_a Numeric
    end

    it 'captures exceptions' do
      expect(event.data).to include(
        'request.error' => 'RuntimeError',
        'request.error_detail' => 'kaboom!',
      )
    end
  end

  describe 'Rack::Honeycomb.add_field' do
    let(:app) do
      base_app = lambda do |env|
        Rack::Honeycomb.add_field(env, :hovercraft_contents, 'eels')
        [200, {}, ['hello']]
      end
      with_middleware(base_app)
    end

    before { get '/' }

    let(:event) { emitted_event }

    it 'includes user-supplied fields, namespaced under "app"' do
      expect(event.data).to include('app.hovercraft_contents' => 'eels')
    end
  end
end
