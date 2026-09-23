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
    "<p>A nushell plugin is a separate program, named <code>nu_plugin_something</code>, that adds commands to <code>nu</code>. This site uses one, <code>query</code>, which pulls values out of HTML with a CSS selector. Getting it takes one line.</p>"

    "<h2>1. Name it in <code>cross-stream.nuon</code></h2>"
    "<pre>{ datastar: true, plugins: [\"query\"] }</pre>"
    "<p><code>plugins</code> is a list. <code>query</code> is one of the stock plugins, which are already on the host, so naming it is all there is to do. On the next push the site starts with the plugin loaded, and the push output shows it:</p>"
    "<pre>remote: post-receive: http-nu flags for nu-plugin-tutorial: --datastar --plugin /usr/local/bin/nu_plugin_query</pre>"
    "<p>For a plugin you built yourself, commit the binary and name its path instead: <code>plugins: [\"bin/nu_plugin_mine\"]</code>. It has to be a linux/x86_64 build made against the same nushell version the host runs. The <a href=\"https://ndyg.cross.stream/docs\">site guide</a> has the details and the list of stock plugins.</p>"

    "<h2>2. Use it</h2>"
    "<p>The plugin's commands are now ordinary commands in the handler. This is the whole of the route behind the box below:</p>"
    "<pre>(route {method: POST path: \"/run\"} {|req ctx|\n  let signals = $in | from datastar-signals $req\n  let result = open --raw $SAMPLE | query web --query $signals.selector\n  { output: ($result | one-per-line) } | to datastar-patch-signals | to sse\n})</pre>"
    "<p>There is no <code>plugin add</code> and no <code>plugin use</code>. Those are for a nushell session, and the platform did the equivalent when it started http-nu with <code>--plugin</code>.</p>"

    "<h2>Try it</h2>"
    $"<p><code>query web</code> takes a CSS selector and returns the text of every element that matches. Type one, and it runs against <a href=\"($sample)\">a small page of semantic HTML</a> served next to this one. The command shown is what the same thing looks like at a terminal.</p>"
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
    "<p>The result is a list with one entry per match. Each entry is itself a list of the element's text pieces, so a <code>&lt;li&gt;</code> holding a link, an author and a year gives five strings, separators included. It is shown here as nuon, one match per line; at the prompt nushell draws it as a table. <code>--attribute</code> returns an attribute instead of the text.</p>"

    "<h2>At a terminal</h2>"
    "<p>In your own nushell the plugin needs registering first: <code>plugin add nu_plugin_query</code> once, then <code>plugin use query</code> in <code>config.nu</code>. The plugin must match your <code>nu</code> version exactly; the nushell release tarball ships every stock plugin next to <code>nu</code>. To run this site locally, pass the plugin yourself: <code>http-nu --datastar --plugin nu_plugin_query :3002 serve.nu</code>.</p>"
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
