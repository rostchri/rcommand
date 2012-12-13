require 'net/ssh'
require 'net/ssh/gateway'
require 'dslblock'

module RCommand
    
  class Connection < DSLBlock::UniversalItem
    attr_accessor :host, :username, :password, :commands
    
    def initialize(options={},&block)
      # set some default options
      # options = options.reverse_merge :show  => false
      # set some instance-variables according to option-values
      set :host      => options.delete(:host),
          :username  => options.delete(:username),
          :password  => options.delete(:password),
          :commands  => {}
      super
    end
    
    def to_s(opts={})
      opts = opts.reverse_merge :include_children => false
      res = "#{self.class.name}: ##{id} #{username}@#{host} depth: #{depth} options: #{options}"
      commands.each { |id,command| res += "\n#{(depth+1).times.map {"\t"}.join("")}#{command.to_s(opts)}" } if opts[:include_children]
      res
    end
    
    # adding new command
    def add_command(options = {}, &block)
      command = Command.new(options.merge!({}), &block)
      commands[command.id] = command
    end
    
    def execute
      sshopts = [host, username]
      sshopts << password unless password.nil? || password.empty? 
      sshopts << :verbose => Logger::ERROR
      Net::SSH.start(sshopts*) do |ssh|
        # open a new channel and configure a minimal set of callbacks, then run
        # the event loop until the channel finishes (closes)
        channel = ssh.open_channel do |ch|
          ch.exec "hostname" do |ch, success|
            raise "could not execute command" unless success
            ch.on_data do |c, data| # "on_data" is called when the process writes something to stdout
              $STDOUT.printf "%p %p\n", c, data
            end
            ch.on_extended_data do |c, type, data| # "on_extended_data" is called when the process writes something to stderr
              $STDERR.printf "%p %p %p\n", c, type, data
            end
            ch.on_close { puts "done!" }
          end
        end
        channel.wait
      end
    end
    
    def oldexecute(hostname,precmds,cmds,direct=false)
      cache_last = []
      begin
        gateway = Net::SSH::Gateway.new('dskinst001', 'root', :verbose => Logger::ERROR)
        gateway.ssh(hostname, "root", {:verbose => Logger::ERROR} ) do |ssh|

          precmds.each_with_index do |command,index|
            yield index, ssh.exec!(command)
          end

          cmds.each do |command|
            ssh.open_channel do |channel|

              # stderr
              channel.on_extended_data do |channel,type,data|
                data.each_line { |l| printf("### STD-ERROR @%d [CMD: %s]  %s\n", channel.local_id + precmds.size , command , l.chop) } if type==1 
              end

              # stdout
              channel.on_data do |channel,data|
                if data[-1] == "\n"
                  if cache_last[channel.local_id]
                    if direct==false
                      cache_last[channel.local_id]+=data
                    else
                      yield channel.local_id, cache_last[channel.local_id] + data
                      cache_last[channel.local_id] = nil
                    end 
                  else
                    if direct==false
                      cache_last[channel.local_id] = data
                    else
                      yield channel.local_id, data
                    end 
                  end
                else
                  # Falls hinten kein \n so ist die Zeile nicht komplett übermittelt und muss als Präfix für die nächste Zeile gecached werden    
                  cache_last[channel.local_id] ? cache_last[channel.local_id] += data : cache_last[channel.local_id] = data
                end
              end

              # eof
              channel.on_eof do |channel|
                #printf("### EOF-CHAN: %d CMD: %s\n", channel.local_id, command)
                yield channel.local_id, cache_last[channel.local_id] if direct==false
              end

              channel.exec command
            end
          end
        end
        gateway.shutdown!
      rescue Net::SSH::HostKeyMismatch => e
        puts "remembering new key: #{e.fingerprint}"
        e.remember_host!
        retry
      rescue Exception => ex
        printf("### ERROR: %s [%s]\n%s\n",ex.message, ex.class, ex.backtrace.join("\n"))
      end
    end
  end
  
  
  def rcommand(options={}, &block)
    Connection.new(options.merge!({}),&block)
  end
  
end