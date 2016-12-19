require "spec_helper"

describe Tantot::Agent::Block do
  context "normal usage" do
    let(:value) { {changes: 0} }
    let(:changes) { {obj: nil} }
    before do
      v = value
      c = changes
      stub_model(:city) do
        watch {|changes| v[:changes] += 1; c[:obj] = changes}
      end
    end

    it "should call the block" do
      city = nil
      Tantot.manager.run do
        city = City.create!
      end
      expect(value[:changes]).to eq(1)
      expect(changes[:obj]).to eq(Tantot::Changes::ById.new({city.id => {"id" => [nil, 1]}}))
    end

    it "should call a single time if multiple changes occur" do
      Tantot.manager.run do
        3.times { City.create! }
      end
      expect(value[:changes]).to eq(1)
      expect(changes[:obj]).to eq(Tantot::Changes::ById.new({1=>{"id"=>[nil, 1]}, 2=>{"id"=>[nil, 2]}, 3=>{"id"=>[nil, 3]}}))
    end
  end

  context "validations" do
    it "should prevent registering twice with the same options" do
      expect do
        stub_model(:city) do
          watch {}
          watch {}
        end
      end.to raise_error(Tantot::MultipleWatchesProhibited, /Can't have multiple/)
    end

    it "should allow registering twice with different options" do
      expect do
        stub_model(:city) do
          watch {}
          watch(:name) {}
        end
      end.not_to raise_error
    end
  end
end
