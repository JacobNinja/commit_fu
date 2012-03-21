require 'spec_helper'

class MockCommit
end

describe CommitFu::FlogCommit do

  let(:commit) { double('Grit::Commit') }
  let(:diff) { double('Grit::Diff') }
  let(:flog) { double('Flog').as_null_object }
  let(:sut) { MockCommit.new.extend(CommitFu::FlogCommit) }

  before do
    sut.stub(:diffs).and_return([diff])
    flog.should_receive(:reset).any_number_of_times
    sut.should_receive(:flog).any_number_of_times.and_return(flog)
  end

  describe "#scores" do

    let(:a_blob) { stub("Blob", :id => "XXX") }
    let(:b_blob) { stub("Blob", :id => "YYY") }
    let(:rugged_repo) { stub("Rugged::Repository") }

    before do
      diff.stub(:a_blob).and_return(a_blob)
      diff.stub(:b_blob).and_return(b_blob)
      diff.stub(:a_path).and_return('file1.rb')
      diff.stub(:b_path).and_return('file2.rb')
      sut.stub_chain(:repo, :working_dir).and_return("working dir")
      Rugged::Repository.should_receive(:new).with("working dir").any_number_of_times.and_return(rugged_repo)
    end

    it "provides an array containing [file_name, old_score, new_score] for each diff" do
      rugged_repo.should_receive(:lookup).with(a_blob.id).and_return(stub("Rugged::Blob", :content => :a_blob_data))
      rugged_repo.should_receive(:lookup).with(b_blob.id).and_return(stub("Rugged::Blob", :content => :b_blob_data))
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

    it "converts nil to zero when code has syntax error" do
      sut.should_receive(:diff_score).and_return([50.0, nil])
      sut.scores.should == [["file1.rb", 50.0, 0.0]]
    end

    context "new file" do

      before do
        diff.stub(:b_path).and_return('newfile.rb')
        diff.stub(:a_path).and_return(nil)
        diff.stub(:a_blob).and_return nil
        rugged_repo.should_receive(:lookup).with(b_blob.id).and_return(stub("Rugged::Blob", :content => :b_blob_data))
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
        rugged_repo.should_receive(:lookup).with(a_blob.id).and_return(stub("Rugged::Blob", :content => :a_blob_data))
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

  describe "#total_score" do
    it "returns sum of accumulated score" do
      sut.stub(:scores).and_return([['file1.rb', 1.0, 2.0], ['file2.rb', 5.0, 10.0]])
      sut.total_score.should == 6.0
    end
    it "returns 0 if before_score is nil" do
      sut.stub(:scores).and_return([['file.rb', nil, 5.0]])
      sut.total_score.should == 0.0
    end
    it "returns 0 if after_score is nil" do
      sut.stub(:scores).and_return([['file.rb', 10.0, nil]])
      sut.total_score.should == 0.0
    end
  end

  describe "#score" do

    let(:code) { "class Test; end" }

    it "retries scoring once if NoMethodError is raised" do
      flog.should_receive(:flog).with(code).and_raise NoMethodError
      flog.should_receive(:flog).with(code)
      flog.should_receive(:total).and_return 10
      sut.score(code).should == 10
    end

    it "retries scoring only once" do
      flog.should_receive(:flog).with(code).and_raise NoMethodError
      flog.should_receive(:flog).with(code).and_raise NoMethodError
      sut.score(code)
    end
  end
end