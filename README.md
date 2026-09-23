# Using a nushell plugin from a site on cross.stream

A short tutorial with a live example. On cross.stream a nushell plugin is one
line in the site's manifest:

```nuon
{ datastar: true, plugins: ["query"] }
```

After that the plugin's commands are ordinary commands in the handler. The page
shows that with `query web`: type a CSS selector and see what it returns for a
small page of semantic HTML, run in the handler itself.

Live at https://nu-plugin-tutorial.ndyg.cross.stream.

## Run it locally

Pass the plugin yourself. It has to match your `nu` version, and the nushell
release tarball ships it next to `nu`.

```bash
http-nu --datastar --plugin nu_plugin_query :3002 serve.nu
```
