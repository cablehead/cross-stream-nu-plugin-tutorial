# Using a nushell plugin

A short tutorial for the nushell `query` plugin, with a live example: type a
CSS selector and see what `query web` returns for it, run in a real `nu` on the
server.

Live at https://nu-plugin-tutorial.ndyg.cross.stream.

## How the live example works

The tutorial is an [http-nu](https://github.com/cablehead/http-nu) site. Its
handler cannot load a plugin into its own engine, so `POST /run` starts a fresh
`nu` the way a reader would at a terminal:

```
nu --no-config-file -c "plugin use --plugin-config plugins.msgpackz query; http get .../sample | query web --query 'h2'"
```

`plugin.nu` fetches `nu_plugin_query` from the nushell release on the first
start, puts it in the site's state directory, and registers it there. The
reader's selector is passed through `to nuon`, so it arrives in that command as
one quoted string whatever it contains.

`/sample` is a small page of semantic HTML to query. It is served from
`static/sample.html`.

## Run it locally

You need a `nu` on the PATH whose version matches `NU_VERSION` in `plugin.nu`,
because the plugin is built for exactly one version.

```bash
mkdir -p /tmp/tutorial-state
CROSS_STREAM_SITE_STATE=/tmp/tutorial-state http-nu --datastar :3002 serve.nu
```
