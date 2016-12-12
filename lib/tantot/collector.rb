require 'tantot/collector/base'
require 'tantot/collector/watcher'
require 'tantot/collector/block'

module Tantot
  module Collector
    class Manager
      def initialize
        @collectors = {}
      end

      def register_watch(context, block)
        resolve!(context).register_watch(context, block)
      end

      def run(&block)
        yield
      ensure
        sweep
      end

      def push(context, instance, mutations)
        collector = resolve!(context)
        Tantot.logger.debug do
          mutate =
            mutations.size.zero? ? 'destroy' : "#{mutations.size} mutations(s)"
          "[Tantot] [Collecting] [#{collector.class.name.demodulize}] #{mutate} on <#{instance.class.name}:#{instance.id}> for <#{collector.debug_context(context)}>"
        end
        collector.push(context, instance, mutations)
        sweep(context.merge(performer: :inline)) if Tantot.config.console_mode
      end

      def sweep(context = {})
        performer = Tantot::Performer.resolve(context[:performer] || Tantot.config.performer).new
        specific_collector = resolve(context)
        collectors = specific_collector ? [specific_collector] : @collectors.values
        collectors.each do |collector|
          Tantot.logger.debug { "[Tantot] [Sweeping] [#{collector.class.name.demodulize}] [#{performer.class.name.demodulize}] #{collector.debug_state(context)}" }
          collector.sweep(performer, context)
        end
      end

      def perform(context, changes)
        collector = resolve!(context)
        Tantot.logger.debug { "[Tantot] [Performing] [#{collector.class.name.demodulize}] #{collector.debug_perform(context, changes)}" }
        collector.perform(context, changes)
      end

      def marshal(context, changes)
        collector = resolve!(context)
        context, changes = collector.marshal(context, changes)
        context[:collector_class] = collector.class
        [context, changes]
      end

      def unmarshal(context, changes)
        context.deep_symbolize_keys!
        collector_class = context[:collector_class].constantize
        collector = @collectors[collector_class] || @collectors[collector_class] = collector_class.new
        collector.unmarshal(context, changes)
      end

      def resolve(context)
        collector_class = Tantot::Collector::Base.descendants.find {|c| c.manages?(context)}
        return nil unless collector_class
        @collectors[collector_class] || @collectors[collector_class] = collector_class.new
      end

      def resolve!(context)
        resolve(context) || (raise "No collector manages current context: #{context.inspect}")
      end

    end
  end
end
