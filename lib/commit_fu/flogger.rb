require 'flog'

module FlogCommit
  include Commit
  def flog
    @flog ||= Flog.new
  end

  def average
    scores.reduce(0.0) do |memo, score|
      _, before_score, after_score = score
      (after_score - before_score) + memo
    end / scores.size.to_f
  end

  def scores
    @scores ||= ruby_diffs.map do |diff|
      [diff_filename(diff)] + diff_score(diff)
    end
  end

  private

  def diff_score(diff)
    [:a_blob, :b_blob].map do |message|
      blob = diff.send(message)
      blob.nil? ? 0.0 : score(blob.data)
    end
  end

  def score(code)
    flog.reset
    flog.flog(code)
    flog.total
  end
end