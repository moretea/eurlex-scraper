class WorkQueue
  def initialize year, letters, numbers_range
    @mutex = Mutex.new
    @retries = [] # Docs that should be retries. Sorted on when they should be retried;
                  # first to be retried is first element in the list.
    @enumerator = WorkQueue.build_enumerator(year, letters, numbers_range)
  end

  # Returns PotentialDocs, until all all options in the cartesian product letters # numbers
  # have been generated. This stream is intermixed with retries, that should fire at a specific time.
  # Once all options in the cartesian product and retries have been exhausted, will return an
  # infinite stream of nil's.
  def next
    @mutex.synchronize do
      # First attempt to see if any retries are available and should be triggered now.
      if @retries.any? && @retries.first.retry_at < Time.now
        return @retries.pop
      end

      # No? Fine, let's generate some work.
      begin
        return @enumerator.next
      rescue StopIteration
        # Just catch the StopIteration; no more new work
      end

      # See if there is anything else we can do
      if @retries.empty?
        # Nope, no retries!
        return nil
      else
        # Yes, some retries!
        some_retry = @retries.pop

        # Really sleep until the first attempt is done.
        while Time.now < some_retry.retry_at
          time_to_sleep = Time.now - some_retry.retry_at
          if time_to_sleep > 0
            sleep time_to_sleep
          end
        end

        return some_retry
      end
    end
  end

  # Schedule a potential doc for some later retry.
  def schedule_retry potential_doc
    @mutex.synchronize do
      @retries.push potential_doc.dup

      # Lazy solution to keep the invariant that  the first doc that should be retried is
      # in the first element of the list.
      @retries.sort_by { potential_doc.retry_at }
    end

    nil
  end

  # Generate the cartisian product letters # numbers
  def self.build_enumerator(year, letters, numbers)
    Enumerator.new do |yielder|
      letters.each do |letter|
        numbers.each do |number|
          yielder << PotentialDoc.new(year, letter, number, nil, 0)
        end
      end
    end
  end
end
