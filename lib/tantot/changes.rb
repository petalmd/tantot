module Tantot
  module Changes

    class ById
      include Enumerable

      attr_reader :changes_by_id

      def initialize(changes_by_id)
        @changes_by_id = changes_by_id
      end

      delegate :[], :keys, :each, :count, :size, to: :changes_by_id

      def ==(other)
        other.changes_by_id == @changes_by_id
      end

      def for_attribute(attribute, compact = true)
        @changes_by_id.values.collect {|changes_by_attribute| changes_by_attribute[attribute.to_s]}.flatten.uniq.tap {|changes| changes.compact! if compact}
      end

      def ids
        @changes_by_id.keys
      end

      def attributes
        @changes_by_id.values.collect(&:keys).flatten.uniq.collect(&:to_sym)
      end
    end

    class ByModel
      include Enumerable

      attr_reader :changes_by_model

      def initialize(changes_by_model)
        @changes_by_model = changes_by_model
      end

      delegate :==, :keys, :values, :count, :size, to: :changes_by_model
      alias_method :models, :keys

      def ==(other)
        other.changes_by_model == @changes_by_model
      end

      def [](model)
        for_model(model)
      end

      def each(&block)
        @changes_by_model.each do |model, changes|
          block.call(model, Tantot::Changes::ById.new(changes))
        end
      end

      def for_model(model)
        Tantot::Changes::ById.new(@changes_by_model[model])
      end
    end

  end
end
