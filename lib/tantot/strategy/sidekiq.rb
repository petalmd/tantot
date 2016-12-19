module Tantot
  module Strategy
    class Sidekiq
      class Worker
        include ::Sidekiq::Worker

        def perform(agent_id, changes_by_model)
          agent = Tantot.agent_registry.agent(agent_id)
          raise AgentNotFound.new("No registered agent with id #{agent_id}") unless agent
          agent.perform(Tantot::Strategy::Sidekiq.unmarshal(changes_by_model))
        end
      end

      def run(agent, changes_by_model)
        queue = agent.options[:queue] || Tantot.config.sidekiq_queue
        ::Sidekiq::Client.push('class' => Tantot::Strategy::Sidekiq::Worker,
                               'args' => [agent.id, Tantot::Strategy::Sidekiq.marshal(changes_by_model)],
                               'queue' => queue)
      end

      def self.marshal(changes_by_model)
        changes_by_model.each.with_object({}) do |(model_class, changes), hash|
          hash[model_class.name] = changes
        end
      end

      def self.unmarshal(changes_by_model)
        changes_by_model.each.with_object({}) do |(model_class_name, changes_by_id), model_hash|
          model_hash[model_class_name.constantize] = changes_by_id.each.with_object({}) do |(id, changes), change_hash|
            change_hash[id.to_i] = changes
          end
        end
      end
    end
  end
end
