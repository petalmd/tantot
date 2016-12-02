module Tantot
  module Formatter
    class Detailed
      def new_value
        []
      end

      def run(model, changes, current_value)
        current_value.push(changes)
      end
    end
  end
end
