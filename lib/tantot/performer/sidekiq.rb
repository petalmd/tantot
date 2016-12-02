module Tantot
  module Performer
    class Sidekiq
      class Worker
        include ::Sidekiq::Worker

        def perform(watcher, changes)
          watcher.constantize.new.perform(Tantot::Performer.unmarshal(changes))
        end
      end

      def run(watcher, changes)
        Tantot::Performer::Sidekiq::Worker.perform_async(watcher, Tantot::Performer.marshal(changes))
      end
    end
  end
end
