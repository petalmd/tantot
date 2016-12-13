module Tantot
  module Collector
    class Watcher < Base
      self.context_key = :watcher

      def initialize
        @stash = Hash.new do |watcher_hash, watcher|
          watcher_hash[watcher] = Hash.new do |model_hash, model|
            model_hash[model] = Hash.new do |id_hash, id|
              id_hash[id] = {}
            end
          end
        end
      end

      def register_watch(context, block)
        Tantot.registry.watch_config[context[:watcher]] = {context: context}
      end

      def perform(context, changes_by_model)
        context[:watcher].new.perform(Tantot::Changes::ByModel.new(changes_by_model))
      end

      def marshal(context, changes_by_model)
        changes_by_model = changes_by_model.each.with_object({}) do |(model_class, changes), hash|
          hash[model_class.name] = changes
        end
        [context, changes_by_model]
      end

      def unmarshal(context, changes_by_model)
        context[:watcher] = context[:watcher].constantize
        changes_by_model = changes_by_model.each.with_object({}) do |(model_class_name, changes_by_id), model_hash|
          model_hash[model_class_name.constantize] = changes_by_id.each.with_object({}) do |(id, changes), change_hash|
            change_hash[id.to_i] = changes
          end
        end
        [context, changes_by_model]
      end

      def debug_context(context)
        context[:watcher].name
      end

      def debug_changes(watcher, changes_by_model)
        "#{watcher.name}(#{changes_by_model.collect {|model, changes_by_id| debug_changes_for_model(model, changes_by_id)}.join(" & ")})"
      end

      def debug_state(stash = @stash)
        stash.collect {|watcher, changes_by_model| debug_changes(watcher, changes_by_model)}.flatten.join(" / ")
      end

      def debug_perform(context, changes_by_model)
        debug_changes(context[:watcher], changes_by_model)
      end

    protected

      def get_stash(context, instance)
        watcher = context[:watcher]
        model = context[:model]
        @stash[watcher][model][instance.id]
      end

    end
  end
end
