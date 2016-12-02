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

    initializer 'tantot.request_strategy' do |app|
      app.config.middleware.insert_after(Rails::Rack::Logger, RequestStrategy)
    end
  end
end
