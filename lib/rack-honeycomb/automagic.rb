# Alternative gem entrypoint that automagically installs our middleware into
# certain Rack frameworks.

begin
  gem 'honeycomb'
  gem 'rack'

  require 'honeycomb/automagic'
  require 'rack/honeycomb'

  has_sinatra = begin
                  gem 'sinatra'
                  true
                rescue Gem::LoadError
                  false
                end
  if has_sinatra
    Honeycomb.after_init :sinatra do |client|
      require 'sinatra/base'

      class << ::Sinatra::Base
        alias build_without_honeycomb build
      end

      ::Sinatra::Base.define_singleton_method(:build) do |*args, &block|
        if ::Sinatra::Base.class_variable_defined?(:@@honeycomb_already_added)
          puts "#{self} chained build"
          unless ::Sinatra::Base.class_variable_get(:@@honeycomb_already_added) == :warned
            warn "Honeycomb Sinatra instrumentation will probably not work, try manual installation"
            ::Sinatra::Base.class_variable_set(:@@honeycomb_already_added, :warned)
          end
        else
          puts "#{self} chained build adding Honeycomb"
          self.use Rack::Honeycomb::Middleware, client: client
          ::Sinatra::Base.class_variable_set(:@@honeycomb_already_added, true)
        end
        build_without_honeycomb(*args, &block)
      end
    end
  else
    puts "Couldn't detect web framework, not autoinitialising rack-honeycomb"
  end
rescue Gem::LoadError => e
  case e.name
  when 'rack'
      puts 'Not autoinitialising rack-honeycomb'
  when 'honeycomb'
    warn "Please ensure you `require 'rack-honeycomb/automagic'` *after* `require 'honeycomb/automagic'`"
  end
end
