#/bin/ruby
require 'bundler'

Bundler.require

require 'benchmark'
require 'stackprof'
require 'active_record'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

Tantot.logger = Logger.new(nil)
Tantot.logger.level = Logger::ERROR

RUNS = 1000

def profile(obj)
  puts obj.class.name
  obj.setup
  data = StackProf.run(mode: :cpu) do
    obj.run
  end
  StackProf::Report.new(data).print_text(false, 20)
end

class ProfileRun
end

class BlockRun < ProfileRun
  class BlockRunCity < ActiveRecord::Base
    watch(:name) {|changes| }
  end

  def setup
    ActiveRecord::Schema.define do
      create_table :block_run_cities do |t|
        t.column :name, :string
      end
    end
  end

  def run
    RUNS.times do
      Tantot.manager.run do
        city = BlockRunCity.create! name: 'foo'
        city.name = 'bar'
        city.save
        city.destroy
      end
    end
  end
end

class WatcherRun < ProfileRun
  class WatcherRunWatcher
    include Tantot::Watcher

    def perform(changes)
    end
  end

  class WatcherRunCity < ActiveRecord::Base
    watch('watcher_run/watcher_run', :name)
  end

  def setup
    ActiveRecord::Schema.define do
      create_table :watcher_run_cities do |t|
        t.column :name, :string
      end
    end
  end

  def run
    RUNS.times do
      Tantot.manager.run do
        city = WatcherRunCity.create! name: 'foo'
        city.name = 'bar'
        city.save
        city.destroy
      end
    end
  end

end

ProfileRun.descendants.each {|runner| profile(runner.new)}
