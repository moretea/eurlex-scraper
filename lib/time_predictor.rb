class TimePredictor
  attr_accessor :size
  attr_accessor :processed

  def initialize(history_size)
    @history_size = history_size
    @history = []
    @size = 0
    @processed = 0
  end

  def report_job_time time, made_progress = true
    @history.push(time)

    while @history.length > @history_size
      @history.shift
    end

    if made_progress
      @processed += 1
    end
  end

  # Returns the number of things that need to be done.
  def work_remaining
    @size - @processed
  end

  # Predicts how many seconds left
  def predict_time_left
   [1, compute_avg_time(@history) * work_remaining].max
  end

  def predict_time_left_str
    duration_str(predict_time_left)
  end

  def percentage_completed
    if processed == 0 && size == 0
      return 0
    end

    [0, (processed.to_f) / @size.to_f* 100].max
  end

  private
  def compute_avg_time(history)
    history = history.dup
    prev_time = history.shift
    data_points = []

    while history.any?
      current_time = history.shift
      diff = current_time - prev_time
      prev_time = current_time
      data_points.push diff
    end

    if data_points.length == 0
      0
    else
      data_points.inject(&:+) / data_points.length
    end
  end

  def duration_str(time_left)
    rest, seconds = time_left.divmod(60)
    rest, minutes = rest.divmod(60)
    days, hours = rest.divmod(24)

    result = []
    result.push("#{days}d")
    result.push("%02dh" % hours)
    result.push("%02dm" % minutes)
    result.push("%02ds" % seconds)
    result.join("")
  end
end
