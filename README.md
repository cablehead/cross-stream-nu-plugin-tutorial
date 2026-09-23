# Using a nushell plugin from a site on cross.stream

A short tutorial, with a live example. It walks through the three things a
site has to do to use a nushell plugin on the platform: put the plugin binary
in `state/`, register it into a registry file there, and run it in a separate
`nu` because the handler cannot load it into its own engine.

Live at https://nu-plugin-tutorial.ndyg.cross.stream. The code it walks
through is `plugin.nu`.

## Run it locally

You need a `nu` on the PATH whose version matches `NU_VERSION` in `plugin.nu`,
since a plugin is built for one version. Give the site a writable directory in
place of the one the platform provides:

```bash
mkdir -p /tmp/tutorial-state
CROSS_STREAM_SITE_STATE=/tmp/tutorial-state http-nu --datastar :3002 serve.nu
```
