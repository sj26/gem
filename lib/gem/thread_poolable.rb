require 'thread'

module Gem::ThreadPoolable
  def in_thread_pool size=4
    to_enum.in_thread_pool size
  end
end

module Gem::ThreadPooler
  def in_thread_pool size=4
    size = size[:of] if size.is_a? Hash
    queue = SizedQueue.new size
    processor = proc { yield *queue.shift rescue nil until queue.empty? }
    pool = size.times.map { Thread.start &processor }
    each do |*yielded|
      queue.push yielded
    end
    each(&:join)
  end
end

Enumerable.send :extend, Gem::ThreadPoolable
Enumerator.send :include, Gem::ThreadPooler
