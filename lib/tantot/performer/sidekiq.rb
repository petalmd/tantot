module Tantot
  module Performer
    class Sidekiq
      class Worker
        include ::Sidekiq::Worker

        def perform(context, changes)
          context, changes = Tantot.collector.unmarshal(context, changes)
          Tantot.collector.perform(context, changes)
        end
      end

      def run(context, changes)
        context, changes = Tantot.collector.marshal(context, changes)
        Tantot::Performer::Sidekiq::Worker.perform_async(context, changes)
      end
    end
  end
end
