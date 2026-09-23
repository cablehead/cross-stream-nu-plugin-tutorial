# Using a nushell plugin from a site on cross.stream

A short tutorial, with a live example. It walks through the three things a
site does to use a nushell plugin on the platform: commit the plugin binary
(built for the host's nushell), register it at startup, and run it in a
separate `nu`, because the handler cannot load it into its own engine.

Live at https://nu-plugin-tutorial.ndyg.cross.stream. The code it walks
through is `plugin.nu`.

## Run it locally

You need a `nu` on the PATH whose version matches `NU_VERSION` in `plugin.nu`,
since the committed plugin is built for that version.

```bash
http-nu --datastar :3002 serve.nu
```
