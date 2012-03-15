class Gem::Version
  include Comparable

  attr_reader :version

  def initialize version=nil
    self.version = version
  end

  def version= value
    @segments = @prelease = nil
    @version = value
  end

  def segments
    @segments ||= version.to_s.split('.')
  end

  def prerelease?
    @prerelease ||= @version =~ /[a-zA-Z]/
  end

  def <=> other
    return unless self.class === other
    return 0 if version == other.version

    lhsegments = segments
    rhsegments = other.segments

    lhsize = lhsegments.size
    rhsize = rhsegments.size
    limit  = (lhsize > rhsize ? lhsize : rhsize) - 1

    i = 0

    while i <= limit
      lhs, rhs = lhsegments[i] || 0, rhsegments[i] || 0
      i += 1

      next      if lhs == rhs
      return -1 if String  === lhs && Numeric === rhs
      return  1 if Numeric === lhs && String  === rhs

      return lhs <=> rhs
    end

    return 0
  end

  def marshal_dump
    [version]
  end

  def marshal_load args
    self.version = args.first
  end

  def empty?
    version.nil? or version.empty?
  end

  def to_s
    version
  end

  def inspect
    "<Gem::Version #{to_s.inspect}>"
  end

  def to_yaml
    [:@version]
  end
end
