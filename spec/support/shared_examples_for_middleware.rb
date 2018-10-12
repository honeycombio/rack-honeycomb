RSpec.shared_examples 'Rack::Honeycomb::Middleware' do |package:, package_version:|
  let(:emitted_event) do
    events = fakehoney.events
    expect(events.size).to eq(1)
    events[0]
  end

  describe 'after the app processes a request' do
    before { get '/' }

    it 'sends an http_server event' do
      expect(emitted_event.data).to include('type' => 'http_server')
    end

    it 'includes basic request and response fields' do
      expect(emitted_event.data).to include(
        'request.method' => 'GET',
        'request.path' => '/',
        'request.protocol' => 'http',
        'response.status_code' => 200,
      )
    end

    it 'records how long request processing took' do
      expect(emitted_event.data).to include('duration_ms')
      expect(emitted_event.data['duration_ms']).to be_a Numeric
    end

    it 'includes meta fields in the event' do
      expect(emitted_event.data).to include(
        'meta.package' => package,
        'meta.package_version' => package_version,
      )
    end
  end

  describe 'more detailed request fields' do
    before do
      get 'https://search.example.org/', {q: 'bees', password: 'secret'}, {'REMOTE_ADDR' => '127.1.2.3'}
    end

    subject { emitted_event.data }

    it { is_expected.to include('request.protocol' => 'https') }

    it { is_expected.to include('meta.local_hostname' => Socket.gethostname) }

    it { is_expected.to include('request.host' => 'search.example.org') }

    it { is_expected.to include('request.remote_addr' => '127.1.2.3') }

    it 'records the querystring' do
      expect(subject).to include('request.query_string' => 'q=bees&password=secret')
      # no masking of sensitive params yet!
    end
  end

  describe 'exception handling' do
    before do
      get '/explode' rescue nil
      # plain Rack app lets the exception escape, but Sinatra catches it
    end

    it 'still includes request fields' do
      expect(emitted_event.data).to include('request.method', 'request.path', 'request.protocol')
    end

    it 'still includes duration' do
      expect(emitted_event.data).to include('duration_ms')
      expect(emitted_event.data['duration_ms']).to be_a Numeric
    end

    it 'captures exceptions' do
      expect(emitted_event.data).to include(
        'request.error' => 'RuntimeError',
        'request.error_detail' => 'kaboom!',
      )
    end
  end

  describe 'custom fields' do
    before { get '/annotated' }

    it 'includes user-supplied fields, namespaced under "app"' do
      expect(emitted_event.data).to include('app.hovercraft_contents' => 'eels')
    end
  end
end
