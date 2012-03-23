require File.expand_path('../../flog', __FILE__)
require 'rugged'

module CommitFu
  module FlogCommit

    include Commit

    def flog
      @flog ||= Flog.new
    end

    def average
      average_score = score_sum / scores.size.to_f
      average_score.nan? ? 0.0 : average_score
    end

    def scores(diffs_to_score=ruby_diffs)
      @scores ||= diffs_to_score.map do |diff|
        [diff_filename(diff), *diff_score(diff)]
      end
    end

    def score_files(files)
      scores(ruby_diffs.select {|diff| files.include?(diff_filename(diff))})
    end

    def total_score
      scores.reduce(0) do |calculated_score, (_, before_score, after_score)|
        calculated_score + accumulated_score(before_score, after_score)
      end
    end

    def score(code)
      with_retry(NoMethodError) do
        flog.reset
        flog.flog(code)
        flog.total
      end
    rescue Racc::ParseError, SyntaxError
      nil
    end

    private

    def diff_score(diff)
      [:a_blob, :b_blob].map do |message|
        blob = diff.send(message)
        blob.nil? ? 0.0 : score(get_contents(blob))
      end
    end

    def score_sum
      scores.reduce(0.0) do |memo, score|
        _, before_score, after_score = score
        (after_score - before_score) + memo
      end
    end

    def accumulated_score(before_score, after_score)
      if before_score && after_score
        after_score - before_score
      else
        0.0
      end
    end

    def with_retry(exception, &block)
      retry_count = 0
      begin
        block.call
      rescue exception
        retry_count += 1
        retry unless retry_count > 1
      end
    end

    def get_contents(blob)
      rugged_repo = Rugged::Repository.new(self.repo.working_dir)
      rugged_repo.lookup(blob.id).content
    end
  end
end
