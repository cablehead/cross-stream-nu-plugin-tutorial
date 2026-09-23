# Getting the query plugin onto this host, and running a command with it.
#
# The handler can't load a plugin into its own engine, so it runs a separate
# `nu`, the way a reader would at their terminal. The plugin binary and the
# registry file live in the site's state dir, which survives deploys.

export const NU_VERSION = "0.113.1"
const TARBALL = $"nu-($NU_VERSION)-x86_64-unknown-linux-musl"
const URL = $"https://github.com/nushell/nushell/releases/download/($NU_VERSION)/($TARBALL).tar.gz"

def state []: nothing -> path { $env.CROSS_STREAM_SITE_STATE }
def plugin-bin []: nothing -> path { state | path join nu_plugin_query }
def registry []: nothing -> path { state | path join plugins.msgpackz }

# Download the plugin from the Nushell release and register it. Skipped when
# the registry already exists.
export def install [] {
  if (registry | path exists) { return }
  let tar = state | path join $"($TARBALL).tar.gz"
  http get $URL | save --force $tar
  ^tar -xzf $tar -C (state) $"($TARBALL)/nu_plugin_query" --strip-components 1
  rm $tar
  ^chmod +x (plugin-bin)
  ^nu --no-config-file -c $"plugin add --plugin-config (registry) (plugin-bin)"
}

# Defined inside the fresh `nu` so scripts can end with it: a list printed
# as nuon with one entry per line, which reads better than nested tables.
const PRELUDE = r#'
def one-per-line []: any -> string {
  let rows = $in | each { to nuon }
  if ($rows | is-empty) { "[]" } else { "[\n  " + ($rows | str join ",\n  ") + "\n]" }
}
'#

# Run a nushell script in a fresh `nu` with the plugin loaded. Returns
# {ok, out, err}.
export def run [script: string, --timeout: duration = 20sec]: nothing -> record {
  let seconds = $timeout | into int | $in / 1_000_000_000 | into string
  let r = ^timeout $seconds nu --no-config-file -c $"plugin use --plugin-config (registry) query; ($PRELUDE); ($script)" | complete
  { ok: ($r.exit_code == 0), out: $r.stdout, err: $r.stderr, exit_code: $r.exit_code }
}
