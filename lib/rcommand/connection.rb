require 'net/ssh'
require 'net/ssh/gateway'
require 'dslblock'

module RCommand
    
  class Connection < DSLBlock::UniversalItem
    attr_accessor :host, :username, :password, :groups
    
    def initialize(options={},&block)
      # set some default options
      options = options.reverse_merge :wait => true
      # set some instance-variables according to option-values
      set :host      => options.delete(:host),
          :username  => options.delete(:username),
          :password  => options.delete(:password),
          :groups    => {}
      super
    end
    
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => true
      res = "#{self.class.name}: ##{id} #{username}@#{host} depth: #{depth} options: #{options}"
      groups.each { |id,group| res += "\n#{(depth+1).times.map {"\t"}.join("")}#{group.to_s(opts)}" } if opts[:include_children]
      res
    end
    
    # adding new sequential command group
    def sequential_commands(options = {}, &block)
      group = Group.new(options.merge!({:order => :sequential}), &block)
      groups[group.id] = group
    end

    # adding new parallel command group
    def parallel_commands(options = {}, &block)
      group = Group.new(options.merge!({:order => :parallel}), &block)
      groups[group.id] = group
    end
    
    def processing_ssh_connection(ssh)
      # open a new channel and configure a minimal set of callbacks, then run
      # the event loop until the channel finishes (closes)
      groups.each do |id,group|
        group.commands.each do |id,command|
          puts command.cmdline
          channel = ssh.open_channel do |ch|
            ch.exec command.cmdline do |ch, success|
              raise "could not execute command: #{command.cmdline}" unless success
              ch.on_data do |c, data| # "on_data" is called when the process writes something to stdout
                printf "STDOUT (#%p/%p): %p\n", c.local_id, c.remote_id, data
              end
              ch.on_extended_data do |c, type, data| # "on_extended_data" is called when the process writes something to stderr
                printf "STDERR[%p] (#%p/%p): %p\n", type, c.local_id, c.remote_id, data
              end
              ch.on_close do |c|
                printf  "### INFO: channel #%p/%p closed\n", c.local_id, c.remote_id 
              end
            end
          end
          channel.wait if group.options[:order] == :sequential
        end
      end
    end
    
    def execute
      hostopts = {:verbose => Logger::ERROR}
      hostopts.merge!({:password => password}) unless password.nil? || password.empty? 
      hostargs = [host, username, hostopts]
      unless options[:gateway].nil?
        gatewayopts = {:verbose => Logger::ERROR}
        gatewayopts.merge!({:password => options[:gateway][:password]}) unless options[:gateway][:password].nil? || options[:gateway][:password].empty? 
        gatewayargs = [options[:gateway][:host], options[:gateway][:username], gatewayopts]
      end
      begin
        unless options[:gateway].nil?
          Net::SSH::Gateway.new(*gatewayargs).ssh(*hostargs) { |ssh| processing_ssh_connection(ssh) }
        else
          Net::SSH.start(*hostargs) { |ssh| processing_ssh_connection(ssh) }
        end
      rescue Net::SSH::HostKeyMismatch => e
        puts "### INFO: remembering new key: #{e.fingerprint}"
        e.remember_host!
        retry
      rescue Exception => ex
        printf "### ERROR in connection: %s@%s: %s [%s]\n%s\n", username, host, ex.message, ex.class, ex.backtrace.join("\n")
      end
    end
  end
  
  
  def rcommand(options={}, &block)
    Connection.new(options.merge!({}),&block)
  end
  
end