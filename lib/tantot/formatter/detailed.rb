module Tantot
  module Formatter
    class Detailed
      def push(change_array, context, changes)
        change_array.nil? ? [changes] : change_array.push(changes)
      end
    end
  end
end
