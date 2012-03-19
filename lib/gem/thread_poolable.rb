require 'thread'

class ThreadPool
  def initialize size=4
    @size = size
    @queue = SizedQueue.new 1
    @queue_mutex = Mutex.new
    @threads = @size.times.map { Thread.new &method(:worker) }
  end

  def enqueue *arguments, &work
    @queue_mutex.synchronize do
      @queue << [work, *arguments]
    end
  end

  def join
    @queue_mutex.synchronize do
      @queue << nil
      @threads.each do |thread|
        thread[:mutex].synchronize do
          thread.kill
        end
      end
    end
  end

private

  def worker
    mutex = Thread.current[:mutex] = Mutex.new
    loop do
      if work = @queue.shift
        mutex.synchronize do
          work.shift.call *work
        end
      end
    end
  end
end

module ThreadPoolable
  def in_thread_pool size=4, &block
    size = size[:of] if size.is_a? Hash
    pool = ThreadPool.new size
    each do |*args|
      pool.enqueue *args, &block
    end
    pool.join
  end

  def in_threads &block
    map do |*args|
      Thread.new *args, &block
    end.each(&:join)
  end
end

Enumerator.send :include, ThreadPoolable
