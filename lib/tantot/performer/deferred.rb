module Tantot
  module Performer
    class Deferred
      class Worker
        include ::Sidekiq::Worker

        def perform(watcher, changes)
          watcher.constantize.new.perform(Tantot::Performer::Deferred.unmarshal(changes))
        end
      end

      def run(watcher, changes)
        Tantot::Performer::Deferred::Worker.perform_async(watcher, Tantot::Performer::Deferred.marshal(changes))
      end

      def self.marshal(changes_per_model)
        # Convert class to class names
        changes_per_model.each.with_object({}) {|(model_class, changes), hash| hash[model_class.name] = changes}
      end

      def self.unmarshal(changes_per_model)
        # Convert back from class names to classes, and object ids to integers
        changes_per_model.each.with_object({}) do |(model_class_name, changes_by_id), model_hash|
          model_hash[model_class_name.constantize] = changes_by_id.each.with_object({}) do |(id, changes), change_hash|
            change_hash[id.to_i] = changes
          end
        end
      end
    end
  end
end
