module Tantot
  module Agent
    class Block < Base
      def self.identify(watch)
        if watch.block.present?
          "#{watch.model.to_s}|#{watch.options.inspect}"
        else
          nil
        end
      end

      def perform(changes_by_model)
        # Block agent always has only one watch
        block = watches.first.block
        model = watches.first.model
        # Skip the model part of the changes since it will always be on a
        # single model, and wrap it in the ById helper.
        model.instance_exec(Tantot::Changes::ById.new(changes_by_model.values.first), &block)
      end

      def debug_block(block)
        location, line = block.source_location
        short_path = defined?(Rails) ? Pathname.new(location).relative_path_from(Rails.root).to_s : location
        "block @ #{short_path}##{line}"
      end

      def debug_id
        debug_block(watches.first.block)
      end
    end
  end
end
