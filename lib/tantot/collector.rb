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
        collector.push(context, instance, mutations)
        sweep_now(context) if Tantot.config.console_mode
      end

      def sweep(context = {})
        performer = Tantot::Performer.resolve(context[:performer] || Tantot.config.performer).new
        if (collector = resolve(context))
          collector.sweep(performer, context)
        else
          @collectors.values.each {|c| c.sweep(performer)}
        end
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
