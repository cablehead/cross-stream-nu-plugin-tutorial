# How a site on cross.stream uses a nushell plugin, with a live example.
#
#   GET  /            the tutorial. It walks through plugin.nu, then lets the
#                     reader type a CSS selector and see what `query web` returns.
#   POST /run         runs the reader's selector against /sample in a fresh
#                     `nu` with the plugin loaded, and patches the result in
#   GET  /sample      a small page of semantic HTML to query
#
# plugin.nu fetches nu_plugin_query into the site's state dir on first start.

use http-nu/router *
use http-nu/datastar *
use ./plugin.nu
use ./plugin.nu NU_VERSION

const ROOT = path self | path dirname
const STATIC = $ROOT | path join static
const HTML = { "content-type": "text/html; charset=utf-8" }
const REPO = "https://github.com/cablehead/cross-stream-nu-plugin-tutorial"

plugin install

def escape []: string -> string {
  str replace --all "&" "&amp;" | str replace --all "<" "&lt;" | str replace --all ">" "&gt;" | str replace --all '"' "&quot;"
}

# The `query web` part of the command, quoted so any input is one string.
def query-part [selector: string, attribute: string]: nothing -> string {
  let attr = if ($attribute | is-empty) { "" } else { $" --attribute ($attribute | to nuon)" }
  $"query web --query ($selector | to nuon)($attr)"
}

# The lines of a nushell error that matter to the reader: the message and the
# help, without the source listing that points into this server's own command.
def error-summary []: string -> string {
  lines | where ($it =~ '^\s*(x |help:)') | str trim | str join "\n"
}

