module RCommand
  class Command < DSLBlock::UniversalItem
    attr_accessor :cmdline, :output, :outputcounter
    def initialize(options={},&block)
      # set some default options
      options = options.reverse_merge :custom_block => true,
                                      :linesplit    => true,
                                      :save         => false,
                                      :stdout       => false,
                                      :stderr       => false
      # set some instance-variables according to option-values
      set :cmdline => options.delete(:cmdline)
      super
      @block = block if block_given?
      @output = []
      @outputcounter = 0
    end
    
    
    def process_raw(data,save=false, &block)
      if linesplit?
        data.each_line do |line| 
          line.chomp! 
          @outputcounter += 1
          @block.call(line) unless @block.nil?
          @output << line if save
          yield line if block_given?
        end
      else
        @outputcounter += 1
        @block.call(data) unless @block.nil?
        @output << data if save
        yield data if block_given?
      end
    end
    
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => false
      res = "#{self.class.name}: ##{id} cmdline: #{cmdline} options: #{options}"
      res
    end
    
  end
end