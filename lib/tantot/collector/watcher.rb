module Tantot
  module Collector
    class Watcher < Base
      def self.manages?(context)
        context.key?(:watcher)
      end

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
        # nop
      end

      def push(context, instance, mutations)
        watcher = context[:watcher]
        model = context[:model]
        formatter = Tantot::Formatter.resolve(watcher.watcher_options[:format]).new
        attribute_hash = @stash[watcher][model][instance.id]
        mutations.each do |attr, changes|
          attribute_hash[attr] = formatter.push(attribute_hash[attr], context, changes)
        end
      end

      def sweep(performer, context = {})
        watcher = context[:watcher]
        filtered_stash = watcher ? @stash.select {|w, _c| w == watcher} : @stash
        filtered_stash.each do |w, changes_by_model|
          performer.run({watcher: w}, changes_by_model)
        end
        if watcher
          @stash.delete(watcher)
        else
          @stash.clear
        end
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
        context[:watcher].name.demodulize
      end

      def debug_state(context)
        return false if @stash.empty?
        @stash.collect do |watcher, changes_by_model|
          "#{watcher.name}[#{changes_by_model.collect do |model, changes_by_id|
            "#{model.name}*#{changes_by_id.size}"
          end.join("&")}]"
        end.flatten.join(" / ")
      end

      def debug_perform(context, changes_by_model)
        "#{context[:watcher].name}[#{changes_by_model.collect do |model, changes_by_id|
          "#{model.name}*#{changes_by_id.size}"
        end.join("&")}]"
      end

    end
  end
end
