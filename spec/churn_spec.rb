require 'spec_helper'

class MockCommit
end

describe ChurnCommit do

  let(:sut) { MockCommit.new.extend(ChurnCommit) }
  let(:diff) { double('Grit::Diff') }

  before do
    diff.stub(:a_path).and_return('file1.rb')
    sut.stub(:diffs).and_return([diff])
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

    it "reports class name as first item" do
      method_details.first.should == :Test
    end
    it "reports line range of A as second item" do
      method_details[1].should == [(1..2)]
    end
    it "reports line range of B as third item" do
      method_details[2].should == [(1..3)]
    end
  end

  describe "#score_methods" do

    before do
      diff.stub_chain(:a_blob, :data).and_return("class Test\ndef some_method(a, b)\nend\nend")
      diff.stub_chain(:b_blob, :data).and_return("class Test\ndef some_method(a, b, c)\n1 + 1\nend\nend")
    end

    def method_details
      sut.score_methods[:Test].first
    end


    it "returns hash of class names" do
      sut.score_methods.keys.first.should == :Test
    end
    context "returns hash of values that" do
      it "have each method" do
        method_details.first.should == "#some_method"
      end
      it "have method arity difference" do
        method_details[1].should == 1
      end
      it "have line range of A" do
        method_details[2].should == (2..3)
      end
      it "have line range of B" do
        method_details[3].should == (2..4)
      end
    end
  end

end

describe Churn do

  describe "self#modules" do
    it "returns hash of modules and line numbers" do
      test_class = "class Test\nend"
      Churn.modules(test_class).should == {:Test => [(1..2)]}
    end
  end

  describe "self#methods" do
    before do
      @test_class = "class Test\ndef test_method(a, b, c)\nend\nend"
    end

    def method_details
      Churn.all_methods(@test_class)[:Test].first
    end

    it "returns hash of modules with each method as first element of each" do
      method_details.first.should == "#test_method"
    end
    it "provides method arity as second element" do
      method_details[1].should == 3
    end
    it "provides method line range as third element" do
      method_details[2].should == (2..3)
    end
  end

end