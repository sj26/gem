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
   * `<platform>`: gem platform, omitted if platform is "ruby", the default

Proposed directory structure:

 * `metadata.index` — newline separated list of all names, append only.
 * `metadata/` — index of gems.
   * `<name>.index` — newline separated list of all basenames for a name, append only.
   * `<name>/` -
     * `<version>[-<platform>].json` – metadata for the gemball.
 * `source.json` — metadata about this source. May contain canonical URL.
 * `sources/` — cached source indexes.
   * `<source-sha>/` — SHA of canonical source URL (i.e. `http://rubygems.org`)
     * `source.json` — metadata about the source.
     * `metadata.index/` — a cache of the top-level metadata.index for the source
     * `metadata/` — a cache of the top-level metadata/ for the source
 * `gems/` — gemballs and unpacked trees.
   * `<basename>.gem` — the gemball.
   * `<basename>/` — the unpacked gem tree. Optional if it allows zip loading.

Use net/http/persistent per-source for gem operations like rubygems-mirror, respecting HTTP content-type, transport-encoding (compression), range and freshness controls, and negating overhead of many small files.

Multiplex mirroring and potentially other operations over a pool of threads like rubygems-mirror.

Break old marshalling support into modules, only include them when backwards-compatible behaviour required (i.e. during upgrade, when compat is requested/configured).

Add more checks and guards to make sure the index/gemspecs/gems can't get into an invalid state.

## License

MIT (see LICENSE). Some parts adapted from Rubygems, which is under the Ruby or MIT license.
