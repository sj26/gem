# Gem

Just enough not-Rubygems to index a collection of gems for download... and maybe more.

There are some severe caveats. Some are by design, others will be addressed later.

Created by [Samuel Cochran](http://sj26.com) for [Railscamp X](http://railscamps.com).

## Thoughts

Rubygems is a bit... horrible. It was a good fit for the problem it solved for a long time, but we've outgrown it. Here are a list of my thoughts on what's wrong and how we could fix it. Many of these ideas are or will permeate this `gem` gem as a (mostly backwards-compatible) drop-in replacement for rubygems.

Local index should be more granular and allow stream processing. Same with specs lists. Marshalling and constantly re-downloading a whole index, or even just a list of specs, is ludicrous at current sizes.

Break index up into more files for efficient lookup?

Learn from PIP, have quick lookups for common cases.

JSON is a better choice than YAML—it's just plain faster and becoming ubiquitous. Built-in (usually reasonably fast) support in 1.9, including streaming, which is cross-platform friendly (much moreso than YAML).

Auto-negotiated transport compression should counteract any size difference and work for partial updates.

Compression is purely a transport/storage concern.

Index journal for efficient partial updates via HTTP.

Use plain old HTTP (but the full functionality of 1.1) and static files to allow serving at edges by cloudfront, easy proxying/caching, etc.

Same directory structure and index format locally and remotely, backwards compatible:

Given the following definitions:

 * `<basename>`: `<name>-<version>[-<platform>]`
   * `<name>`: gem name, i.e. "rails"
   * `<version>`: gem version, i.e. "3.2.2"
   * `<platform>`: gem platform, omittted if platform is "ruby", the default

Proposed directory structure:

 * `cache/` -> `gems/` — a symlink for old gemball location, backwards compat only.
 * `index/` — index of gemspecs.
   * All gemspec indexes are stored as simple tuples, `[[<name>, <version>, <platform>[, <yanked?>]]+]`
     * Journalled (append-only).
     * Yanked gems add another entry with <yanked?> set to true.
   * `specs.json[.gz]` — index of all (non-prerelease) gemspecs
   * `latest_specs.json[.gz]` — index of latest (non-prerelease) gemspec
   * `prerelease_specs.json[.gz] — index of all (non-prerelease) gemspecs ([[name, version, platform]*]), journalled.
   * `<name>/` — gem name specific indexes
     * `specs.json[.gz]` — index of gemspecs for a gem name (for complex requirement resolution)
     * `latest_specs.json[.gz]` — latest gemspec for each platform for a gem name (`gem install <name>`)
     * `prerelease_specs.json[.gz]` — latest prerelease gemspec for each platform for a gem name (`gem install —prerelease <name>`)
     * eventually, we might need to replicate by version segment for targeted requirements if it would provide efficiency gains — gems with many semantic versions, etc:
       `version-<version-prefix>/{specs,latest_specs,prerelease_specs}.json.gz`
     * could also introduce something for platform, ala:
       `version-<version-prefix>/]platform-<platform>/`
 * `sources/` — cached source indexes
   * `<source-sha>/` — SHA of source URL (i.e. `http://rubygems.org`)
     * `index/` — a cache of the top-level index/ for a particular source
 * `gems/` — installed gems, backwards compatible.
   * `<basename>.gem` — the gem ball
   * `<basename>/` — the unpacked gem tree
 * `specifications/` — gem specifications of installed gems, backwards compatible.
   * `<basename>.gemspec` — ruby format, without file/test lists

Use net/http/persistent per-source for gem operations like rubygems-mirror, respecting HTTP content-type, transport-encoding (compression), range and freshness controls, and negating overhead of many small files.

Multiplex mirroring and potentially other operations over a pool of threads like rubygems-mirror.

Break old marshalling support into modules, only include them when backwards-compatible behaviour required (i.e. during upgrade, when compat is requested/configured).

Add more checks and guards to make sure the index/gemspecs/gems can't get into an invalid state.

## License

MIT (see LICENSE). Some parts adapted from Rubygems, which is under the Ruby or MIT license.
