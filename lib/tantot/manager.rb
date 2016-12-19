module Tantot
  class Manager
    def run(&block)
      yield
    ensure
      sweep
    end

    def sweep(strategy_name = nil)
      Tantot.agent_registry.each_agent {|agent| agent.sweep(strategy_name)}
    end

    def perform(context, changes_by_model)
      collector = resolve!(context)
      Tantot.logger.debug { "[Tantot] [Run] [#{collector.class.name.demodulize}] #{collector.debug_perform(context, changes)}" }
      collector.perform(context, changes_by_model)
    end

    def marshal(watch, changes)
      collector.marshal(context, changes)
    end

    def unmarshal(context, changes)
      context.deep_symbolize_keys!
      collector_class = context[:collector_class].constantize
      collector = @watches[collector_class] || @watches[collector_class] = collector_class.new
      collector.unmarshal(context, changes)
    end

  end
end
