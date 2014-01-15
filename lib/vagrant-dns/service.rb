require 'daemons'


module VagrantDNS
  class Service
    attr_accessor :tmp_path, :options
    
    def initialize(tmp_path)
      self.tmp_path = tmp_path
    end

    def start!
      run_options = {:ARGV => ["start"]}.merge(runopts)
      run!(run_options)
    end

    def start_fg!
      run_options = {:ARGV => ["start"], :fg => true}.merge(runopts)
      run!(run_options)
    end

    def stop!
      run_options = {:ARGV => ["stop"]}.merge(runopts)
      run!(run_options)
    end

    def run!(run_options)
      if run_options[:fg]
        run_server
      else
        Daemons.run_proc("vagrant-dns", run_options) do
          run_server
        end
      end
    end

    def restart!
      stop!
      start!
    end
    
    def runopts
      {:dir_mode => :normal, 
       :dir => File.join(tmp_path, "daemon"),
       :log_output => true,
       :log_dir => File.join(tmp_path, "daemon")}
    end
    
    def config_file
      File.join(tmp_path, "config")
    end

    private

    def run_server
      require 'rubydns'
      require 'rubydns/system'

      registry = YAML.load(File.read(config_file))
      std_resolver = RubyDNS::Resolver.new(RubyDNS::System::nameservers)

      RubyDNS::run_server(:listen => VagrantDNS::Config.listen) do
        registry.each do |pattern, ip|
          puts "match #{pattern} #{ip}"
          match(Regexp.new(pattern), Resolv::DNS::Resource::IN::A) do |transaction, match_data|
            transaction.respond!(ip)
          end
        end

        otherwise do |transaction|
          puts "otherwise #{transaction.inspect}"
          transaction.passthrough!(std_resolver) do |reply, reply_name|
            puts reply
            puts reply_name
          end
        end
      end
    end
  end
end
