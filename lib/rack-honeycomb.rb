begin
  gem 'rack'

  require 'rack/honeycomb'
rescue Gem::LoadError
  warn 'Rack not detected, not enabling rack-honeycomb'
end
