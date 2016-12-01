module Tantot
  class Strategy
    class Sidekiq < Atomic
      class Worker
        include ::Sidekiq::Worker

        def perform(watcher, changes_per_model)
          watcher.constantize.new.perform(Tantot::Strategy::Sidekiq.unmarshal(changes_per_model))
        end
      end

      def leave(specific_watcher = nil)
        if specific_watcher
          # called from `join`, execute atomic inline
          super
        else
          @stash.each do |watcher, changes_per_model|
            Tantot::Strategy::Sidekiq::Worker.perform_async(watcher.name, Tantot::Strategy::Sidekiq.marshal(changes_per_model))
          end
        end
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
