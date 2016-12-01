module Tantot
  module Formatter
    class Compact
      def new_value
        []
      end

      def run(changes, current_value)
        current_value |= changes
      end
    end
  end
end
