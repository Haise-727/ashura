# Known issues

## Bugs

- Holding Super, dragging a window with the mouse, then releasing Super can
  still open search: mouse drag binds cannot cancel the tap.
- The cheatsheet's rightmost column is clipped at 1920 px wide, and it shows
  Ctrl+Super+F1 as "F&lt;Number&gt;" because it groups function keys.
- Esc does not close the cheatsheet; Super+/ or a click outside does.
- A live lofi stream shows a meaningless track length (mpv reports its buffer).
- After a crash while locked, the lock guard brings back only the focused
  monitor's workspace.

## Limits

- **Outline transition.** It needs the BiRefNet model, downloaded on first use
  (Settings, Wallpapers, "Prepare transitions now"). Until then every change
  uses the pixel colonies.
- **Cockpit window claiming.** A window is filed under a repo only when it can be
  identified:
  - VS Code is matched by the repo's folder name in its title. With a changed
    `window.title` setting, or two repos sharing a folder name, it is not
    claimed.
  - For 10 s after a cockpit first opens, the next new Firefox window is filed
    under that repo.
  - When Firefox was not running yet, the cockpit gets no browser window:
    Firefox's first windows are its own session restore and are left alone.
  - Firefox or VS Code windows you open yourself in the cockpit are not filed
    under the repo; move them with the overview.
- **Docker** deletes nothing (images, volumes, containers) on purpose.
- **Booru.** Danbooru answers 403 to non browser clients. Gelbooru needs an API
  key. The blacklist matches whole space separated tags, so Zerochan's multi
  word tags cannot be blocked exactly.
- **No keyboard TTY** when the keyboard has no Alt key (Ctrl+Alt+Fn cannot be
  typed). Use `sudo chvt 3` from a terminal.
- **Login picker.** qylock's `clockwork` is a folder of three themes, so the
  picker does not list it; `ninesols` has no preview image.
- **Live wallpapers** use the GPU continuously (mpvpaper or a full screen
  shader). They pause while every screen shows a fullscreen or maximized window.
- **Lyrics** depend on LRCLIB having the song; odd video titles may not match.
  They only toggle over IPC for now: `qs -c ashura ipc call lyrics toggle`.
- **Depth parallax** is switched off: the filled in background shows as smudges
  round characters. The code and `scripts/ashura/depthlayers` stay.
- **Automatic suspend** is off in `hypridle.conf` because resume hangs on the
  laptop this was built on (an NVIDIA wake bug). Turn the listener back on if
  suspend works on yours.
