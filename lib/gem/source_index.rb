class Gem::SourceIndex
  attr_accessor :gems

  def initializer gems=[]
    self.gems = gems
  end

  def gems
    @gems ||= []
  end
end
