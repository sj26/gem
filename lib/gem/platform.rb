class Gem::Platform
  RUBY = 'ruby'

  attr_accessor :cpu, :os, :version

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
