require File.expand_path('/Users/jacobr/code/metrics/commit_fu/lib/commit_fu', __FILE__)
require '/Users/jacobr/code/grit/lib/grit'

repo = Grit::Repo.new(ENV["GIT_DIR"])
commit = repo.commit('HEAD')

post_commit = PostCommit.new(commit)
errors = post_commit.critique.inject([]) do |errors, (file_name, scores)|
  errors + scores.inject([]) do |coll, score|
    score_errors = score.errors.flatten
    coll + (score_errors.empty? ? [] : [[score.method_name, score_errors]])
  end
end
puts "Consider refactoring your code in the following areas:" unless errors.empty?
errors.each do |(method_name, method_errors)|
  puts "Errors for #{method_name}:" unless method_errors.empty?
  method_errors.each {|error| puts "\t#{error}"}
end