class Gem::Specification
  include Comparable

  # We override some of these later
  attr_accessor :authors, :autorequire, :bindir, :date, :default_executable, :dependencies,
    :description, :email, :executables, :extensions, :extra_rdoc_files, :files, :has_rdoc,
    :homepage, :licenses, :name, :platform, :rdoc_options, :require_paths,
    :required_ruby_version, :required_rubygems_version, :requirements, :rubyforge_project,
    :rubygems_version, :specification_version, :summary, :test_files, :version

  def self.from_gem path
    Gem::Tar::Reader.new(File.open(path, 'r')).each do |entry|
      if entry.full_name == "metadata.gz" or entry.full_name == "metadata"
        entry = Zlib::GzipReader.new entry if entry.full_name =~ /\.gz\Z/
        return YAML.load_stream entry
      end
    end
  end

  def self.try_from_gem path
    begin
      from_gem path
    # XXX: YAML throws `SyntaxError`s (eek!)
    rescue Exception
    end
  end

  @@capture = false

  def self.from_gemspec path
    @@capture = true
    load path
    @@capture
  end

  def initialize *args
    options = args.pop if args.last.is_a? Hash
    options ||= {}

    self.name = args.shift
    self.version = args.shift
    self.platform = args.shift

    raise ArgumentError, "Too many arguments" unless args.empty?

    options.each do |key, value|
      send "#{key}=", value
    end

    yield self if block_given?

    @@capture = self if @@capture == true
  end

  def name= value
    @basename = nil
    @name = value
  end

  def version
    @version
  end

  def version= value
    value = Gem::Version.new value unless value.nil? or not value.is_a? Gem::Version
    @basename = nil
    @version = value
  end

  def prerelease?
    version.is_a? Version and version.prerelease?
  end

  def platform
    @platform.to_s == "ruby" ? nil : @platform
  end

  def platform= value
    @basename = nil
    @platform = value
  end

  def basename
    @basename ||= [name, version, platform].map(&:to_s).reject(&:empty?).compact.join('-')
  end

  def authors
    @authors ||= []
  end

  def author
    authors.first
  end

  def author= value
    self.authors = [value]
  end

  def licenses
    @licenses ||= []
  end

  def license
    licenses.first
  end

  def license= value
    licenses[0] = value
  end

  def date
    @date ||= Time.utc(today.year, today.month, today.day)
  end

  def rubygems_version
    @rubygems_version ||= Gem::VERSION
  end

  def dependencies
    @dependencies ||= []
  end

  def add_runtime_dependency *dependency
    self.dependencies << dependency
  end

  alias add_dependency add_runtime_dependency

  def add_development_dependency *dependency
    self.dependencies << dependency
  end

  def specification_version
    3
  end

  def <=> other
    [name.to_s, version, platform == "ruby" ? -1 : 1] <=> [other.name.to_s, other.version, other.platform == "ruby" ? -1 : 1]
  end

  def _dump limit=-1
    Marshal.dump [
      # This order is important
      rubygems_version,
      specification_version,
      name,
      version,
      date,
      summary,
      required_ruby_version,
      required_rubygems_version,
      platform,
      dependencies,
      rubyforge_project,
      email,
      authors,
      description,
      homepage,
      has_rdoc,
      platform,
      licenses
    ]
  end

  def self._load data
    marshalled = Marshal.load data

    new.tap do |spec|
      # This order is important
      spec.rubygems_version,
      spec.specification_version,
      spec.name,
      spec.version,
      spec.date,
      spec.summary,
      spec.required_ruby_version,
      spec.required_rubygems_version,
      spec.platform,
      spec.dependencies,
      spec.rubyforge_project,
      spec.email,
      spec.authors,
      spec.description,
      spec.homepage,
      spec.has_rdoc,
      spec.platform,
      spec.licenses = marshalled
    end
  end

  def for_cache
    dup.for_cache!
  end

  def for_cache!
    tap do
      @files = nil
      @test_files = nil
    end
  end
end

