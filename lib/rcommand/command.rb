module RCommand
  class Command < DSLBlock::UniversalItem
    attr_accessor :cmdline
    def initialize(options={},&block)
      # set some default options
      # options = options.reverse_merge :show  => false
      # set some instance-variables according to option-values
      set :cmdline => options.delete(:cmdline)
      super
    end
    
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => false
      res = "#{self.class.name}: ##{id} cmdline: #{cmdline} options: #{options}"
      res
    end
    
  end
end