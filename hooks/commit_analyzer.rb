require File.expand_path('commit_fu')
require 'grit'

repo = Grit::Repo.new(ENV["GIT_DIR"])
commit = repo.commit('HEAD')

post_commit = PostCommit.new(commit)
errors = post_commit.critique.inject([]) do |errors, (file_name, scores)|
  errors + scores.inject([]) do |collection, score|
    score_errors = score.errors.flatten
    collection + (score_errors.empty? ? [] : [[score.method_name, score_errors]])
  end
end
puts "Consider refactoring your code in the following areas:" unless errors.empty?
errors.each do |(method_name, method_errors)|
  puts "Errors for #{method_name}:" unless method_errors.empty?
  method_errors.each {|error| puts "\t#{error}"}
end