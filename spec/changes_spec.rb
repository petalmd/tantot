require "spec_helper"

describe Tantot::Changes do

  describe Tantot::Changes::ById do
    let(:raw_changes) { {1 => {"id" => [nil, 1], "name" => [nil, "foo"]}, 2 => {"name" => ["foo", nil]}, 3 => {"id" => [3, nil], "name" => ["bar", "baz", nil]}} }
    subject { described_class.new(raw_changes) }

    it "should find ids" do
      expect(subject.ids).to eq([1, 2, 3])
    end

    it "should find all values for an attribute, removing nil by default" do
      expect(subject.for_attribute(:name)).to eq(["foo", "bar", "baz"])
    end

    it "should find all values for an attribute, including nil" do
      expect(subject.for_attribute(:name, false)).to eq([nil, "foo", "bar", "baz"])
    end

    it "should find all changed attributes" do
      expect(subject.attributes).to eq([:id, :name])
    end

    it "should correctly implement ==" do
      expect(subject).to eq(described_class.new(raw_changes))
    end

    it "should implement Enumerable" do
      expect(subject.collect {|id, changes| [id, changes]}).to eq(raw_changes.to_a)
    end
  end

  describe Tantot::Changes::ByModel do
    before do
      stub_const('City', Class.new)
      stub_const('Country', Class.new)
    end
    let(:city_changes) { {1 => {"id" => [nil, 1], "name" => [nil, "foo"]}, 2 => {"name" => ["foo", nil]}, 3 => {"id" => [3, nil], "name" => ["bar", "baz", nil]}} }
    let(:country_changes) { {1 => {'id' => [nil, 1]}} }
    let(:raw_changes) { {City => city_changes, Country => country_changes} }
    subject { described_class.new(raw_changes) }

    it "should find models" do
      expect(subject.models).to eq([City, Country])
    end

    it "should implement []" do
      expect(subject[City]).to eq(Tantot::Changes::ById.new(city_changes))
    end

    it "should implement Enumerable" do
      expect(subject.collect {|model, changes| [model, changes]}).to eq([
        [City, Tantot::Changes::ById.new(city_changes)],
        [Country, Tantot::Changes::ById.new(country_changes)]
      ])
    end
  end

end
