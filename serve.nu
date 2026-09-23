# Using a nushell plugin from a site on cross.stream, with a live example.
#
#   GET  /        the tutorial. The reader types a CSS selector and sees what
#                 `query web` returns for it, run right here in the handler.
#   POST /run     runs the reader's selector against the sample page
#   GET  /sample  a small page of semantic HTML to query
#
# The plugin comes from one line in cross-stream.nuon: `plugins: ["query"]`.

use http-nu/router *
use http-nu/datastar *

const ROOT = path self | path dirname
const STATIC = $ROOT | path join static
const SAMPLE = $STATIC | path join sample.html
const HTML = { "content-type": "text/html; charset=utf-8" }
const REPO = "https://github.com/cablehead/cross-stream-nu-plugin-tutorial"

# A list as nuon with one entry per line, which reads better than nested tables.
def one-per-line []: any -> string {
  let rows = $in | each { to nuon }
  if ($rows | is-empty) { "[]" } else { "[\n  " + ($rows | str join ",\n  ") + "\n]" }
}

# The lines of a nushell error that matter to the reader: the message and the help.
def error-summary []: string -> string {
  lines | where ($it =~ '^\s*(x |help:)') | str trim | str join "\n"
}

def page [req: record]: nothing -> string {
  let sample = $req | href "/sample"
  let signals = "{selector: 'h2', attribute: '', command: '', output: '', error: '', ran: false}"
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
    "<p>A nushell plugin is a separate program that adds commands to <code>nu</code>. Its file name starts with <code>nu_plugin_</code>. This site uses the <code>query</code> plugin, which reads values out of HTML with a CSS selector. Try it first. Then read how the site loads it, which takes one line.</p>"

    "<h2>Try it</h2>"
    $"<p><code>query web</code> takes a CSS selector and returns the text of each element that matches. Type a selector. The site runs it in its handler against <a href=\"($sample)\">a small page of semantic HTML</a>. The command shown is the same query at a terminal.</p>"
    "<form class=\"try\" data-on:submit__prevent=\"@post('/run')\">"
    "<label>selector <input name=\"selector\" data-bind:selector data-on:input__debounce.400ms=\"@post('/run')\" placeholder=\"h2\" autocomplete=\"off\" spellcheck=\"false\"></label>"
    "<label>attribute <input name=\"attribute\" data-bind:attribute data-on:input__debounce.400ms=\"@post('/run')\" placeholder=\"(none)\" autocomplete=\"off\" spellcheck=\"false\"></label>"
    "<button type=\"submit\">run</button>"
    "</form>"
    "<p class=\"hint\">try <a href=\"#\" data-on:click__prevent=\"$selector = 'h2'; $attribute = ''; @post('/run')\">h2</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = '#papers a'; $attribute = ''; @post('/run')\">#papers a</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = '.author'; $attribute = ''; @post('/run')\">.author</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = 'li time'; $attribute = 'datetime'; @post('/run')\">li time with the datetime attribute</a>,"
    " <a href=\"#\" data-on:click__prevent=\"$selector = '#papers a'; $attribute = 'href'; @post('/run')\">#papers a with href</a></p>"
    "<pre class=\"command\" data-text=\"$command\"></pre>"
    "<pre class=\"output\" data-show=\"$ran && $error == ''\" data-text=\"$output\"></pre>"
    "<pre class=\"error\" data-show=\"$error != ''\" data-text=\"$error\"></pre>"
    "<p>The result is a list with one entry for each match. Each entry is a list of the text pieces in that element. A <code>&lt;li&gt;</code> that holds a link, an author and a year gives five strings, because the separators count. The page shows the result as nuon, one match on each line. At a terminal, nushell draws the same result as a table. <code>--attribute</code> returns an attribute of each element instead of its text.</p>"

    "<h2>How the site loads the plugin</h2>"
    "<p>One line in <code>cross-stream.nuon</code>:</p>"
    "<pre>{ datastar: true, plugins: [\"query\"] }</pre>"
    "<p><code>plugins</code> is a list of plugin names. <code>query</code> is a stock plugin. The stock plugins are already on the host, so the name is all the site needs. On the next push the platform starts http-nu with the plugin loaded. The push output shows this:</p>"
    "<pre>remote: post-receive: http-nu flags for nu-plugin-tutorial: --datastar --plugin /usr/local/bin/nu_plugin_query</pre>"
    "<p>The stock plugins are the plugins that ship with nushell: <code>query</code>, <code>polars</code>, <code>formats</code>, <code>gstat</code>, and some demo plugins. The <a href=\"https://ndyg.cross.stream/docs\">site guide</a> lists them.</p>"

    "<h3>A plugin that is not stock</h3>"
    "<p>Commit the plugin file to the repo. In the list, give its path instead of its name:</p>"
    "<pre>{ datastar: true, plugins: [\"bin/nu_plugin_mine\"] }</pre>"
    "<p>The platform does not build anything. The plugin file must be ready to run when you push it. Make sure of three things:</p>"
    "<ul>"
    "<li>The file is a linux/x86_64 build. From Rust, use the target <code>x86_64-unknown-linux-musl</code> for a static build, or <code>x86_64-unknown-linux-gnu</code> for glibc 2.39 or older.</li>"
    "<li>The build uses the same nushell version as the host. A plugin does not load under a different version. The push output shows the host version, and so does <code>nu --version</code> on the host.</li>"
    "<li>The file is executable. Git keeps the executable bit if the bit was set when you added the file. If not, run <code>git update-index --chmod=+x bin/nu_plugin_mine</code>.</li>"
    "</ul>"
    "<p>The path is relative to the repo root. The platform rejects absolute paths and paths that contain <code>..</code>. A plugin from crates.io works the same way. Install it with <code>cargo install</code> under the host nushell version, then commit the file from <code>~/.cargo/bin</code>.</p>"
    "<p>One thing to watch. When the platform cannot find a plugin in the list, it does not fail the deploy. It skips the plugin and writes a warning in the push output. The first sign is a missing command at runtime. If a plugin's commands are missing, read the push output.</p>"

    "<h2>Using the plugin in the handler</h2>"
    "<p>The plugin's commands are ordinary commands in the handler. This is the route behind the box above:</p>"
    "<pre>(route {method: POST path: \"/run\"} {|req ctx|\n  let signals = $in | from datastar-signals $req\n  let result = open --raw $SAMPLE | query web --query $signals.selector\n  { output: ($result | one-per-line) } | to datastar-patch-signals | to sse\n})</pre>"
    "<p>There is no <code>plugin add</code> and no <code>plugin use</code>. Those two commands register and load a plugin in a nushell session. The platform does the same work when it starts http-nu with <code>--plugin</code>.</p>"

    "<h2>At a terminal</h2>"
    "<p>In your own nushell, register the plugin once with <code>plugin add nu_plugin_query</code>. Then put <code>plugin use query</code> in <code>config.nu</code> to load it in each session. The plugin must match your <code>nu</code> version. The nushell release tarball ships each stock plugin next to <code>nu</code>. To run this site on your own machine, give http-nu the plugin yourself: <code>http-nu --datastar --plugin nu_plugin_query :3002 serve.nu</code>.</p>"
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
      let attr = if ($attribute | is-empty) { "" } else { $" --attribute ($attribute | to nuon)" }
      let command = $"http get https://($req.headers.host? | default 'localhost')/sample | query web --query ($selector | to nuon)($attr)"
      if ($selector | is-empty) {
        { command: $command, output: "", error: "", ran: false } | to datastar-patch-signals | to sse
      } else {
        let r = try {
          let out = if ($attribute | is-empty) {
            open --raw $SAMPLE | query web --query $selector
          } else {
            open --raw $SAMPLE | query web --query $selector --attribute $attribute
          }
          { output: ($out | one-per-line), error: "" }
        } catch {|e|
          { output: "", error: ($e.rendered? | default $e.msg | error-summary) }
        }
        { command: $command, output: $r.output, error: $r.error, ran: true } | to datastar-patch-signals | to sse
      }
    })

    (route {method: GET path: "/sample"} {|req ctx| .static $STATIC "/sample.html" })
    (route {method: GET} {|req ctx| .static $STATIC $req.path })
  ]
}
