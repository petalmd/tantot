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

ActiveRecord::Base.raise_in_transactional_callbacks = true
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

  create_table :streets do |t|
    t.column :city_id, :integer
    t.column :name, :string
  end

  create_table :users do |t|
    t.column :username, :string
  end

  create_table :memberships do |t|
    t.column :user_id, :integer
    t.column :group_id, :integer
    t.column :name, :string
  end

  create_table :groups do |t|
    t.column :name, :string
  end

  create_table :colors do |t|
    t.column :group_id, :integer
    t.column :name, :string
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with :truncation
    DatabaseCleaner.strategy = :truncation
  end

  config.before do
    DatabaseCleaner.start
    Tantot.agent_registry.clear
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  config.after do
    ActiveRecord::Base.logger = Logger.new(nil)
    DatabaseCleaner.clean
  end
end
