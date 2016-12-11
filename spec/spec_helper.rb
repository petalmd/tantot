require 'bundler'

Bundler.require

require 'active_record'
require 'database_cleaner'

Tantot.logger = Logger.new(STDOUT)

def stub_class(name, superclass = nil, &block)
  stub_const(name.to_s.camelize, Class.new(superclass || Object, &block))
end

def stub_model(name, superclass = nil, &block)
  stub_class(name, superclass || ActiveRecord::Base, &block)
end

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :countries do |t|
    t.column :name, :string
    t.column :country_code, :string
    t.column :rating, :integer
  end

  create_table :cities do |t|
    t.column :country_id, :integer
    t.column :name, :string
    t.column :rating, :integer
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with :transaction
    DatabaseCleaner.strategy = :transaction
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end
