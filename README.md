# Honeycomb middleware for Rack applications

This is Rack middleware that sends request/response data to [Honeycomb](https://honeycomb.io).  You can use `Rack::Honey` with any Ruby web framework based on Rack, including Ruby on Rails and Sinatra.

For more information about using Honeycomb, check out our [docs](https://honeycomb.io/docs) and our [Ruby SDK](https://honeycomb.io/docs/connect/ruby/).

## Adding instrumentation to a Rails application

```ruby
# config/application.rb
require 'rack/honey'

class Application < Rails::Application
  config.middleware.use Rack::Honey::Middleware, writekey: "<YOUR WRITEKEY HERE>", dataset: "<YOUR DATASET NAME HERE>"
end
```

## Adding instrumentation to a Sinatra application

```ruby
#!/usr/bin/env ruby -rubygems
require 'sinatra'
require 'rack/honey'

use Rack::Honey::Middleware, writekey: "<YOUR WRITEKEY HERE>", dataset: "<YOUR DATASET NAME HERE>"

get('/hello') { "Hello, world!\n" }
```

## Installation

To install the latest stable release of `rack-honey`, simply:

```bash
$ gem install rack-honey
```

or add this to your Gemfile

```
gem "rack-honey"
```

To follow the bleeding edge, it's easy to track the git repo:

```
gem "rack-honey", :git => "https://github.com/honeycombio/rack-honey.git"
```
