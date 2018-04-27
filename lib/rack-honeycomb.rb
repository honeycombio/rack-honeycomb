# Main gem entrypoint (see also lib/rack-honeycomb/automagic.rb for an
# alternative entrypoint).

begin
  gem 'rack'

  require 'rack/honeycomb'
rescue Gem::LoadError
  warn 'Rack not detected, not enabling rack-honeycomb'
end
