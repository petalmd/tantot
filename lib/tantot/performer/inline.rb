module Tantot
  module Performer
    class Inline
      def run(watcher, changes)
        watcher.new.perform(changes)
      end
    end
  end
end
