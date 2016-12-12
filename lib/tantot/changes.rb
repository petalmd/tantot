module Tantot
  module Changes

    class ById
      attr_reader :changes_by_id

      def initialize(changes_by_id)
        @changes_by_id = changes_by_id
      end

      delegate :[], :keys, :each, :count, :size, to: :change_by_id

      def ==(other)
        other.changes_by_id == @changes_by_id
      end

      def for_attribute(attribute)
        @changes_by_id.values.collect {|changes_by_attribute| changes_by_attribute[attribute.to_s]}.flatten.uniq
      end

      def ids
        @changes_by_id.keys
      end

      def attributes
        @changes_by_id.values.collect(&:keys).flatten.uniq.collect(&:to_sym)
      end
    end

    class ByModel
      attr_reader :changes_by_model

      def initialize(changes_by_model)
        @changes_by_model = changes_by_model
      end

      delegate :==, :keys, :each, :count, :size, to: :changes_by_model
      alias_method :models, :keys

      def ==(other)
        other.changes_by_model == @changes_by_model
      end

      def [](model)
        for_model(model)
      end

      def for_model(model)
        Tantot::Changes::ById.new(@changes_by_model[model])
      end
    end

  end
end
