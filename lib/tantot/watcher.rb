module Tantot
  module Watcher
    extend ActiveSupport::Concern

    included do
      class_attribute :watcher_options_hash
    end

    class_methods do
      def watcher_options(opts = {})
        self.watcher_options_hash ||= {}
        self.watcher_options_hash = self.watcher_options_hash.merge(opts)
      end
    end
  end
end
