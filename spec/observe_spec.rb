require "spec_helper"

describe Tantot::Observe::ActiveRecordMethods do

  describe ".watch" do
    before do
      stub_class(:some_watcher) do
        include Tantot::Watcher
      end
    end

    it "should validate that at least a watcher or a block is defined" do
      expect do
        stub_model(:no_block_no_watcher_model) do
          watch
        end
      end.to raise_error(Tantot::UnresolvableAgent, /Can't resolve/)
    end

    it "should validate that no more than one agent can be specified" do
      expect do
        stub_model(:block_and_watcher_model) do
          watch(SomeWatcher) {}
        end
      end.to raise_error(Tantot::UnresolvableAgent, /More than one/)
    end

    it "should allow registering a simple block watch" do
      stub_model(:block_model) do
        watch {}
      end
    end

    it "should allow registering a simple watcher watch" do
      stub_model(:watcher_model) do
        watch SomeWatcher
      end
    end

    it "should treat additional arguments as the :only option" do
      stub_model(:block_model)

      agent = BlockModel.watch(:foo, :bar) {}

      expect(agent.watches.first.attributes[:only]).to eq(['foo', 'bar'])
    end

    it "prevent bad arguments" do
      stub_model(:block_model)

      expect { BlockModel.watch(SomeWatcher, SomeWatcher, :foo, :bar) }.to raise_error(ArgumentError, /symbol/)
      expect { BlockModel.watch(:foo, "string", :bar) {} }.to raise_error(ArgumentError, /symbol/)
      expect { BlockModel.watch(:foo, SomeWatcher, :bar) {} }.to raise_error(ArgumentError, /symbol/)
      expect { BlockModel.watch(:foo, :bar, only: :baz) {} }.to raise_error(ArgumentError, /Only one of/)
    end
  end

end

