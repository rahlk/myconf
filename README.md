# myconf

Personal terminal config for macOS and the Ubuntu SSH host.

## Terminal appearance

- Local Ghostty follows the system appearance: Retro Paper in light mode and Retro Green in dark mode.
- Retro Paper inverts the green palette into near-black ink (`#030303`) on paper white (`#FDFDFD`). Both appearances apply the monochrome filter to application colors.
- Retro Green uses vivid green text (`#39FF6A`) on an almost-black green background.
- Local SSH profile: Retro Red phosphor, with the same global shaders.
- The Ubuntu theme remains available as an optional orange palette.
- Local font: PxPlus IBM VGA 8x16 at size 16, with Maple Mono NF for Nerd Font symbols.
- Blinking underscore cursor.
- Subtle CRT curvature (`0.006`), Gaussian scan lines with wider bright beams, tightly spaced antialiased concentric background rings, and 3px phosphor bloom. Dark-theme scan lines have a 6px pitch; paper uses a finer 3px texture.
- Background rings repeat every 3 physical pixels and are drawn in the final overlay with pixel filtering to reduce moiré.
- Vignette strength is `0.10` in dark mode and `0.035` on paper.
- Smooth whole-screen horizontal drift reaches ±1.25 physical pixels, easing between random targets seven times per second. Row-level analog wobble remains capped at 0.1188px; rare half-second glitch bursts occur at random 1–5 minute intervals.
- Original tracking distortion rolls downward every 20–40 seconds, taking 1.5 seconds per pass. RGB separation during tracking and bursts feeds into the monochrome filter.
- Six soft brightness sweeps fit each tracking interval. Every sixth sweep shares the tracking band's start, vertical position, and speed, including the curvature mapping.
- The brightness sweep darkens backgrounds by up to 7.2% on paper and 4.8% in dark mode. Separate whole-screen flicker is capped at 0.5% dimming (0.25% average).
- Zellij uses `retro-paper` for light mode and `retro-green` for dark mode, with top tabs and rounded pane frames. Paper uses dark active frames and gray inactive frames.
- The green Powerline bar shows the session, tabs, time, and date. The session ends square; tab arrows join directly to the next segment without background gaps.

## Files

| Path | Purpose |
| --- | --- |
| `.zshrc.macos` | macOS Zsh config with credentials removed |
| `.config/ghostty/` | Ghostty config, one CRT source bundle, pass builder, palettes, and SSH launcher |
| `.config/zellij/` | Local Zellij config, themes, layout, and zjstatus plugin |
| `.local/share/fonts/DepartureMono/` | Departure Mono 1.500 and its license |
| `macos/zellij-auto-attach.zsh` | Host-aware Zsh auto-attach block for local Zellij sessions |
| `macos/Services/` | Cmd+Shift+T service for the SSH window |
| `remote/.config/zellij/` | Orange SSH theme and bottom tab-bar layout |
| `remote/ssh-zellij.zsh` | Remote Zsh auto-start block for local and SSH Zellij sessions |

All eight effects live in `.config/ghostty/shaders/crt.glsl`. The `reload-shader` script selects each `CRT_PASS` at compile time and generates eight cached shader inputs in this order:

1. Block-cursor halo and trail
2. Analog drift, tracking distortion, and rare bursts
3. CRT texture and horizontal softening
4. Green/red phosphor or inverted paper monochrome
5. Scan lines and vignette
6. Phosphor bloom
7. Subtle curvature
8. Background rings, synchronized brightness sweeps, and flicker

The eight GPU passes keep their intermediate textures, preserving the original rendering cost. Generated cache files are rebuilt from the source bundle and are not versioned.

## Restore on macOS

Copy `.config/ghostty/`, including `reload-shader`, into `~/.config/ghostty/`.
The repository and current installation both use the filename `config`.
Copy the repository config into the active Ghostty config file.
Avoid conflicting copies of `config` and `config.ghostty`.

Then build the shader passes and reload Ghostty:

```sh
~/.config/ghostty/reload-shader
```

This regenerates the cache paths recorded in `config` for the current machine. The copied config's cache paths must be rebuilt before using it on another machine or after clearing the shader cache.

Copy `.config/zellij/` into `~/.config/zellij/`.
Copy `.zshrc.macos` to `~/.zshrc` for the full macOS shell config.
Set API keys in your local environment.
To keep your existing `~/.zshrc`, replace only its Zellij auto-start block with `macos/zellij-auto-attach.zsh`.
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

After editing `shaders/crt.glsl`, run `~/.config/ghostty/reload-shader` again. It creates versioned cache paths, validates the config, and reloads Ghostty. An ordinary config reload uses the last generated shader passes.

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
