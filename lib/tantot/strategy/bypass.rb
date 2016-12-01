module Tantot
  class Strategy
    class Bypass < Base
      def perform(watcher, model, id, mutations, options)
        # nop
      end

      def leave(watcher = nil)
        # nop
      end

      def clear(watcher = nil)
        # nop
      end
    end
  end
end
