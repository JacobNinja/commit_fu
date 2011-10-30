require 'sexp_processor'
require 'ruby_parser'

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
    #p ast
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
    #p "In process class: #{name}"
    Sexp.new(:class, name, process(exp.shift), process(exp.shift))
  end

  def process_lit(exp)
    literal = exp.shift
    #p "in process lit: #{literal}"
    Sexp.new(:lit, literal, process(exp.shift))
  end

  def process_lasgn(exp)
    variable = exp.shift
    variable_assignment_scope = exp.shift
    #p "In process lasgn: #{variable}\n\t#{variable_assignment_scope}"
    Sexp.new(:lasagn, variable, process(variable_assignment_scope), process(exp.shift))
  end

  def process_block(exp)
    block = exp.shift
    #p "In process block: #{block}"
    Sexp.new(:block, process(block), process(exp.shift))
  end

  alias_method :process_module, :process_class

  def process_defn(exp)
    name = exp.shift
    parameters = exp.shift
    @all_methods[@current_class] << ["##{name.to_s}", parameters.count - 1, (exp.line..exp.last.line)]
    scope = exp.shift
    #p "In process defn: #{name}\n\t#{parameters}\n\t#{scope}"
    Sexp.new(name, process(parameters), process(scope), process(exp.shift))
  end

  def process_if(exp)
    conditional = exp.shift
    truth_scope = exp.shift
    #p "In process if: #{conditional}\n\t#{truth_scope}"
    Sexp.new(process(conditional), process(truth_scope), process(exp.shift))
  end

  def process_call(exp)
    receiver = exp.shift
    method_name = exp.shift
    arg_list = exp.shift
    #p "In process call: #{receiver}\n\t#{method_name}\n\t#{arg_list}"
    Sexp.new(process(receiver), method_name, process(arg_list), process(exp.shift))
  end

  private

  def get_name(name)
    name.is_a?(Sexp) ? name.values.drop(1).join("::") : name
  end
end

module ChurnCommit

  include Commit

  def score_classes
    @score_classes ||= ruby_diffs.inject([]) do |churns, diff|
      before_churn = (diff.a_blob and diff.b_blob) ? Churn.modules(diff.a_blob.data) : []
      after_churn = diff.b_blob ? Churn.modules(diff.b_blob.data) : []
      churns + before_churn.select {|mod, line_ranges|  c = after_churn[mod] and !c.empty?}.map do |mod, line_ranges|
        [mod, line_ranges, after_churn[mod]]
      end
    end
  end

  def score_methods
    @score_methods ||= ruby_diffs.each_with_object(Hash.new {|h, k| h[k] = []}) do |diff, churns|
      before_churn = (diff.a_blob and diff.b_blob) ? Churn.all_methods(diff.a_blob.data) : []
      after_churn = diff.b_blob ? Churn.all_methods(diff.b_blob.data) : []
      before_churn.select {|module_name, details| after_churn[module_name]}.each do |module_name, details|
        details.each do |a_detail|
          b_detail = after_churn[module_name].find {|b_details| b_details.first == a_detail.first}
          if b_detail
            a_method_name, a_arity, a_line_range = a_detail
            b_method_name, b_arity, b_line_range = b_detail
            churns[module_name] << [a_method_name, b_arity - a_arity, a_line_range, b_line_range]
          end
        end
      end
    end
  end

end
