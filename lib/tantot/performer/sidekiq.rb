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
        queue = context[:options][:queue] || Tantot.config.sidekiq_queue
        ::Sidekiq::Client.push('class' => Tantot::Performer::Sidekiq::Worker,
          'args' => Tantot.collector.marshal(context, changes),
          'queue' => queue)
      end
    end
  end
end
