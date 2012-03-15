require 'yaml'
require 'zlib'
require 'fileutils'

class String
  def presence
    empty? ? nil : self
  end
end

module Gem
  VERSION = '1.8.11'.freeze

  class Version
    attr_accessor :version, :prerelease

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
      @version = args.first
    end

    def to_yaml_properties
      [:@version]
    end
  end

  class Requirement
    attr_accessor :none, :requirements
  end

  Version::Requirement = Requirement

  class Dependency
  end

  class Platform
    RUBY = 'ruby'

    attr_accessor :cpu
    attr_accessor :os
    attr_accessor :version

    def initialize arch
      case arch
      when Array then
        @cpu, @os, @version = arch
      when String then
        arch = arch.split '-'

        if arch.length > 2 and arch.last !~ /\d/ then # reassemble x86-linux-gnu
          extra = arch.pop
          arch.last << "-#{extra}"
        end

        cpu = arch.shift

        @cpu = case cpu
           when /i\d86/ then 'x86'
           else cpu
         end

        if arch.length == 2 and arch.last =~ /^\d+(\.\d+)?$/ then # for command-line
          @os, @version = arch
          return
        end

        os, = arch
        @cpu, os = nil, cpu if os.nil? # legacy jruby

        @os, @version = case os
          when /aix(\d+)/ then             ['aix',       $1 ]
          when /cygwin/ then               ['cygwin',    nil]
          when /darwin(\d+)?/ then         ['darwin',    $1 ]
          when /freebsd(\d+)/ then         ['freebsd',   $1 ]
          when /hpux(\d+)/ then            ['hpux',      $1 ]
          when /^java$/, /^jruby$/ then    ['java',      nil]
          when /^java([\d.]*)/ then        ['java',      $1 ]
          when /^dotnet$/ then             ['dotnet',    nil]
          when /^dotnet([\d.]*)/ then      ['dotnet',    $1 ]
          when /linux/ then                ['linux',     $1 ]
          when /mingw32/ then              ['mingw32',   nil]
          when /(mswin\d+)(\_(\d+))?/ then
            os, version = $1, $3
            @cpu = 'x86' if @cpu.nil? and os =~ /32$/
            [os, version]
          when /netbsdelf/ then            ['netbsdelf', nil]
          when /openbsd(\d+\.\d+)/ then    ['openbsd',   $1 ]
          when /solaris(\d+\.\d+)/ then    ['solaris',   $1 ]
          # test
          when /^(\w+_platform)(\d+)/ then [$1,          $2 ]
          else                             ['unknown',   nil]
        end
      when Gem::Platform then
        @cpu = arch.cpu
        @os = arch.os
        @version = arch.version
      else
        raise ArgumentError, "invalid argument #{arch.inspect}"
      end
    end

    def to_a
      [@cpu, @os, @version]
    end

    def to_s
      to_a.compact.join '-'
    end

    def empty?
      to_s.empty?
    end
  end

  class Specification
    attr_accessor :authors, :autorequire, :bindir, :default_executable, :dependencies,
      :description, :email, :executables, :extensions, :extra_rdoc_files, :files,
      :has_rdoc, :homepage, :licenses, :name, :platform, :rdoc_options, :require_paths,
      :required_ruby_version, :required_rubygems_version, :requirements,
      :rubyforge_project, :rubygems_version, :summary, :test_files, :version

    def initialize *args
      options = args.pop if args.last.is_a? Hash
      options ||= {}

      self.name = args.shift if args.first.is_a? String
      self.version = args.shift if args.first.is_a? String or args.first.is_a? Gem::Version

      raise ArgumentError, "Too many arguments" unless args.empty?

      options.each do |key, value|
        send "#{key}=", value
      end
    end

    def prerelease?
      version.is_a? Version and version.prerelease?
    end

    def platform
      @platform.to_s == "ruby" ? nil : @platform
    end

    def basename
      @basename ||= [name.to_s, version.version, platform.to_s.presence].compact.join '-'
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

  class SourceIndex
    attr_accessor :gems

    def gems
      @gems ||= []
    end
  end

  def self.marshal_version
    "#{Marshal::MAJOR_VERSION}.#{Marshal::MINOR_VERSION}"
  end

  def self.[] name
    name += ".gem" unless name[/.gem\Z/]
    yaml = `tar -Oxf gems/#{name} metadata.gz | gunzip`
    if not yaml.empty? and specification = YAML.load(yaml + "\n")
      specification.for_cache!
    end
  end

  def self.all
    # If we have an index, run the block if given
    @index.gems.each(&proc) if block_given? and @index

    # Otherwise build the index and run the block for each built spec
    @index ||= SourceIndex.new.tap do |index|
      progress = nil
      Dir.foreach("gems").select do |path|
        path =~ /\.gem\Z/
      end.tap do |names|
        progress = ProgressBar.new("Loading index", names.length)
      end.each do |name|
        begin
          if specification = self[name]
            index.gems << specification
            yield specification if block_given?
          end
        rescue StandardError
          puts "Failed to load gem #{name.inspect}: #{$!}", $!.inspect, $!.backtrace
        end
        progress.inc
      end
      progress.finish
      puts "#{index.gems.length} gems loaded into index"
      index.gems.sort!
    end
  end

  def self.quick_index specification
    File.write("quick/#{specification.basename}.gemspec.rz", Zlib.deflate(YAML.dump(specification)))
    File.write("quick/Marshal.#{marshal_version}/#{specification.basename}.gemspec.rz", Zlib.deflate(Marshal.dump(specification)))
  end

  def self.index
    FileUtils.mkdir_p "quick/Marshal.#{marshal_version}"

    all(&method(:quick_index))

    print "Marshal index... "
    File.write("Marshal.#{marshal_version}.Z", Zlib.deflate(Marshal.dump(all.gems.map { |spec| [spec.basename, spec] })))
    puts "done."

    # deprecated: Marshal.dump(all, File.open("Marshal.#{marshal_version}", "w"))

    # deprecated:
    #puts "Quick index"
    #File.open('quick/index', 'w') do |quick_index|
    #  all.gems.each do |specification|
    #    quick_index.write("#{specification.name.to_s}-#{specification.version.version}\n")
    #  end
    #end

    # deprecated:
    #puts "Master index"
    #YAML.dump(all, File.open("yaml", "w"))
    #File.write("yaml.Z", Zlib.deflate(File.read("yaml")))

    # un-gzipped indexes are deprecated, so generate gzipped directly:

    print "Writing specs... "
    Marshal.dump(all.gems.reject(&:prerelease?).map do |specification|
      platform = specification.platform
      platform = "ruby" if platform.nil? or platform.empty?
      [specification.name, specification.version, platform]
    end, IO.popen("gzip -c > specs.#{marshal_version}.gz", "w", err: nil))
    puts "done."

    print "Writing lastest_specs... "
    Marshal.dump(all.gems.group_by(&:name).map do |name, specifications|
      specification = specifications.reject(&:prerelease?).last
      platform = specification.platform
      platform = "ruby" if platform.nil? or platform.empty?
      [specification.name, specification.version, platform]
    end, IO.popen("gzip -c > latest_specs.#{marshal_version}.gz", "w", err: nil))
    puts "done."

    print "Writing prerelease_specs... "
    Marshal.dump(all.gems.select(&:prerelease?).map do |specification|
      platform = specification.platform
      platform = "ruby" if platform.nil? or platform.empty?
      [specification.name, specification.version, platform]
    end, IO.popen("gzip -c > prerelease_specs.#{marshal_version}.gz", "w", err: nil))
    puts "done."

    # TODO: index.rss
  end
end

require 'gem/progressbar'