def page [req: record]: nothing -> string {
  let sample = $req | href "/sample"
  let signals = "{selector: 'h2', attribute: '', command: '', output: '', error: '', ran: false, running: false}"
  [
    "<!doctype html>"
    "<html lang=\"en\">"
    "<head>"
    "<meta charset=\"utf-8\">"
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    "<link rel=\"icon\" href=\"data:,\">"
    "<title>A nushell plugin on cross.stream</title>"
    "<link rel=\"stylesheet\" href=\"/styles.css\">"
    $"<script type=\"module\" src=\"($DATASTAR_JS_PATH)\"></script>"
    "</head>"
    $"<body data-signals=\"($signals)\" data-init=\"@post\('/run'\)\">"
    "<main>"
    "<h1>Using a nushell plugin from a site on cross.stream</h1>"
    "<p>A nushell plugin is a separate program, named <code>nu_plugin_something</code>, that adds commands to <code>nu</code>. This site uses one, <code>query</code>, which pulls values out of HTML with a CSS selector. Try it at the bottom of the page. The rest of the page is how the site gets the plugin onto the host and runs it, in three steps that any plugin needs.</p>"
    "<p>The whole thing is one file, <a href=\"https://github.com/cablehead/cross-stream-nu-plugin-tutorial/blob/main/plugin.nu\"><code>plugin.nu</code></a>, about 40 lines. The pieces below are taken from it.</p>"

    "<h2>1. The plugin has to live in <code>state/</code></h2>"
    "<p>A plugin binary is 19 MB, so it is not something to commit. The site downloads it from the nushell release the first time it starts. It has to go in the site's state directory, <code>$env.CROSS_STREAM_SITE_STATE</code>: the repo is rebuilt on every push, and everything else on the host is read-only.</p>"
    "<pre>const TARBALL = $\"nu-($NU_VERSION)-x86_64-unknown-linux-musl\"\nconst URL = $\"https://github.com/nushell/nushell/releases/download/($NU_VERSION)/\"\n  + $\"($TARBALL).tar.gz\"\n\ndef state []: nothing -> path { $env.CROSS_STREAM_SITE_STATE }\n\nlet tar = state | path join $\"($TARBALL).tar.gz\"\nhttp get $URL | save --force $tar\n^tar -xzf $tar -C (state) $\"($TARBALL)/nu_plugin_query\" --strip-components 1\n^chmod +x (state | path join nu_plugin_query)</pre>"
    $"<p>A plugin is built for one exact version of nushell, and the <code>nu</code> on a cross.stream host is ($NU_VERSION), so the release it is downloaded from must be the same one. The release tarball ships every plugin next to <code>nu</code>, which is why no build step is needed. State survives pushes, so this download happens once per site, not once per deploy.</p>"

    "<h2>2. Register it, into a file in <code>state/</code> too</h2>"
    "<p>Before nushell will load a plugin it has to be registered: <code>plugin add</code> runs the binary once, asks it which commands it provides, and writes the answer to a registry file. Normally that file is nushell's own, in the config directory. The handler has no config directory, so the registry is named on the command and kept beside the binary:</p>"
    "<pre>let registry = state | path join plugins.msgpackz\nlet binary = state | path join nu_plugin_query\n^nu --no-config-file -c $\"plugin add --plugin-config ($registry) ($binary)\"</pre>"
    "<p>The site skips both steps when the registry file already exists.</p>"

    "<h2>3. Run it in a separate <code>nu</code></h2>"
    "<p>An http-nu handler runs inside http-nu's own nushell engine, and on cross.stream there is no way to load a plugin into it. So the handler does what you would do at a terminal: it starts a fresh <code>nu</code>, loads the plugin with <code>plugin use</code>, and runs the command there.</p>"
    "<pre>export def run [script: string]: nothing -> record {\n  let registry = state | path join plugins.msgpackz\n  let r = ^nu --no-config-file -c $\"plugin use --plugin-config ($registry) query; ($script)\"\n    | complete\n  { ok: ($r.exit_code == 0), out: $r.stdout, err: $r.stderr }\n}</pre>"
    "<p><code>complete</code> collects the output and the exit code instead of failing the handler. Starting a <code>nu</code> and loading the plugin costs about 20 milliseconds, so this is fine per request. The site adds a <code>timeout</code> in front of <code>nu</code> so a slow command cannot hold a request open.</p>"

    "<h2>Try it</h2>"
    $"<p>Type a CSS selector. The command shown runs on this server, through the <code>run</code> function above, against <a href=\"($sample)\">a small page of semantic HTML</a> served next to this one. The selector goes through <code>to nuon</code> on the way in, so whatever you type arrives as one quoted string.</p>"
    "<form class=\"try\" data-on:submit__prevent=\"@post('/run')\">"
    "<label>selector <input name=\"selector\" data-bind:selector data-on:input__debounce.400ms=\"@post('/run')\" placeholder=\"h2\" autocomplete=\"off\" spellcheck=\"false\"></label>"
    "<label>attribute <input name=\"attribute\" data-bind:attribute data-on:input__debounce.400ms=\"@post('/run')\" placeholder=\"(none)\" autocomplete=\"off\" spellcheck=\"false\"></label>"
    "<button type=\"submit\" data-attr:disabled=\"$running\">run</button>"
    "</form>"
    "<p class=\"hint\">try <a href=\"#\" data-on:click__prevent=\"$selector = 'h2'; $attribute = ''; @post('/run')\">h2</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = '#papers a'; $attribute = ''; @post('/run')\">#papers a</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = '.author'; $attribute = ''; @post('/run')\">.author</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = 'li time'; $attribute = 'datetime'; @post('/run')\">li time with the datetime attribute</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = '#papers a'; $attribute = 'href'; @post('/run')\">#papers a with href</a></p>"
    "<pre class=\"command\" data-text=\"$command\"></pre>"
    "<pre class=\"output\" data-show=\"$ran && $error == ''\" data-text=\"$output\"></pre>"
    "<pre class=\"error\" data-show=\"$error != ''\" data-text=\"$error\"></pre>"
    "<p>The result is a list with one entry per match. Each entry is itself a list of the element's text pieces, so a <code>&lt;li&gt;</code> holding a link, an author and a year gives five strings, separators included. It is shown here as nuon, one match per line; at the prompt nushell draws it as a table. <code>--attribute</code> returns an attribute instead of the text.</p>"

    "<h2>On your own machine</h2>"
    "<p>The same three steps apply, with the differences you would expect: <code>plugin add nu_plugin_query</code> with no <code>--plugin-config</code> writes to nushell's own registry, and <code>plugin use query</code> in <code>config.nu</code> loads it in every session. To run this site locally, set <code>CROSS_STREAM_SITE_STATE</code> to any writable directory, which is what the platform does for you when deployed.</p>"
    "</main>"
    "<footer>"
    $"<a href=\"($REPO)\">source</a> · <a href=\"https://www.nushell.sh/book/plugins.html\">the plugins chapter of the nushell book</a> · served by <a href=\"https://http-nu.cross.stream\">http-nu</a>"
    "</footer>"
    "</body>"
    "</html>"
  ] | str join "\n" | metadata set { merge { "http.response": { headers: $HTML } } }
}

{|req|
  dispatch $req [
    (route {method: GET path: "/"} {|req ctx| page $req })

    (route {method: POST path: "/run"} {|req ctx|
      let signals = $in | from datastar-signals $req
      let selector = $signals.selector? | default "" | str trim | str substring 0..200
      let attribute = $signals.attribute? | default "" | str trim | str substring 0..60
      # What the reader would type: /sample is public. What runs here reads the
      # same file from disk, since the handler does not know its own port.
      let shown = $"http get https://($req.headers.host? | default 'localhost')/sample | (query-part $selector $attribute)"
      let sample = $STATIC | path join sample.html
      if ($selector | is-empty) {
        { command: $shown, output: "", error: "", ran: false, running: false } | to datastar-patch-signals | to sse
      } else {
        let r = plugin run $"open --raw ($sample | to nuon) | (query-part $selector $attribute) | one-per-line"
        {
          command: $shown
          output: (if $r.ok { $r.out | str trim } else { "" })
          error: (if $r.ok { "" } else { $r.err | error-summary })
          ran: true
          running: false
        } | to datastar-patch-signals | to sse
      }
    })

    (route {method: GET path: "/sample"} {|req ctx| .static $STATIC "/sample.html" })
    (route {method: GET} {|req ctx| .static $STATIC $req.path })
  ]
}
