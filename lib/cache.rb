class Cache
  def initialize(location)
    @location = location
    @mutex = Mutex.new
  end

  def cached(key, value = nil)
    path = location.join(key).to_s
    dir = File.dirname(path)

    FileUtils.mkdir_p(dir)

    @cache_mutex.synchronize do
      if File.exists?(path)
        Marshal.load(File.read(path))
      else
        value = if block_given?
                  yield
                else
                  value
                end
        File.write(path,Marshal.dump(value))
        value
      end
    end
  end
end
