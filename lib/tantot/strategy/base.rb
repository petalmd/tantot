module Tantot
  class Strategy
    class Base
      def perform(watcher, model, id, mutations, options)
        raise NotImplementedError
      end

      def leave(watcher = nil)
        raise NotImplementedError
      end

      def clear(watcher = nil)
        raise NotImplementedError
      end
    end
  end
end
