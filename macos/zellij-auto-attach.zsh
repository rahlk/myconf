# ── zellij: host-aware auto-attach ──────────────────────────────────
# One persistent session per host program, so "main" stays reserved for
# shells I start myself in a real terminal:
#   claude code -> claude   codex -> codex   vscode/codium -> code
#   iTerm2/Terminal.app/Ghostty/... -> main   anything else -> other
# Serialize creation: simultaneous `attach --create`
# calls can start competing servers for the same session socket.
# Escape hatches: ZELLIJ_AUTO_ATTACH=false zsh | ZELLIJ_AUTO_SESSION=foo zsh
if [[ -o interactive && -t 1 && "$ZELLIJ_AUTO_ATTACH" != "false" ]]; then
  if   [[ -n "$ZELLIJ_AUTO_SESSION" ]]; then zj="$ZELLIJ_AUTO_SESSION"
  elif [[ -n "$CLAUDECODE" || "$TERM_PROGRAM" == claude* \
       || "$__CFBundleIdentifier" == com.anthropic.* ]];               then zj=claude
  elif [[ -n "${CODEX_SANDBOX}${CODEX_INTERNAL_ORIGINATOR_OVERRIDE}" \
       || "$TERM_PROGRAM" == codex* || "$__CFBundleIdentifier" == com.openai.* ]]; then zj=codex
  elif [[ "$TERM_PROGRAM" == vscode \
       || "$__CFBundleIdentifier" == (com.microsoft.VSCode|com.vscodium|com.visualstudio.code.oss)* ]]; then zj=code
  elif [[ "$TERM_PROGRAM" == (Apple_Terminal|iTerm.app|ghostty|WezTerm|Hyper|Tabby|rio) \
       || "$TERM" == (xterm-kitty|alacritty*) \
       || "$__CFBundleIdentifier" == (com.apple.Terminal|com.googlecode.iterm2|com.mitchellh.ghostty) ]]; then zj=main
  else                                                                      zj=other
  fi

  # $ZELLIJ* is inherited by every app a pane launches (Claude Desktop, VS
  # Code, ...), so it alone can't say whether this shell IS a pane - walk up
  # the process tree and see which comes first, the zellij server or a host
  # program. Already in the session we'd pick? Nothing to do either way.
  if [[ -n "$ZELLIJ" ]]; then
    [[ "$ZELLIJ_SESSION_NAME" == "$zj" ]] && zj=
    if [[ -n "$zj" ]]; then
      typeset -gA zj_ppid zj_comm
      local zj_p zj_pp zj_c
      while read -r zj_p zj_pp zj_c; do zj_ppid[$zj_p]=$zj_pp; zj_comm[$zj_p]=$zj_c; done \
        < <(ps -Ao pid=,ppid=,comm=)
      zj_p=$PPID
      while (( zj_p > 1 )); do
        zj_c=${zj_comm[$zj_p]:t}
        case $zj_c in
          zellij) zj=; break ;;                                     # a real pane: stay put
          claude*|codex*|node|Electron|Code*|VSCodium*|Cursor*|Windsurf*|*Helper*) break ;;
        esac                                                        # host in between: stale env
        zj_p=${zj_ppid[$zj_p]:-1}
      done
      unset zj_ppid zj_comm zj_p zj_pp zj_c
    fi
  fi

  if [[ -n "$zj" ]]; then
    unset ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID   # drop inherited pane env
    if (
      setopt localoptions nomonitor
      zmodload zsh/system || exit 1
      local zj_lock_dir="${TMPDIR:-/tmp}/zellij-${UID}"
      local zj_lock_fd zj_client_pid zj_clients
      mkdir -p -m 700 "$zj_lock_dir" || exit 1
      : >> "$zj_lock_dir/auto-attach.lock" || exit 1
      zsystem flock -t 10 -i 0.05 -f zj_lock_fd "$zj_lock_dir/auto-attach.lock" || exit 1

      # Start with a real client so the first tab's plugins initialize.
      # Keep its terminal input connected while waiting for session readiness.
      zellij attach --create "$zj" < /dev/tty > /dev/tty 2>&1 &
      zj_client_pid=$!
      while kill -0 "$zj_client_pid" 2>/dev/null; do
        zj_clients=$(zellij --session "$zj" action list-clients 2>/dev/null)
        [[ "$zj_clients" == CLIENT_ID*$'\n'[0-9]* ]] && break
        sleep 0.05
      done
      zsystem flock -u "$zj_lock_fd"
      wait "$zj_client_pid"
    ); then
      [[ "$ZELLIJ_AUTO_EXIT" == "true" ]] && exit
    else
      print -u2 -r -- "Zellij could not start session '$zj'; continuing in this shell."
    fi
  fi
  unset zj
fi
