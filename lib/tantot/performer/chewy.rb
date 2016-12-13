module Tantot
  module Performer
    class Chewy
      class Worker
        include ::Sidekiq::Worker

        def perform(context, changes)
          context, changes = Tantot.collector.unmarshal(context, changes)
          ::Chewy.strategy(Tantot.config.chewy_strategy) do
            Tantot.collector.perform(context, changes)
          end
        end
      end

      def run(context, changes)
        case ::Chewy.strategy.current.name
        when :atomic, :urgent
          Tantot::Performer::Inline.new.run(context, changes)
        when /sidekiq/
          context, changes = Tantot.collector.marshal(context, changes)
          Tantot::Performer::Chewy::Worker.perform_async(context, changes)
        when :bypass
          return
        else
          # No strategy defined, do an Inline run and let Chewy fail
          Tantot::Performer::Inline.new.run(context, changes)
        end
      end
    end
  end
end
