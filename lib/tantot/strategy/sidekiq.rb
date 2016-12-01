module Tantot
  class Strategy
    class Sidekiq < Atomic
      class Worker
        include ::Sidekiq::Worker

        def perform(watcher, changes_per_model)
          watcher.constantize.perform(changes_per_model)
        end
      end

      def leave(specific_watch = nil)
        @stash.select {|watch, _c| specific_watch.nil? || specific_watch == watch}.each do |watch, changes_per_model|
          Tantot::Strategy::Sidekiq::Worker.perform_async(watch.class.name, changes_per_model)
        end
      end
    end
  end
end
