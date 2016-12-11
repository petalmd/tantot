module Tantot
  module Performer
    class Inline
      def run(context, changes)
        Tantot.collector.perform(context, changes)
      end
    end
  end
end
