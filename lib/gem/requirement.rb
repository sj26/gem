class Gem::Requirement
  attr_accessor :none, :requirements

  def initialize requirements=nil
    self.requirements = requirements
  end

  def marshal_dump
    [@requirements]
  end

  def marshal_load array
    @requirements = array.first
  end
end

Gem::Version::Requirement = Gem::Requirement
