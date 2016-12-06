module Tantot
  class Railtie < Rails::Railtie
    class RequestStrategy
      def initialize(app)
        @app = app
      end

      def call(env)
        Tantot.collector.run { @app.call(env) }
      end
    end

    console do |app|
      # Will sweep after every push (unfortunately)
      Tantot.config.console_mode = true
    end

    initializer 'tantot.request_strategy' do |app|
      app.config.middleware.insert_after(Rails::Rack::Logger, RequestStrategy)
    end
  end
end
