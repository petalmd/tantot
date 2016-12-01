require 'tantot/formatter/compact'
require 'tantot/formatter/detailed'

module Tantot
  module Formatter
    def self.resolve(name)
      "Tantot::Formatter::#{name.to_s.camelize}".safe_constantize or raise "Can't find formatter class `#{name}`"
    end
  end
end
