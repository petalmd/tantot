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
      Tantot.config.sweep_on_push = true
    end

    initializer 'tantot.request_strategy' do |app|
      Tantot.logger.debug { "[Tantot] Installing Rails middleware" }
      app.config.middleware.insert_after(Rails::Rack::Logger, RequestStrategy)
    end

    config.to_prepare do
      Tantot.logger.debug { "[Tantot] Clearing registry" }
      Tantot.agent_registry.clear
    end
  end
end
