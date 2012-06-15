class Gem::Version
  include Comparable

  attr_reader :version

  def initialize version=nil
    self.version = version
  end

  def version= value
    @segments = @prerelease = nil
    @version = value
  end

  def segments
    @segments ||= version.to_s.split('.').map {|piece|
      piece[/^\d+$/] ? piece.to_i : piece
    }
  end

  def prerelease?
    @prerelease ||= @version =~ /[a-zA-Z]/
  end

  def <=> other
    return unless self.class === other
    return 0 if version == other.version

    max_length = [segments.length, other.segments.length].max
    (0...max_length).to_a.each {|index|
      result = compare_pieces segments[index], other.segments[index]
      return result unless result == 0
    }

    0
  end

  def compare_pieces this, that
    if this.is_a?(String) ^ that.is_a?(String)
      this.is_a?(String) ? -1 : 1
    else
      (this || 0) <=> (that || 0)
    end
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
    version.to_s
  end

  def inspect
    "<Gem::Version #{to_s.inspect}>"
  end

  def to_yaml_properties
    [:@version]
  end
end
