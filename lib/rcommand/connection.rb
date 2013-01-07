require 'net/ssh'
require 'net/ssh/gateway'
require 'dslblock'

module RCommand
    
  class Connection < DSLBlock::UniversalItem
    attr_accessor :hosts
    
    def initialize(options={},&block)
      # set some default options
      options = options.reverse_merge :debug       => false,
                                      :maxthreads  => 1
      # set some instance-variables according to option-values
      set :hosts => {}
      super
    end
    
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => true
      res = "#{self.class.name}: ##{id} depth: #{depth}  options: #{options}"
      hosts.each { |id,host| res += "\n#{(depth+1).times.map {"\t"}.join("")}#{host.to_s(opts)}" } if opts[:include_children]
      res
    end

    # adding new host
    def add_host(options = {}, &block)
      host = Host.new(options, &block)
      hosts[host.id] = host
    end
    
    def execute_commands
      puts to_s if debug?
      threads=[]
      hosts.each do |hostid,host|
        tcount = threads.select{|t| t.alive?}.size
        if tcount < maxthreads
      	  threads << Thread.new {host.execute_commands}
      	else
      	  while (tcount =  threads.select{|t| t.alive?}.size) >= maxthreads do 
      	    sleep 0.3
      	  end
          #printf("Now Threads %d < %d\n",tcount,maxthreads)
      	  threads << Thread.new { host.execute_commands}
      	end
      end
      threads.each { |t| t.join }
    end
    
  end
  
  def rcommand(options={}, &block)
    connection = Connection.new(options.merge!({}),&block)
    connection.execute_commands
  end
  
end