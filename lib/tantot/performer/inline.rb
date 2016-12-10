module Tantot
  module Performer
    class Inline
      def run(context, changes)
        Tantot.collector.resolve(context).perform(context, changes)
      end
    end
  end
end
