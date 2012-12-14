module RCommand
  class Group < DSLBlock::UniversalItem
    attr_accessor :commands
    def initialize(options={},&block)
      # set some default options
      options = options.reverse_merge :order  => :sequential,
                                      :save   => false,
                                      :stdout => false,
                                      :stderr => false
      # set some instance-variables according to option-values
      set :commands  => {}
      super
    end
    
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => true
      res = "#{self.class.name}: ##{id} options: #{options}"
      commands.each { |id,command| res += "\n#{(depth+1).times.map {"\t"}.join("")}#{command.to_s(opts)}" } if opts[:include_children]
      res
    end
    
    def add_command(options = {}, &block)
      command = Command.new(options.merge!({}), &block)
      commands[command.id] = command
    end

  end
end