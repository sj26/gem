class Gem::Requirement
  attr_accessor :none, :requirements

  def initialize requirements=nil
    self.requirements = requirements
  end
end

Gem::Version::Requirement = Gem::Requirement
