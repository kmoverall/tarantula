module CsvExchange
  class Import
    class SimulationDone < StandardError; end
  
    def initialize(file, simulate=false, logger=nil, 
                   col_sep=';', row_sep="\r\n")
      @lines = file.read.split(row_sep)
      @simulate = simulate
      @col_sep = col_sep
      @row_sep = row_sep
      @log = StringIO.new
      @logger = logger || CsvExchange::Logger.new(@log)
    end
  
    def log; @log.string; end
    
    def process
      @logger.create_msg("Starting a new CSV import..")
      begin
        find_header
        @klass.transaction do
          chunks = self.class.chunkify(@lines, @col_sep, @row_sep)
          chunks.each do |c|
            @klass.update_from_csv(c, @logger, @col_sep, @row_sep)
          end
          if @simulate
            raise SimulationDone.new
          else
            @logger.info "Done."
          end
        end
      rescue SimulationDone => e
        @logger.info "Simulation done."
      rescue Exception => e
        @logger.error_msg e.message+"\n"+e.backtrace.join("\n")
      end
    end

    def self.chunkify(csv_lines, col_sep, row_sep)
      chunks = []
      chunk = csv_lines.delete_at(0)
      while(line = csv_lines.delete_at(0))
        if line =~ /^""#{col_sep}.*/ or line[0,1] == col_sep
          chunk += row_sep+line
        else
          chunks << chunk
          chunk = line
        end
      end
      chunks << chunk
      chunks
    end

    private
  
    def find_header
      classes = CsvExchange::Info.classes
      headers = {}
      classes.each do |klass|
        headers[klass.csv_header(@col_sep, @row_sep)] = klass
      end
      
      while(line = @lines.delete_at(0))
        next if line.empty?
        if @klass = headers[line+@row_sep]
          @logger.info "Found #{@klass} header."
          break
        else
          raise "Unknown CSV header: \"#{line}\""
        end
      end
    end
 
  end

end