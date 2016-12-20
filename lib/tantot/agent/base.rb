module Tantot
  module Agent
    class Base
      attr_reader :id, :watches, :stash

      def self.identify(watch)
        raise NotImplementedError
      end

      def initialize(id)
        @id = id
        @watches = []
        @stash = Hash.new do |model_hash, model|
          model_hash[model] = Hash.new do |instance_id_hash, instance_id|
            instance_id_hash[instance_id] = Hash.new do |attribute_hash, attribute|
              attribute_hash[attribute] = []
            end
          end
        end
      end

      def options
        @watches.first.options
      end

      def add_watch(watch)
        watch.agent = self
        setup_watch(watch)
        @watches.push(watch)
      end

      def setup_watch(watch)
        # nop
      end

      def push(watch, instance, changes_by_attribute)
        Tantot.logger.debug do
          mutate = changes_by_attribute.size.zero? ? 'destroy' : "#{changes_by_attribute.size} mutations(s)"
          "[Tantot] [Collecting] [#{self.class.name.demodulize}] #{mutate} on <#{instance.class.name}:#{instance.id}> for <#{debug_id}>"
        end
        attribute_hash = @stash[watch.model][instance.id]
        changes_by_attribute.each do |attr, changes|
          attribute_hash[attr] |= changes
        end
        sweep if Tantot.config.sweep_on_push
      end

      def sweep(strategy_name = nil)
        if @stash.any?
          strategy = Tantot::Strategy.resolve(strategy_name || options[:strategy] || Tantot.config.strategy).new
          Tantot.logger.debug { "[Tantot] [Strategy] [#{self.class.name.demodulize}] [#{strategy.class.name.demodulize}] [#{debug_id}] #{debug_stash}" }
          strategy.run(self, @stash)
          @stash.clear
        end
      end

      def perform(changes_by_model)
        Tantot.logger.debug { "[Tantot] [Perform] [#{self.class.name.demodulize}] [#{debug_id}] [#{debug_stash}]"  }
      end

      def debug_id
        raise NotImplementedError
      end

      def debug_stash
        "#{@stash.collect {|model, changes_by_id| debug_changes_for_model(model, changes_by_id)}.join(" & ")}"
      end

      def debug_changes_for_model(model, changes_by_id)
        "#{model.name}#{changes_by_id.keys.inspect}"
      end

    end
  end
end
