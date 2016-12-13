module Tantot
  module Collector
    class Base
      class_attribute :context_key

      def self.manages?(context)
        context.key?(self.context_key)
      end

      def register_watch(context, block)
        raise NotImplementedError
      end

      def push(context, instance, mutations)
        formatter = Tantot::Formatter.resolve(context[:options][:format] || Tantot.config.format).new
        attribute_hash = get_stash(context, instance)
        mutations.each do |attr, changes|
          attribute_hash[attr] = formatter.push(attribute_hash[attr], context, changes)
        end
      end

      def sweep(performer_name)
        if @stash.any?
          Tantot.logger.debug { "[Tantot] [Sweeping] [#{self.class.name.demodulize}] #{debug_state}" }
          @stash.each do |id, changes|
            context = Tantot.registry.watch_config[id][:context]
            performer = Tantot::Performer.resolve(performer_name || context[:options][:performer] || Tantot.config.performer).new
            Tantot.logger.debug { "[Tantot] [Performer] [#{self.class.name.demodulize}] [#{performer.class.name.demodulize}] #{debug_state(Hash[id, changes])}" }
            performer.run(context, changes)
          end
          @stash.clear
        end
      end

      def debug_changes_for_model(model, changes_by_id)
        "#{model.name}#{changes_by_id.keys.inspect}"
      end

    protected

      def get_stash(context, instance)
        raise NotImplementedError
      end
    end
  end
end
