# A tutorial for the nushell query plugin, with a live example.
#
#   GET  /            the tutorial. The reader types a CSS selector and sees
#                     what `query web` returns for it.
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

# The command the reader would type. `--attribute` only when they gave one.
def command [selector: string, attribute: string, url: string]: nothing -> string {
  let attr = if ($attribute | is-empty) { "" } else { $" --attribute ($attribute | to nuon)" }
  $"http get ($url) | query web --query ($selector | to nuon)($attr)"
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
    "<title>Using a nushell plugin</title>"
    "<link rel=\"stylesheet\" href=\"/styles.css\">"
    $"<script type=\"module\" src=\"($DATASTAR_JS_PATH)\"></script>"
    "</head>"
    $"<body data-signals=\"($signals)\" data-init=\"@post\('/run'\)\">"
    "<main>"
    "<h1>Using a nushell plugin</h1>"
    "<p>A nushell plugin is a separate program, named <code>nu_plugin_something</code>, that adds commands to <code>nu</code>. This page walks through one: <code>query</code>, which pulls values out of HTML, JSON and XML. It ships with nushell.</p>"

    "<h2>1. Get the plugin</h2>"
    "<p>A plugin is built for one exact version of nushell. The easiest way to get a matching one is the nushell release itself, which includes the plugins next to <code>nu</code>:</p>"
    $"<pre>nu --version\n# => ($NU_VERSION)\n\n# download the release for your platform from\n# https://github.com/nushell/nushell/releases/tag/($NU_VERSION)\n# and copy nu_plugin_query somewhere on your PATH</pre>"
    "<p>If you build from source instead, <code>cargo install nu_plugin_query</code> gets the newest version, which must match your <code>nu</code>.</p>"

    "<h2>2. Register it, once</h2>"
    "<pre>plugin add ~/.cargo/bin/nu_plugin_query</pre>"
    "<p><code>plugin add</code> runs the binary, asks it what commands it provides, and records them in nushell's plugin registry file. It does not load the plugin yet.</p>"

    "<h2>3. Load it</h2>"
    "<pre>plugin use query</pre>"
    "<p>Now <code>query web</code>, <code>query json</code> and <code>query xml</code> exist. Put this line in <code>config.nu</code> to have them in every session.</p>"

    "<h2>4. Use it</h2>"
    $"<p><code>query web</code> takes a CSS selector and returns the text of every element that matches. Try it against <a href=\"($sample)\">a small page of semantic HTML</a> served next to this tutorial. Type a selector, and the exact command below runs in a fresh <code>nu</code> on this server.</p>"
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
    "<p>The result is a list with one entry per match. Each entry is itself a list of the element's text pieces, so a <code>&lt;li&gt;</code> holding a link, an author and a year gives five strings, separators included. It is shown here as nuon, one match per line; at the prompt nushell draws it as a table. <code>--attribute</code> returns an attribute instead of the text. From there it is ordinary nushell: <code>flatten</code>, <code>where</code>, <code>sort-by</code>.</p>"
    "<p><code>query web --as-table [Title Status Rating]</code> finds the table on the page with those headers and returns it as a nushell table. <code>query json</code> and <code>query xml</code> do the same job for JSON (with <a href=\"https://github.com/tidwall/gjson/blob/master/SYNTAX.md\">gjson</a> paths) and XML (with XPath).</p>"

    "<h2>In a script</h2>"
    "<p>A script run with <code>--no-config-file</code> has no registry, so name it on the command. This is how this page runs your selector:</p>"
    "<pre>nu --no-config-file -c \"plugin use --plugin-config plugins.msgpackz query; http get ... | query web --query 'h2'\"</pre>"
    "<p>The registry file is what <code>plugin add</code> wrote. Make one anywhere with <code>plugin add --plugin-config plugins.msgpackz nu_plugin_query</code>.</p>"
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
      # the sample page, fetched from this same server
      let url = $"http://127.0.0.1:($req.headers.host? | default 'localhost' | split row ':' | last)/sample"
      let proto = $req.headers.x-forwarded-proto? | default "http"
      let shown = command $selector $attribute $"($proto)://($req.headers.host? | default 'localhost')/sample"
      if ($selector | is-empty) {
        { command: $shown, output: "", error: "", ran: false, running: false } | to datastar-patch-signals | to sse
      } else {
        let r = plugin run $"(command $selector $attribute $url) | one-per-line"
        {
          command: $shown
          output: (if $r.ok { $r.out | str trim } else { "" })
          error: (if $r.ok { "" } else { $r.err | error-summary })
          ran: true
          running: false
        } | to datastar-patch-signals | to sse
      }
    })

    (route {method: GET path: "/debug"} {|req ctx|
      {
        headers: $req.headers
        remote: ($req.remote_ip? | default "")
        env: ($env | select -o HTTPNU_FLAGS PORT HOST)
        url_tried: $"http://127.0.0.1:($req.headers.host? | default 'localhost' | split row ':' | last)/sample"
        fetch: (try { http get --full --max-time 5sec $"http://127.0.0.1:($req.headers.host? | default 'localhost' | split row ':' | last)/sample" | get status } catch {|e| $e.msg })
        run: (plugin run "'<p>x</p>' | query web --query p | one-per-line")
      } | to json
    })
    (route {method: GET path: "/sample"} {|req ctx| .static $STATIC "/sample.html" })
    (route {method: GET} {|req ctx| .static $STATIC $req.path })
  ]
}
