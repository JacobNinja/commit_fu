module Commit
  def ruby_diffs
    diffs.select do |diff|
      diff_filename(diff) =~ /\.rb$/ && diff_filename(diff) !~ /_spec|_steps\.rb$/
    end
  end

  private

  def diff_filename(diff)
    diff.a_path || diff.b_path
  end
end