require 'grit'
require 'spec_helper'

describe PostCommit do

  let(:commit) { Grit::Commit.new(nil, 'X' * 10, [], nil, nil, nil, nil, nil, []) }
  let(:sut) { PostCommit.new(commit) }
  let(:diff) { double('Grit::Diff', :a_path => 'file1.rb', :b_path => 'file1.rb') }
  let(:before_blob) do
    <<-BLOB
class Test
  def some_method
    # nothing
  end
end
    BLOB
  end
  let(:after_blob) do
    <<-BLOB
class Test
  def some_method
    something
    another_thing
    last_thing
  end
end
    BLOB
  end

  before do
    diff.stub_chain(:a_blob, :data).and_return(before_blob)
    diff.stub_chain(:b_blob, :data).and_return(after_blob)
    commit.stub(:diffs).and_return([diff])
  end

  def method_body(blob)
    lines = blob.split("\n")
    lines.slice(1..lines.size.pred.pred).join("\n")
  end

  describe "#analyze" do

    it "returns hash keyed by file name with accumulated commit score for each method" do
      commit.stub(:score).with(method_body(before_blob)).and_return(1)
      commit.stub(:score).with(method_body(after_blob)).and_return(6)
      commit_score = CommitScore.new(:module_name => :Test, :method_name => "#some_method", :flog_score => 5,
                                     :lines_added => 2, :b_blob => method_body(after_blob))
      sut.analyze.should == {'file1.rb' => [commit_score]}
    end
    it "ignores method if flog score stays the same" do
      commit.stub(:score).and_return(5)
      sut.analyze.should == {}
    end
  end

  describe "#critique" do

    before do
      sut.stub(:roodi).and_return(stub('Roodi::Runner').as_null_object)
    end

    it "returns scores from analyze that have high accumulation of churn and complexity and adds errors" do
      commit.stub(:score).with(method_body(before_blob)).and_return(1)
      commit.stub(:score).with(method_body(after_blob)).and_return(11)
      check = stub('Roodi::Check', :errors => [:errors_collection])
      sut.roodi.should_receive(:check).with('file1.rb', method_body(after_blob)).and_return([check])
      # 10 points of complexity and 2 lines added
      result = sut.analyze
      result['file1.rb'].first.errors = check.errors
      sut.critique.should == result
    end

    it "ignores scores that have low complexity with low churn" do
      commit.stub(:score).with(method_body(before_blob)).and_return(1)
      commit.stub(:score).with(method_body(after_blob)).and_return(3)
      # 2 points of complexity and 2 lines added
      sut.critique.should == {}
    end
  end

  describe "#blob_contents" do
    it "returns empty string if zero line range" do
      sut.blob_contents(diff, :a_blob, (0..0)).should == ""
    end
  end

end