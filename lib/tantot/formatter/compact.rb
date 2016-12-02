module Tantot
  module Formatter
    class Compact
      def push(change_array, model, changes)
        change_array.nil? ? changes : change_array | changes
      end
    end
  end
end
