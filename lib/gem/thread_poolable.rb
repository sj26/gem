require 'thread'

class ThreadPool
  def initialize size=4
    @size = size
    @queue = SizedQueue.new 1
    @threads = @size.times.map { Thread.new &method(:worker) }
  end

  def enqueue *arguments, &work
    @queue << [work, arguments]
  end

  def join
    @queue << nil
    @threads.each do |thread|
      thread[:mutex].synchronize do
        thread.kill
      end
    end
  end

private

  def worker
    mutex = Thread.current[:mutex] = Mutex.new
    loop do
      mutex.synchronize do
        if work = @queue.shift
          work.shift.call *work
        end
      end
    end
  end
end

module Enumerable
  def in_thread_pool size=4, &block
    to_enum.in_thread_pool size, &block
  end

  def in_threads &block
    to_enum.in_threads &block
  end
end

class Enumerator
  def in_thread_pool size=4, &block
    size = size[:of] if size.is_a? Hash
    pool = ThreadPool.new size
    each do |*args|
      pool.enqueue { block.call *args }
    end
    pool.join
  end

  def in_threads &block
    map do |*args|
      Thread.new *args, &block
    end.each(&:join)
  end
end
