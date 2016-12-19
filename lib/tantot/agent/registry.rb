module Tantot
  module Agent
    class Registry
      include Singleton

      def initialize
        @agents = {}
      end

      def register(watch)
        puts 'register'
        agent_class, watch_id = Tantot::Agent.resolve!(watch)
        agent = @agents.fetch(watch_id.to_s) do
          agent_class.new(watch_id).tap {|new_agent| @agents[watch_id.to_s] = new_agent}
        end
        agent.add_watch(watch)
        agent
      end

      def agent(agent_id)
        @agents[agent_id.to_s]
      end

      def each_agent
        @agents.values.each do |agent|
          yield agent
        end
      end

      def clear
        @agents.clear
      end
    end
  end
end
