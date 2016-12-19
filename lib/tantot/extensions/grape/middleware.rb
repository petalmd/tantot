if defined?(::Grape)

  module Tantot
    module Extensions

      class GrapeMiddleware < Grape::Middleware::Base
        def call!(env)
          Tantot.manager.run do
            @app_response = super(env)
          end
        end
      end

    end
  end

end
