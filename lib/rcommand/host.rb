module RCommand
  class Host < DSLBlock::UniversalItem
    attr_accessor :hostname, :username, :password, :groups
    def initialize(options={},&block)
      # set some default options
      options = options.reverse_merge :save   => false,
                                      :stdout => false,
                                      :stderr => false,
                                      :debug  => false
                                      
      # set some instance-variables according to option-values
      set :hostname => options.delete(:hostname),
          :username => options.delete(:username),
          :password => options.delete(:password),
          :groups   => {}
      super
    end
        
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => true
      res = "#{self.class.name}: ##{id} #{username}@#{hostname} options: #{options}"
      groups.each { |id,group| res += "\n#{(depth+1).times.map {"\t"}.join("")}#{group.to_s(opts)}" } if opts[:include_children]
      res
    end
    
    # adding new command group with following possible options:
    # :order  => :sequential (default)
    # :order  => :parallel
    def add_group(options = {}, &block)
      group = Group.new(options, &block)
      groups[group.id] = group
    end
    
    def execute_commands
      hostopts = {:verbose => Logger::ERROR}
      hostopts.merge!({:password => password}) unless password.nil? || password.empty? 
      hostargs = [hostname, username, hostopts]
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
        printf "### ERROR in connection: %s@%s: %s [%s]\n%s\n", username, hostname, ex.message, ex.class, ex.backtrace.join("\n")
      end
    end
    
    def processing_ssh_connection(ssh)
      # open a new channel and configure a minimal set of callbacks, then run
      # the event loop until the channel finishes (closes)
      groups.each do |id,group|
        group.commands.each do |id,command|
          channel = ssh.open_channel do |ch|
            ch.exec command.cmdline do |ch, success|
              
              if success
                printf  "### DEBUG %10.10s [#%p/%p] executing: %s\n", command.id, ch.local_id, ch.remote_id, command.cmdline if debug?
              else
                raise "could not execute command: #{command.cmdline}"
              end
              
              # STDOUT-Channel
              ch.on_data do |ch, data| # "on_data" is called when the process writes something to stdout
                command.process_raw(data,save? || group.save? || command.save?) do |output|
                  printf "### INFO  %10.10s [#%p/%p] STDOUT: %s\n", command.id, ch.local_id, ch.remote_id, output if stdout? || group.stdout? || command.stdout?
                end
              end

              # STDERR-Channel
              ch.on_extended_data do |ch, type, data| # "on_extended_data" is called when the process writes something to stderr
                command.process_raw(data,save? || group.save? || command.save?) do |output|
                  printf "### INFO  %10.10s [#%p/%p] STDERR#%p: %s\n", command.id, ch.local_id, ch.remote_id, type, output if stderr? || group.stderr? || command.stderr?
                end
              end
              
              ch.on_close do |ch|
                printf "### DEBUG %10.10s [#%p/%p] FINISHED. %s received: %d\n", command.id, ch.local_id, ch.remote_id, command.linesplit? ? "Lines" : "Blocks", command.outputcounter if debug?
              end
            end
          end
          channel.wait if group.order == :sequential
        end
      end
    end

  end
end