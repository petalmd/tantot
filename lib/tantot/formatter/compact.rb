module Tantot
  module Formatter
    class Compact
      def push(change_array, context, changes)
        change_array.nil? ? changes : change_array | changes
      end
    end
  end
end
