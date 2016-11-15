require 'time'

class Scraper
  def self.scrape!(year, letters, numbers)
    Scraper.new(year, letters, numbers).scrape
  end

  def initialize(year, letters, numbers)
    context_dir = Pathname.new(File.join("data", year.to_s))
    FileUtils.mkdir_p(context_dir)

    not_found_file_path = context_dir.join("not-found.txt")

    if File.exists?(not_found_file_path)
      @not_founds = File.read(not_found_file_path).split("\n").sort
    else
      @not_founds = []
    end
    @not_found_file = File.open(not_found_file_path, "a")

    found_file_path = context_dir.join("found.txt")
    if File.exists?(found_file_path)
      @founds = File.read(found_file_path).split("\n").sort
    else
      @founds = []
    end
    @found_file = File.open(found_file_path, "a")

    @html_dir = context_dir.join("html")
    FileUtils.mkdir_p(@html_dir)

    @work_queue = WorkQueue.new(year, letters, numbers)
    @size = letters.length * ((numbers.end-numbers.begin) + 1)

    # Info of pages that have been processed are pushed to this queue.
    # Once no more jobs are present, 'false' is pushed to it, so that
    # the log output thing can quit as well.
    @processed_queue = Queue.new
  end

  def scrape
    # Start several worker threads
    worker_threads = (1..NR_THREADS).map { |i| Thread.new { worker_thread(i) } }
    log_thread = Thread.new { print_progress }

    worker_threads.map {|wt| wt.join }
    @processed_queue.push(false)
    log_thread.join

    @found_file.sync
    @not_found_file.sync
    @found_file.close
    @not_found_file.close
  end

  private

  def print_progress
    Thread.current.abort_on_exception=true
    processed = 0

    # Predict times, based on the last 3 * NR_THREADS samples.
    time_predictor = TimePredictor.new(3 * NR_THREADS)
    time_predictor.size = @size
    while (result = @processed_queue.pop)
      state, worker_nr, potential_doc = result

      if state == :found
        @found_file.puts potential_doc.celex_id
      end

      if state == :not_found
        @not_found_file.puts potential_doc.celex_id
      end

      made_progress, message = case state
        when :found            then [true,"found"]
        when :found_cached     then [true,"found (from found.txt)"]
        when :not_found        then [true,"not found"]
        when :not_found_cached then [true,"not found (from not-found.txt)"]
        when :timeout_retry    then [false,"timed out at attempt %d! Will retry at %s" % [potential_doc.attempts, potential_doc.retry_at.rfc2822]]
        when :timeout_nope     then [true,"timed out too many times. Skipping"]
        when :exception_retry  then [false,"something bad happened at attempt %d! Will retry at %s" % [potential_doc.attempts, potential_doc.retry_at.rfc2822]]
        when :exception_nope   then [true,"something bad happened too many times. Skipping. #{potential_doc.inspect}"]
      end

      time_predictor.report_job_time(Time.now, made_progress)


      puts("|%s| %.2f%% - done: %d, todo: %d - [worker %02d] %s %s" % [
        time_predictor.predict_time_left_str,
        time_predictor.percentage_completed,
        time_predictor.processed,
        time_predictor.work_remaining,
        worker_nr,
        potential_doc.celex_id,
        message])
    end
  end

  def worker_thread(index)
    Thread.current.abort_on_exception = true
    while (potential_doc = @work_queue.next)

      # check if it's in the not_found.txt file
      celex_id = potential_doc.celex_id

      if @not_founds.bsearch { |x| celex_id <=> x }
        @processed_queue.push [:not_found_cached, index, potential_doc]
        next
      end

      if @founds.bsearch { |x| celex_id <=> x }
        @processed_queue.push [:found_cached, index, potential_doc]
        next
      end

      begin
        # Attempt to fetch the HTML page, within a timeout.
        state, html = Timeout.timeout(FETCH_PAGE_TIMEOUT_IN_SEC) do
          DocFetcher.fetch(potential_doc)
        end

        # If we have a success, write the HTML file out to disk.
        # Otherwise, write it to the "not_found.txt" file
        if state == :found
          File.write(@html_dir.join(potential_doc.celex_id+".html"), html)
        end

        # state can be either :found or :not_found, delegate writing to files to log thread
        @processed_queue.push [state, index, potential_doc]
      rescue Timeout::Error
        if potential_doc.attempts < MAX_TIMEOUT_ATTEMPTS
          potential_doc = potential_doc.dup # Duplicate to prevent races with printing.
          potential_doc.attempts += 1
          potential_doc.retry_at = Time.now + TIMEOUT_INTERVAL_RETRY
          @work_queue.schedule_retry potential_doc
          @processed_queue.push [:timeout_retry, index, potential_doc]
        else
          @processed_queue.push [:timeout_nope, index, potential_doc]
        end
        next
      rescue Exception => e
        puts e.inspect
        puts e.backtrace
        if potential_doc.attempts < MAX_EXCEPTION_ATTEMPTS
          potential_doc = potential_doc.dup # Duplicate to prevent races with printing.
          potential_doc.attempts += 1
          potential_doc.retry_at = Time.now + TIMEOUT_INTERVAL_EXCEPTION
          @work_queue.schedule_retry potential_doc
          @processed_queue.push [:exception_retry, index, potential_doc]
        else
          @processed_queue.push [:exception_nope, index, potential_doc]
        end
      end
    end
  end
end
