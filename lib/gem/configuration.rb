module Gem::Configuration
  def sources
    @sources ||= %w(http://rubygems.org)
  end

  def sources= value
    @sources = value
  end

  def source
    sources.first
  end

  def source= value
    self.sources = [value]
  end

  def ruby_engine
    if defined? RUBY_ENGINE then
      RUBY_ENGINE
    else
      'ruby'
    end
  end

  def path
    @path ||= begin
      File.join *if defined? RUBY_FRAMEWORK_VERSION
        [File.dirname(RbConfig::CONFIG["sitedir"]), 'Gems', RbConfig::CONFIG["ruby_version"]]
      elsif RbConfig::CONFIG["rubylibprefix"] then
        [RbConfig::CONFIG["rubylibprefix"], 'gems', RbConfig::CONFIG["ruby_version"]]
      else
        [RbConfig::CONFIG["libdir"], ruby_engine, 'gems', RbConfig::CONFIG["ruby_version"]]
      end
    end
  end

  def marshal_version
    "#{Marshal::MAJOR_VERSION}.#{Marshal::MINOR_VERSION}"
  end
end

Gem.extend Gem::Configuration
