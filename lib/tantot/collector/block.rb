module Tantot
  module Collector
    class Block
      def self.manages?(context)
        context.key?(:block_id)
      end

      def initialize
        @stash = Hash.new do |block_id_hash, block_id|
          block_id_hash[block_id] = Hash.new do |id_hash, id|
            id_hash[id] = {}
          end
        end
      end

      def register_watch(context, block)
        Tantot.registry.watch_config[context[:block_id]] = {context: context, block: block}
      end

      def push(context, instance, mutations)
        options = context.fetch(:options, {})
        formatter = Tantot::Formatter.resolve(options[:format] || Tantot.config.default_watcher_options[:format]).new
        attribute_hash = @stash[context[:block_id]][instance.id]
        mutations.each do |attr, changes|
          attribute_hash[attr] = formatter.push(attribute_hash[attr], context, changes)
        end
      end

      def sweep(performer, context = {})
        @stash.each do |block_id, changes|
          performer.run({block_id: block_id}, changes)
        end
        @stash.clear
      end

      def perform(context, changes_by_id)
        watch_config = Tantot.registry.watch_config[context[:block_id]]
        watch_config[:context][:model].instance_exec(Tantot::Changes::ById.new(changes_by_id), &watch_config[:block])
      end

      def marshal(context, changes_by_id)
        [context, changes_by_id]
      end

      def unmarshal(context, changes_by_id)
        changes_by_id = changes_by_id.each.with_object({}) do |(id, changes), change_hash|
          change_hash[id.to_i] = changes
        end
        [context, changes_by_id]
      end

      def debug_block(block)
        location, line = block.source_location
        short_path = defined?(Rails) ? Pathname.new(location).relative_path_from(Rails.root).to_s : location
        "block @ #{short_path}##{line}"
      end

      def debug_context(context)
        block = Tantot.registry.watch_config[context[:block_id]][:block]
        debug_block(block)
      end

      def debug_state(context)
        return false if @stash.empty?
        @stash.collect do |block_id, changes_by_id|
          watch_config = Tantot.registry.watch_config[block_id]
          "#{watch_config[:context][:model].name}*#{changes_by_id.size} for #{debug_block(watch_config[:block])}"
        end.join(" / ")
      end

      def debug_perform(context, changes_by_id)
        watch_config = Tantot.registry.watch_config[context[:block_id]]
        "#{watch_config[:context][:model].name}*#{changes_by_id.size} for #{debug_block(watch_config[:block])}"
      end

    end
  end
end
