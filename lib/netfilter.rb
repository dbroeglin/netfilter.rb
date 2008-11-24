module Netfilter

  require 'lib/combinate'

  class Table
    attr_reader :name
    attr_reader :chains

    def initialize(name)
      @name = name
      @chains = []
    end

    def new_chain(name)
      Chain.new(self, name)
    end

    def method_missing(method, *args)
      if chain = @chains.find { |c| c.name == method.to_s }
        chain
      else
        super
      end
    end

    def rules
      all_rules = []
      @chains.each do |c|
        c.rules.each { |r| all_rules << [to_nfarg, r].join(' ') }
      end
      all_rules
    end

    def to_nfarg
      "-t #{name}"
    end

  end

  class FilterTable < Table
    def initialize
      @name = "filter"
      @chains = []
      @chains << new_chain("input")
      @chains << new_chain("forward")
      @chains << new_chain("output")
    end
  end

  class Chain
    attr_reader :name
    attr_reader :table

    def initialize(table, name)
      @table = table
      @name = name
      @rules = []
    end

    def with_scope(*args, &block)
      @scope = args.first
      self.instance_exec(&block)
    ensure
      @scope = nil
    end

    def scope
      @scope||{}
    end

    def accept(options = {})
      new_rule(options.update(:action => :accept))
    end

    def drop(options = {})
      new_rule(options.update(:action => drop))
    end

    def log(options = {})
      new_rule(options.update(:action => :log))
    end

    # Create a new rule, merging in any scope and passing in this chain
    def new_rule(options = {})
      @rules << Rule.new(options.update(scope).update(:chain => self))
    end

    def rules
      if @rules.empty?
        []
      else
        all_rules = []
        @rules.each { |r| all_rules += [to_nfarg, r.to_nfargs].combinate }
        all_rules
      end
    end

    def to_nfarg
      "-A #{name}"
    end
  end

  class Rule
    attr_reader :options

    def initialize(options = {})
      @options = options
    end

    def to_nfargs
      options.combinate.collect { |o| "rule: #{o.keys.join(" ")}" }
    end

  end

  def filter
    @filter_table ||= FilterTable.new
  end
end

