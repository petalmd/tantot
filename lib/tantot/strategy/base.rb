module Tantot
  class Strategy
    class Base
      def perform(watch, model, id, mutations, options)
        raise NotImplementedError
      end

      def leave(watch = nil)
        raise NotImplementedError
      end

      def clear(watch = nil)
        raise NotImplementedError
      end
    end
  end
end
