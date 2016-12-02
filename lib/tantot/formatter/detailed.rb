module Tantot
  module Formatter
    class Detailed
      def push(change_array, model, changes)
        change_array.nil? ? [changes] : change_array.push(changes)
      end
    end
  end
end
