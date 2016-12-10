module Tantot
  module Collector
    class Block < Base
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
        @stash.each {|block_id, changes| performer.run({block_id: block_id}, changes)}
        @stash.clear
      end

      def perform(context, changes_by_id)
        watch_config = Tantot.registry.watch_config[context[:block_id]]
        watch_config[:context][:model].where(id: changes_by_id.keys).find_each do |instance|
          instance.instance_exec(changes_by_id[instance.id], &watch_config[:block])
        end
      end

      def marshal(context, changes_per_id)
        [context, changes_per_id]
      end

      def unmarshal(context, changes_per_id)
        changes_per_id = changes_per_id.each.with_object({}) do |(id, changes), change_hash|
          change_hash[id.to_i] = changes
        end
        [context, changes_per_id]
      end

    end
  end
end