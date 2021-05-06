class Processor
  def self.process!(output, year, letters, numbers_range)
    self.new(output, year, letters, numbers_range).process!
  end

  def self.get_number_of_cores
     if RbConfig::CONFIG["target_os"] =~ /mingw|mswin/
       ENV["NUMBER_OF_PROCESSORS"].to_i
     else
      File.read("/proc/cpuinfo").scan(/^processor/).size
     end
  end

  def initialize(output_file_name, year, letters, numbers_range)
    @root_dir = Pathname.new("data").join(year.to_s)
    @output_file_name = output_file_name
    @filter_enumerator = WorkQueue::PlannedWorkEnumerator.new(year, letters, numbers_range)

    if File.exists?(@output_file_name)
      puts "File already exists!"
      exit 1
    end
  end

  def process!
    puts @output_file
    output_file = File.open(@output_file_name,"w")
    output_file.puts "celex_id, author, title, has_text, dircode_1, dircode_2, dircode_3, sentence_1, sentence_2, sentence_3, sentence_rest"

    found_documents     = File.read(@root_dir.join("found.txt")).split("\n").sort
    not_found_documents = File.read(@root_dir.join("not-found.txt")).split("\n").sort

    work_queue = Queue.new
    csv_lines = Queue.new
    error_queue = Queue.new

    while doc = @filter_enumerator.next
      break if doc.nil?
      id = doc.celex_id
      if found_documents.bsearch { |x| id <=> x }
        work_queue.push(id)
      else
        if ! not_found_documents.bsearch { |x| id <=> x }
          puts "Document #{doc.celex_id} has not been scraped yet! (It's neither in found.txt nor not-found.txt)"
          puts "Rerun the scraper with the same filter parameters, to see if anything is missing."
          puts "Alternatively, hack your way around, and add this number to the not-found.txt file"
          exit 1
        end
      end
    end

    found_documents = nil
    not_found_documents = nil

    length = work_queue.size
    processor = Thread.new { process_thread(length, csv_lines, output_file) }

    workers = (1..Processor.get_number_of_cores).map do |worker|
      work_queue.push(nil)
      Thread.new { worker_thread(work_queue, csv_lines, error_queue) }
    end

    workers.each do |worker|
      worker.join
    end

    csv_lines.push(nil)
    processor.join

    if !error_queue.empty?
      msgs = ["#{error_queue.length} item(s) could not be processed!"]
      while !error_queue.empty?
        doc_number, err = error_queue.pop
        msgs.push "- Document #{doc_number} failed because:"
        msgs.push "  " + [err.to_s, err.backtrace].join("\n  ")
      end

      msg = msgs.join("\n")

      error_file_name = File.basename(@output_file_name, ".*") + ".err.txt"
      puts msg
      File.write(error_file_name,msg)
      puts "(this list is also written to file #{error_file_name})"
    end
  end

  private
  def process_thread(found_elements, results_queue, output_file)
    time_predictor = TimePredictor.new(2*Processor.get_number_of_cores)
    time_predictor.size = found_elements
    while csv_line = results_queue.pop
      time_predictor.report_job_time(Time.now)
      output_file.puts(csv_line)
      puts("|%s| %.2f%% - done: %d, todo: %d " % [
        time_predictor.predict_time_left_str,
        time_predictor.percentage_completed,
        time_predictor.processed,
        time_predictor.work_remaining])
    end
  end

  def worker_thread(work_queue, result_queue, error_queue)
    Thread.current.abort_on_exception = true

    while celex_id = work_queue.pop
      doc = PotentialDoc.from_celex_id(celex_id)
      path = @root_dir.join("html").join(celex_id + ".html")

      if !File.exists? path
        $stderr.puts "HTML for document #{celex_id} has not been found!"
        exit 1
      end

      html = File.read(path).force_encoding("UTF-8")
      begin
        document = Parser.parse_output(doc, html)
        result_queue.push document.as_csv_line
      rescue Exception => e
        error_queue.push([celex_id, e])
      end
    end
  end
end
