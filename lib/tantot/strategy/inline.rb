module Tantot
  module Strategy
    class Inline
      def run(agent, changes_by_model)
        agent.perform(changes_by_model)
      end
    end
  end
end
