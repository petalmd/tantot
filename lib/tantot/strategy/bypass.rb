module Tantot
  class Strategy
    class Bypass < Base
      def perform(watch, model, id, mutations, options)
        # nop
      end

      def leave(watch = nil)
        # nop
      end

      def clear(watch = nil)
        # nop
      end
    end
  end
end
