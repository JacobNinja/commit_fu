module CommitFu
  module Commit
    def ruby_diffs
      diffs.select do |diff|
        diff_filename(diff).match(/\.rb$/) && !diff_filename(diff).match(/_spec|_steps|_test\.rb$/)
      end
    end

    private

    def diff_filename(diff)
      diff.a_path || diff.b_path || ""
    end
  end
end