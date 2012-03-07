require 'ostruct'
require 'rubygems'
require 'roodi'

class CommitScore < OpenStruct
end

class PostCommit

  attr_reader :commit

  def initialize(commit)
    @commit = commit.extend(CommitFu::ChurnCommit).extend(CommitFu::FlogCommit)
  end

  def analyze
    commit.score_methods.each_with_object(Hash.new {|h, k| h[k] = []}) do |(file_name, score), hsh|
      flog_scores = score.inject([]) do |flog_scores, (commit_details)|
        before_range, after_range = commit_details[:line_range_a], commit_details[:line_range_b]
        diff = commit.diffs.find {|diff| (diff.a_path || diff.b_path) == file_name }
        before_score = commit.score(blob_contents(diff, :a_blob, before_range))
        after_commit_content = blob_contents(diff, :b_blob, after_range)
        after_score = commit.score(after_commit_content)
        accumulated_score = after_score - before_score
        commit_args = {:module_name => commit_details[:module], :method_name => commit_details[:method], :flog_score => accumulated_score,
                       :lines_added => ((after_range.max - after_range.min) - (before_range.max - before_range.min)),
                       :b_blob => after_commit_content }
        flog_scores + Array(commit_score(commit_args, accumulated_score))
      end
      hsh[file_name] += flog_scores unless flog_scores.empty?
    end
  end

  def critique
    analyze.each_with_object(Hash.new {|h, k| h[k] = []}) do |(file_name, commit_scores), hsh|
      valid_scores = commit_scores.select do |commit_score|
        (commit_score.flog_score / commit_score.lines_added) > 1
      end.each do |commit_score|
        commit_score.errors = roodi.check(file_name, commit_score.b_blob).inject([]) do |errors, score|
          errors + score.errors
        end
      end
      hsh[file_name] += valid_scores unless valid_scores.empty?
    end
  end

  def roodi
    Roodi::Core::Runner.new
  end

  def blob_contents(diff, blob, line_range)
    return "" if line_range.max.zero?
    ((code_blob = diff.send(blob) and code_blob.data) || "").split("\n").slice(adjust_line_range(line_range)).join("\n")
  end

  private

  def commit_score(args_as_hash, accumulated_score)
    CommitScore.new(args_as_hash) if accumulated_score > 0
  end

  def adjust_line_range(line_range)
    (line_range.begin - 1)..(line_range.end - 1)
  end

end