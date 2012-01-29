require 'sexp_processor'
require 'ruby_parser'
require File.expand_path('../commit', __FILE__)

class Churn < SexpProcessor

  attr_reader :parser, :modules, :all_methods

  def initialize
    super
    @parser = RubyParser.new
    @modules = Hash.new {|h, k| h[k] = []}
    @all_methods = Hash.new {|h, k| h[k] = []}
    self.auto_shift_type = true
  end

  def self.analyze(code)
    churn = new
    ast = churn.parser.process(code)
    churn.process ast
    churn
  rescue Racc::ParseError, SyntaxError
    #p "There was a syntax error in the following code...\n#{code}"
    churn
  end

  def self.modules(code)
    churn = analyze(code)
    churn.modules
  end

  def self.all_methods(code)
    churn = analyze(code)
    churn.all_methods
  end

  def process_class(exp)
    name = exp.shift
    @current_class = get_name(name)
    @modules[@current_class] << (exp.line..exp.last.line)
    Sexp.new(:class, name, process(exp.shift), process(exp.shift))
  end

  alias_method :process_module, :process_class

  def process_defn(exp)
    name = exp.shift
    parameters = exp.shift
    details = {:method => "##{name.to_s}", :arity => parameters.count - 1, :line_range => (exp.line..exp.last.line)}
    @all_methods[@current_class] << details
    Sexp.new(name, process(parameters), process(exp.shift), process(exp.shift))
  end

  private

  def get_name(name)
    name.is_a?(Sexp) ? name.values.drop(1).join("::") : name
  end
end

module ChurnCommit

  include Commit

  def score_classes
    @score_classes ||= diffs.inject([]) do |churns, diff|
      before_churn = (diff.a_blob and diff.b_blob) ? Churn.modules(diff.a_blob.data) : []
      after_churn = diff.b_blob ? Churn.modules(diff.b_blob.data) : []
      churns + before_churn.select {|mod, _| after_churn.has_key?(mod) }.map do |mod, line_ranges|
        {:file => diff_filename(diff), :module => mod, :line_range_a => line_ranges, :line_range_b => after_churn[mod]}
      end
    end
  end

  def score_methods
    @score_methods ||= ruby_diffs.each_with_object(Hash.new {|h, k| h[k] = []}) do |diff, churns|
      file_name = diff_filename(diff)
      before_churn = method_churn_score(diff.a_blob)
      after_churn = method_churn_score(diff.b_blob)
      after_churn.each do |module_name, b_details|
        b_details.each do |b_detail|
          before_churn
          a_detail = before_churn[module_name].find {|a_details| b_detail[:method] == a_details[:method]}
          b_method_name, b_arity, b_line_range = b_detail[:method], b_detail[:arity], b_detail[:line_range]
          if a_detail
            a_arity, a_line_range = a_detail[:arity], a_detail[:line_range]
          else
            a_arity, a_line_range = 0, (0..0)
          end
          details = {:module => module_name, :method => b_method_name, :arity => b_arity - a_arity, :line_range_a => a_line_range, :line_range_b => b_line_range}
          churns[file_name] << details
        end
      end
    end
  end

  private

  def method_churn_score(blob)
    if blob
      Churn.all_methods(blob.data)
    else
      Hash.new { |h, k| h[k] = [] }
    end
  end

end