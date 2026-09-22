# Probe: can this deployment load a nushell plugin?
{|req|
  {
    httpnu_flags: ($env.HTTPNU_FLAGS? | default "unset")
    nu: (version | get version)
    plugin_path: ($nu.plugin-path? | default "unset")
    plugins: (try { plugin list | get name } catch {|e| $"error: ($e.msg)" })
    state_dir: ($env.CROSS_STREAM_SITE_STATE? | default "unset")
    can_exec_from_state: (try {
      let f = $env.CROSS_STREAM_SITE_STATE | path join probe.sh
      "#!/bin/sh\necho ok\n" | save -f $f
      ^chmod +x $f
      ^$f | str trim
    } catch {|e| $"error: ($e.msg)" })
  } | to json
}
