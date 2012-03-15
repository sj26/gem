class Gem::SourceIndex
  attr_accessor :gems

  def gems
    @gems ||= []
  end
end

