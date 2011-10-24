require 'spec_helper'

class MockCommit
end

describe FlogCommit do

  let(:commit) { double('Grit::Commit') }
  let(:diff) { double('Grit::Diff') }
  let(:sut) { MockCommit.new.extend(FlogCommit) }

  before do
    sut.stub(:diffs).and_return([diff])
  end

  describe "#scores" do

    let(:flog) { double('Flog').as_null_object }

    before do
      diff.stub_chain(:a_blob, :data).and_return(:a_blob_data)
      diff.stub_chain(:b_blob, :data).and_return(:b_blob_data)
      sut.should_receive(:flog).any_number_of_times.and_return(flog)
      diff.stub(:a_path).and_return('file1.rb')
      diff.stub(:b_path).and_return('file2.rb')
      flog.should_receive(:reset).any_number_of_times
    end

    it "provides an array containing [file_name, old_score, new_score] for each diff" do
      flog.should_receive(:flog).with(:a_blob_data)
      flog.should_receive(:flog).with(:b_blob_data)
      flog.should_receive(:total).and_return(0.0)
      flog.should_receive(:total).and_return(1.0)
      sut.scores.to_a.should == [['file1.rb', 0.0, 1.0]]
    end

    it "skips scoring non ruby files" do
      non_ruby_diff = double('Grit::Diff')
      sut.stub(:diffs).and_return([non_ruby_diff])
      non_ruby_diff.stub(:a_path).and_return('cucumber.feature')
      sut.scores.to_a.should == []
    end

    it "skips scoring test files" do
      non_ruby_diff = double('Grit::Diff')
      sut.stub(:diffs).and_return([non_ruby_diff])
      non_ruby_diff.stub(:a_path).and_return('ruby_spec.rb')
      sut.scores.to_a.should == []
    end

    it "skips scoring step files" do
      non_ruby_diff = double('Grit::Diff')
      sut.stub(:diffs).and_return([non_ruby_diff])
      non_ruby_diff.stub(:a_path).and_return('web_steps.rb')
      sut.scores.to_a.should == []
    end

    context "new file" do

      before do
        diff.stub(:b_path).and_return('newfile.rb')
        diff.stub(:a_path).and_return(nil)
        diff.stub(:a_blob).and_return nil
        flog.should_receive(:flog).with(:b_blob_data)
        flog.should_receive(:total).and_return(1.0)
      end

      it "uses b_blob name" do
        sut.scores.to_a.first.take(1).should == ['newfile.rb']
      end
      it "scores a at 0.0" do
        sut.scores.to_a.first.drop(1).should == [0.0, 1.0]
      end
    end

    context "deleted file" do

      before do
        flog.should_receive(:flog).with(:a_blob_data)
        flog.should_receive(:total).and_return(1.0)
        diff.stub(:b_path).and_return(nil)
        diff.stub(:b_blob).and_return(nil)
      end

      it "scores b at 0.0" do
        sut.scores.to_a.first.drop(1).should == [1.0, 0.0]
      end
    end
  end

  describe "#average" do
    it "calculates average flog score of all files in commit" do
      sut.stub(:scores).and_return([['file1.rb', 1.0, 2.0], ['file2.rb', 5.0, 10.0]])
      sut.average.should == 3.0
    end
  end
end