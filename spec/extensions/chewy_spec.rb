require "spec_helper"

module Chewy
end

describe Tantot::Extensions::Chewy do
  before :each do
    Tantot::Extensions::Chewy::ChewyWatcher.clear_callbacks
  end

  it "should allow registering an index watch on self" do
    chewy_type = double

    stub_model(:city) do
      watch_index 'foo', :id, :name, method: :self
    end

    Tantot.collector.run do
      city = City.create!

      expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
      expect(chewy_type).to receive(:update_index).with([city.id], {})
    end
  end

  it "should allow registering an index watch on self (all attributes)" do
    chewy_type = double

    stub_model(:city) do
      watch_index 'foo', method: :self
    end

    Tantot.collector.run do
      city = City.create!

      expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
      expect(chewy_type).to receive(:update_index).with([city.id], {})
    end
  end

  it "should allow registering an index watch on self (all attributes, destroy)" do
    chewy_type = double

    stub_model(:city) do
      watch_index 'foo', method: :self
    end

    city = City.create!
    Tantot.collector.sweep(performer: :bypass)

    Tantot.collector.run do
      city.destroy

      expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
      expect(chewy_type).to receive(:update_index).with([city.id], {})
    end
  end

  it "should allow registering an index watch with a class method callback" do
    chewy_type = double

    stub_model(:city) do
      watch_index 'foo', :id, :name, method: :get_ids

      def self.get_ids(changes)
        [5, 6, 7]
      end
    end

    Tantot.collector.run do
      City.create!

      expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
      expect(chewy_type).to receive(:update_index).with([5, 6, 7], {})
    end
  end

  it "should allow registering an index watch with a block" do
    chewy_type = double

    stub_model(:city) do
      watch_index 'foo', :id, :name do |changes|
        [8, 9 ,10]
      end
    end

    Tantot.collector.run do
      City.create!

      expect(Chewy).to receive(:derive_type).with('foo').and_return(chewy_type)
      expect(chewy_type).to receive(:update_index).with([8, 9, 10], {})
    end
  end
end
