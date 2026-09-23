# Running the query plugin from this site.
#
# The plugin binary is committed to the repo, built for the nu on a
# cross.stream host (see NU_VERSION). Two things happen around it:
#
# - At startup, `plugin add` registers it into a registry file. The registry
#   records the binary's absolute path, which differs per checkout, so it is
#   made here rather than committed. Registering takes about 20ms.
# - Per request, `run` starts a fresh `nu` with the plugin loaded. The handler
#   runs inside http-nu's own engine, and a plugin cannot be loaded into that.

export const NU_VERSION = "0.113.1"

const ROOT = path self | path dirname
const BINARY = $ROOT | path join nu_plugin_query

# Register the plugin into a temp file and remember where. Run once at
# startup. The registry is only needed by this process, so a temp file is the
# right home for it.
export def --env register [] {
  $env.NU_PLUGIN_REGISTRY = mktemp --suffix .msgpackz
  ^nu --no-config-file -c $"plugin add --plugin-config ($env.NU_PLUGIN_REGISTRY) ($BINARY)"
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
  let r = ^timeout $seconds nu --no-config-file -c $"plugin use --plugin-config ($env.NU_PLUGIN_REGISTRY) query; ($PRELUDE); ($script)" | complete
  { ok: ($r.exit_code == 0), out: $r.stdout, err: $r.stderr, exit_code: $r.exit_code }
}
