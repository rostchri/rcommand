module RCommand
  class Command < DSLBlock::UniversalItem
    attr_accessor :cmdline
    def initialize(options={},&block)
      # set some default options
      # options = options.reverse_merge :show  => false
      # set some instance-variables according to option-values
      set :cmdline => options.delete(:cmd)
      super
    end
  end
end