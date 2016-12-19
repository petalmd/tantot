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
  end
end
