module Kernel
private
  def require_with_gem path
    puts "Found:", Dir[Gem.path + "/gems/*/lib/" + path].inspect
    require_without_gem path
  end

  alias require_without_gem require

public
  alias require require_with_gem
end
