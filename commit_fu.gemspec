Gem::Specification.new do |s|
  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.name = 'commit_fu'
  s.version = '0.1'
  s.date = '2011-10-24'

  s.summary = "Grit commit extensions for analysis"
  s.description = "Allows you to extend an instance of Grit::Commit and run certain metrics on it"

  s.authors = ["Jacob Richardson"]
  s.email = 'jacob.ninja.dev@gmail.com'

  s.require_paths = %w[lib]

  s.add_dependency('grit')
  s.add_dependency('sexp_processor', '~> 3.0')
  s.add_dependency('ruby_parser', '~> 2.0')
  s.add_dependency('rugged')

  s.add_development_dependency('rspec')

  # = MANIFEST =
  s.files = %w[
    commit_fu.gemspec
    lib/commit_fu.rb
    lib/flog.rb
    lib/commit_fu/churn.rb
    lib/commit_fu/commit.rb
    lib/commit_fu/flogger.rb
    lib/commit_fu/post_commit.rb
  ]
  # = MANIFEST =

  s.test_files = s.files.select { |path| path =~ /^spec\/.*_spec\.rb/ }
end
