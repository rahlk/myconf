# myconf

Personal terminal config for macOS and the Ubuntu SSH host.

## Terminal appearance

- Local Ghostty follows the system appearance: CRT Blue in light mode and Retro Green in dark mode.
- CRT Blue uses DOS colors with a brighter royal blue background (`#1C32C7`) and bright white text (`#FFFFFF`).
- The DOS appearance includes gray menus and white borders, with red, yellow, and cyan ANSI accents.
- Retro Paper remains an optional theme, with black text on a pale paper background (`#FAF9F6`).
- Retro Green uses vivid green text (`#39FF6A`) on an almost-black green background.
- Local SSH profile: Retro Red phosphor, with the same global shaders.
- The Ubuntu theme remains available as an optional orange palette.
- Local font: PxPlus IBM VGA 8x16 at size 18, with Maple Mono NF for Nerd Font symbols.
- Blinking underscore cursor.
- Curved CRT screen, Gaussian scan lines, background glow, and 3px phosphor bloom.
- Vignette strength: `0.10`. White text on blue uses a `2.0` shader gain, capped at display white.
- Slow continuous jitter drifts between random levels, capped at 0.594 pixels. Bursts last 0.5 seconds at random 1–5 minute intervals.
- The top 48px remains flat. Jitter stays zero in the top 96px to preserve mouse alignment with the top tabs.
- One or three bands move from bottom to top at random 20–40 second intervals. Each band takes 1.5 seconds.
- Zellij uses `crt-light` for light mode and `retro-green` for dark mode, with top tabs and rounded pane frames.
- The light Zellij theme uses DOS blue and white, with gray menus and yellow selections. The green Powerline bar shows the session in green on black, gray tabs, a bright green active tab, then time and date.
With CRT Blue, the session uses white text on teal, and the empty bar background is teal.
The session ends square. Tab arrows join directly to the next segment without background gaps.

## Files

| Path | Purpose |
| --- | --- |
| `.config/ghostty/` | Ghostty config, six active shaders, palettes, and SSH launcher |
| `.config/zellij/` | Local Zellij config, themes, layout, and zjstatus plugin |
| `.local/share/fonts/DepartureMono/` | Departure Mono 1.500 and its license |
| `macos/zellij-auto-attach.zsh` | Host-aware Zsh auto-attach block for local Zellij sessions |
| `macos/Services/` | Cmd+Shift+T service for the SSH window |
| `remote/.config/zellij/` | Orange SSH theme and bottom tab-bar layout |
| `remote/ssh-zellij.zsh` | Remote Zsh auto-start block for local and SSH Zellij sessions |

Only the six active shaders are included, with stable filenames. Ghostty runs them in this order:

1. `block-cursor-halo.glsl`
2. `glitch-timed-color.glsl`
3. `crt-no-bloom.glsl`
4. `phosphor-vivid.glsl`
5. `crt-finish.glsl`
6. `phosphor-bloom.glsl`

## Restore on macOS

Copy the shaders, themes, and SSH launcher from `.config/ghostty/` into `~/.config/ghostty/`.
The repository uses the filename `config`. The current installation uses `config.ghostty`.
Copy the repository config into the active Ghostty config file.
Avoid conflicting copies of `config` and `config.ghostty`.

Copy `.config/zellij/` into `~/.config/zellij/`.
Replace the existing local Zellij auto-start block in `~/.zshrc` with `macos/zellij-auto-attach.zsh`.
Do not keep or source both auto-start blocks.
The block selects separate sessions for terminal applications, Claude, Codex, VS Code, and other hosts.
It serializes startup and attaches a real client immediately so the first tab initializes its tab bar.
Set `ZELLIJ_AUTO_ATTACH=false` to skip auto-attach.
Set `ZELLIJ_AUTO_SESSION` to select a session name.

Install PxPlus IBM VGA 8x16 and Maple Mono NF separately in `~/Library/Fonts/`.
The repository includes Departure Mono for the Ubuntu desktop profile.

Copy the workflow from `macos/Services/` into `~/Library/Services/`.
Enable its Cmd+Shift+T shortcut in macOS Keyboard settings under Services.
The launcher creates a separate SSH window because borderless windows cannot host native tabs reliably.
The local files contain personal paths under `/Users/rkrsn` and the `stagger-juice` SSH destination.

Reload Ghostty after applying the files.
For later shader edits, change the configured shader filename to force a rebuild in Ghostty 1.3.1.
A reload with the same filename can reuse a cached shader build.

## Rebuild the tab bar plugin

The included zjstatus plugin adds `tab_powerline` for direct color transitions between adjacent tabs.
The optional `format_left_blue`, `format_right_blue`, and `format_space_blue` keys select the DOS-blue variants from the Zellij theme.
It uses [upstream 0.25.0 at commit 7e6dbfd](https://github.com/dj95/zjstatus/tree/7e6dbfd43a1c7431f3969d9a565bcd6d5bbdce45), with `.config/zellij/plugins/zjstatus-powerline.patch`.

Run `bash macos/build-zjstatus.sh` to rebuild the included plugin.
The script installs Rust 1.95.0 with the WASI target and builds from the pinned source and dependency lockfile.
It writes `.config/zellij/plugins/zjstatus.wasm`.

## Restore on the Ubuntu host

Copy `remote/.config/zellij/` into `~/.config/zellij/` on the host.
Replace the existing Zellij auto-start block in `~/.zshrc` with `remote/ssh-zellij.zsh`.
Do not keep both auto-start blocks.
The SSH block preserves the client terminal palette and selects the orange Zellij theme.
The normal remote desktop session keeps its existing Zellij config.

Install the font in `~/.local/share/fonts/DepartureMono/`.
Then run `fc-cache -f`.
The configured desktop sizes are Departure Mono 11.5 for ddterm and 12 for GNOME Terminal.
The system monospace default is Departure Mono 11.

If the host reports `xterm-ghostty: unknown terminal type`, install Ghostty's terminfo from the Mac:

```sh
infocmp -x -A /Applications/Ghostty.app/Contents/Resources/terminfo xterm-ghostty |
  ssh rkrsn@stagger-juice.ddns.net 'mkdir -p ~/.terminfo && tic -x -o ~/.terminfo -'
```

## Sources

The CRT and glitch shaders derive from [hackrdotsh/ghostty-shaders](https://github.com/hackrdotsh/ghostty-shaders).
Their original source and license comments remain in the shader files.
The Zellij tab bar uses [dj95/zjstatus](https://github.com/dj95/zjstatus). Its upstream license accompanies the plugin.
Departure Mono includes its license beside the font file.
