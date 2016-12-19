module Tantot
  module Strategy
    class Chewy
      class Worker
        include ::Sidekiq::Worker

        def perform(agent_id, chew_strategy, changes_by_model)
          agent = Tantot.agent_registry.agent(agent_id)
          raise AgentNotFound.new("No registered agent with id #{id}") unless agent

          ::Chewy.strategy(chewy_strategy) do
            agent.perform(Tantot::Strategy::Sidekiq.unmarshal(changes_by_model))
          end
        end
      end

      def run(agent, changes_by_model)
        case ::Chewy.strategy.current.name
        when /sidekiq/
          queue = agent.options[:queue] || Tantot.config.sidekiq_queue
          ::Sidekiq::Client.push('class' => Tantot::Strategy::Chewy::Worker,
                                 'args' => [agent.id, ::Chewy.strategy.current.name, Tantot::Strategy::Sidekiq.marshal(changes_by_model)],
                                 'queue' => queue)
        when :bypass
          return
        else # :atomic, :urgent, any other (even nil, which we want to pass and fail in Chewy)
          Tantot::Strategy::Inline.new.run(agent, changes_by_model)
        end
      end
    end
  end
end
