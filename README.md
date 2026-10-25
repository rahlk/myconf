# myconf

Personal terminal config for macOS and the Ubuntu SSH host.

## Terminal appearance

- Local Ghostty follows the system appearance: CRT Blue in light mode and Retro Green in dark mode.
- CRT Blue uses the standard 16-color DOS palette, with a blue background (`#0000AA`) and light gray text (`#AAAAAA`).
- The DOS appearance includes gray menus and borders, with red, yellow, and cyan ANSI accents.
- Retro Paper remains an optional theme, with black text on a pale paper background (`#FAF9F6`).
- Retro Green uses vivid green text (`#39FF6A`) on an almost-black green background.
- Local SSH profile: Retro Red phosphor, with the same global shaders.
- The Ubuntu theme remains available as an optional orange palette.
- Local font: PxPlus IBM VGA 8x16 at size 18, with Maple Mono NF for Nerd Font symbols.
- Blinking underscore cursor.
- Flat CRT screen, scan lines, background glow, and no text bloom.
- Vignette strength: `0.10` for the general finish and `0.165` for white text on blue.
- Light continuous jitter and 0.5-second bursts at random 1–5 minute intervals.
- One or three bands move from bottom to top at random 20–40 second intervals. Each band takes 1.5 seconds.
- Zellij uses `crt-light` for light mode and `retro-green` for dark mode, with top tabs and rounded pane frames.
- The light Zellij theme uses DOS blue and gray, with yellow for selected elements. A date and clock appear beside the tabs.

## Files

| Path | Purpose |
| --- | --- |
| `.config/ghostty/` | Ghostty config, five active shaders, palettes, and SSH launcher |
| `.config/zellij/` | Local Zellij config, themes, layout, and zjstatus plugin |
| `.local/share/fonts/DepartureMono/` | Departure Mono 1.500 and its license |
| `macos/zellij-auto-attach.zsh` | Host-aware Zsh auto-attach block for local Zellij sessions |
| `macos/Services/` | Cmd+Shift+T service for the SSH window |
| `remote/.config/zellij/` | Orange SSH theme and bottom tab-bar layout |
| `remote/ssh-zellij.zsh` | Remote Zsh auto-start block for local and SSH Zellij sessions |

Only the five active shaders are included, with stable filenames. Ghostty runs them in this order:

1. `block-cursor-halo.glsl`
2. `glitch-timed-color.glsl`
3. `crt-no-bloom.glsl`
4. `phosphor-vivid.glsl`
5. `crt-finish-shared.glsl`

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
