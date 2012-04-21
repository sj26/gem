require 'fileutils'
require 'net/http/persistent'
require 'rbconfig'
require 'time'
require 'yaml'
require 'zlib'

module Gem
  VERSION = '1.8.11'.freeze

  # XXX: Find methods not implemented yet
  def self.method_missing symbol, *args
    # XXX: WHUT, why doesn't "[athing]"[1, -1] not give "athing"? Grr.
    puts "TODO: #{name}.#{symbol}(#{args.inspect.tap { |s| s.slice!(0, 1); s.slice!(-1) } })"
  end

  def self.[] name, version=nil, platform=nil
    name.gsub! /\.gem\Z/, ""
    if version.nil?
      versions = Dir[File.join(path, "cache", "#{name}-*.gem")].map do |filename|
        File.basename(filename)
      end.map do |basename|
        basename.slice(name.length + 1, basename.length - name.length - 1 - 4)
      end.map do |version|
        Version.new version
      end.reject(&:prerelease?).sort
      version = versions.last.to_s unless versions.empty?
    end

    specification = Specification.new name, version, platform
    filename = File.join path, "cache", "#{specification.basename}.gem"

    Specification.from_gem filename
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
          if specification = self[name].for_cache!
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
    end, Zlib::GzipWriter.new(File.open("specs.#{marshal_version}.gz", "w")))
    puts "done."

    print "Writing lastest_specs... "
    Marshal.dump(all.gems.group_by(&:name).map do |name, specifications|
      specification = specifications.reject(&:prerelease?).last
      platform = specification.platform
      platform = "ruby" if platform.nil? or platform.empty?
      [specification.name, specification.version, platform]
    end, Zlib::GzipWriter.new(File.open("latest_specs.#{marshal_version}.gz", "w")))
    puts "done."

    print "Writing prerelease_specs... "
    Marshal.dump(all.gems.select(&:prerelease?).map do |specification|
      platform = specification.platform
      platform = "ruby" if platform.nil? or platform.empty?
      [specification.name, specification.version, platform]
    end, Zlib::GzipWriter.new(File.open("prerelease_specs.#{marshal_version}.gz", "w")))
    puts "done."

    # TODO: index.rss
  end

  def self.mirror source=source
    http = Net::HTTP::Persistent.new "gem-mirror"
    print "#{File.exist? "specs.#{marshal_version}.gz" and "Updating" or "Fetching"} specifications... "
    ["specs", "latest_specs", "prerelease_specs"].each.in_threads do |specs_name|
      path = "#{specs_name}.#{marshal_version}.gz"
      uri = URI "#{source}/#{specs_name}.#{marshal_version}.gz"
      headers = {}
      headers['If-Modified-Since'] = File.mtime(path).rfc2822 if File.exist? path
      catch :done do
        loop do
          request = Net::HTTP::Get.new uri.path, headers
          http.request(uri, request) do |response|
            puts response.inspect
            if response.code == "304"
              # Nothing to do, we already have latest version
              throw :done
            elsif response.code[0] == "3" and response["Location"]
              # Redirect
              url = URI.join uri.to_s, response["Location"]
            elsif response.code == "206"
              File.open(path, 'a') do |file|
                response.read_body do |chunk|
                  file.write chunk
                end
              end
            elsif response.code == "200"
              File.open(path, 'w') do |file|
                response.read_body do |chunk|
                  file.write chunk
                end
              end
              last_modified = Time.parse response['Last-Modified']
              File.utime last_modified, last_modified, path
              throw :done
            else
              raise StandardError, "Unknown response: #{response.inspect}"
            end
          end
        end
      end
    end
    puts "done."
    FileUtils.mkdir_p "gems"
    progress = nil
    ["latest_specs", "specs", "prerelease_specs"].each do |specs_name|
      Marshal.load(IO.popen("gunzip -c #{specs_name}.#{marshal_version}.gz", "r", err: nil)).tap do |tuples|
        progress = ProgressBar.new("Mirroring #{specs_name.gsub('_', ' ')}", tuples.length)
      end.each.in_thread_pool(of: 8) do |tuple|
        name, version, platform = tuple
        begin
          specification = Specification.new name: name, version: version, platform: platform
          path = "gems/#{specification.basename}.gem"
          unless File.exist? path and Specification.try_from_gem(path)
            uri = URI "#{source}/#{path}"
            headers = {}
            headers["Range"] = "bytes=#{File.size(path)}-" if File.exist? path
            catch :done do
              loop do
                request = Net::HTTP::Get.new uri.path, headers
                http.request uri, request do |response|
                  puts response.inspect
                  if response.code == "304"
                    # Nothing to do, we already have latest version
                    throw :done
                  elsif response.code[0] == "3" and response["Location"]
                    # Redirect
                    url = URI.join uri.to_s, response["Location"]
                  elsif response.code == "200" or response.code == "206"
                    # TODO: Check range properly
                    File.open(path, response.code == '206' ? 'a' : 'w') do |file|
                      response.read_body do |chunk|
                        file.write chunk
                      end
                    end
                    last_modified = Time.parse response['Last-Modified']
                    File.utime last_modified, last_modified, path
                    throw :done
                  else
                    raise StandardError, "Unknown response: #{response.inspect}"
                  end
                end
              end
            end
            progress.puts specification.basename
          end
        rescue StandardError
          progress.puts "Failed to mirror gem #{name.inspect}: #{$!}", $!.inspect, $!.backtrace
        end
        progress.inc
      end
      progress.finish
    end
    puts "#{`/bin/ls -1f | wc -l`.to_i - 2} gems mirrored."
    index
  end

protected

  def self.shellescape arg
    if not arg.is_a? String
      arg.to_s
    else
      arg.dup
    end.tap do |arg|
      # Process as a single byte sequence because not all shell
      # implementations are multibyte aware.
      arg.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")

      # A LF cannot be escaped with a backslash because a backslash + LF
      # combo is regarded as line continuation and simply ignored.
      arg.gsub!(/\n/, "'\n'")
    end
  end
end

require 'gem/tar'
require 'gem/thread_poolable'

require 'gem/configuration'
require 'gem/version'
require 'gem/requirement'
require 'gem/dependency'
require 'gem/platform'
require 'gem/specification'
require 'gem/progressbar'

require 'gem/require'
