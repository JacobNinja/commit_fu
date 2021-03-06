require 'spec_helper'

class MockCommit
end

describe CommitFu::ChurnCommit do

  let(:sut) { MockCommit.new.extend(CommitFu::ChurnCommit) }
  let(:diff) { double('Grit::Diff') }

  before do
    diff.stub(:a_path).and_return('file1.rb')
    sut.stub(:diffs).and_return([diff])
  end

  def method_details
    sut.score_methods['file1.rb'].first
  end

  describe "#score_classes" do

    before do
      @test_class = "class Test\nend"
      diff.stub_chain(:a_blob, :data).and_return(@test_class)
      diff.stub_chain(:b_blob, :data).and_return("class Test\n\nend")
    end

    def method_details
      sut.score_classes.first
    end

    it "reports file name as first item" do
      method_details[:file].should == "file1.rb"
    end

    it "reports class name as second item" do
      method_details[:module].should == :Test
    end
    it "reports line range of A as third item" do
      method_details[:line_range_a].should == [(1..2)]
    end
    it "reports line range of B as fourth item" do
      method_details[:line_range_b].should == [(1..3)]
    end
  end

  describe "#score_methods" do

    context "changed method" do

      before do
        diff.stub_chain(:a_blob, :data).and_return("class Test\ndef some_method(a, b)\nend\nend")
        diff.stub_chain(:b_blob, :data).and_return("class Test\ndef some_method(a, b, c)\n1 + 1\nend\nend")
      end

      it "returns hash of file names" do
        sut.score_methods.keys.first.should == 'file1.rb'
      end

      context "returns hash of values that" do
        it "have module name" do
          method_details[:module].should == :Test
        end
        it "have each method" do
          method_details[:method].should == "#some_method"
        end
        it "have method arity difference" do
          method_details[:arity].should == 1
        end
        it "have line range of A" do
          method_details[:line_range_a].should == (2..3)
        end
        it "have line range of B" do
          method_details[:line_range_b].should == (2..4)
        end
      end
    end

    context "new method" do

      before do
        diff.stub_chain(:a_blob, :data).and_return("class Test\nend")
        diff.stub_chain(:b_blob, :data).and_return("class Test\ndef some_method(a, b, c)\n1 + 1\nend\nend")
      end

      it "reports name of new method" do
        method_details[:method].should == "#some_method"
      end

      it "reports arity of new method" do
        method_details[:arity].should == 3
      end

      it "reports line range of A as 0" do
        method_details[:line_range_a].should == (0..0)
      end

      it "reports line range of B" do
        method_details[:line_range_b].should == (2..4)
      end

    end
  end
end

describe CommitFu::Churn do

  describe "self#modules" do
    it "returns hash of modules and line numbers" do
      test_class = "class Test\nend"
      CommitFu::Churn.modules(test_class).should == {:Test => [(1..2)]}
    end
  end

  describe "self#methods" do
    before do
      @test_class = "class Test\ndef test_method(a, b, c)\nend\nend"
    end

    def method_details
      CommitFu::Churn.all_methods(@test_class)[:Test].first
    end

    it "returns hash of modules with each method as first element of each" do
      method_details[:method].should == "#test_method"
    end
    it "provides method arity as second element" do
      method_details[:arity].should == 3
    end
    it "provides method line range as third element" do
      method_details[:line_range].should == (2..3)
    end
  end

end