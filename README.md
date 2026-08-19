# Lock Screen Explorer

A few lock screen designs for Omarchy 4 and a picker to preview and switch between them.
Colors and fonts come from your Omarchy theme.

![preview](preview.png)

Designs: Greeting Card, Classic (the stock one), Editorial, Zen, Split, Terminal, Ring, Poster, Dock, Aurora, Analog, Flip, Island, Cinema, Sheet, Neon, Calendar, Frame, Dayline, Profile, Weather, Music, System, Rain.

Weather fetches from wttr.in (same location as the bar widget), Music reads MPRIS players, System shows uptime, memory, load and battery.

Every password field has an eye button to show what you typed (Ctrl+E does the same). It hides again after a failed attempt or when the field is cleared.

## Install

```sh
omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --enable
omarchy restart shell
```

The restart is needed: the shell loads this service before it unloads the stock one, so for a
moment both claim the `lock` IPC target and the stock one keeps it. Until you restart,
`omarchy-shell lock explore` answers `Function not found`.

This replaces the built-in `omarchy.lock` service (the manifest has `clonedFrom: omarchy.lock`
so the shell swaps them and everything that locks the screen keeps working). Disable or remove
the plugin to get the stock lock screen back.

## Usage

```sh
omarchy-shell lock explore
```

Arrows to browse, Tab to switch category (or click the chips), Space for full-size preview, Enter to select, Esc to close. Scroll with the mouse wheel or PageUp/PageDown. `U` cycles the unlock animation and `Shift+U` its length, the same as clicking the Unlock chip in the header.

`A` picks a profile picture with the normal file dialog (the explorer steps aside while the
dialog is up and comes back when you are done), `Shift+A` clears it again. The designs that show
the user — Greeting Card, Split, Dock, Poster, Sheet, Island and Profile — use it, and fall back
to your initial when there is none.

`C` on any design copies it to `~/.config/omarchy/lock-designs/` (it shows up under Custom) and opens it in the
built-in editor. `E` edits a custom design, `N` starts a new one from the template. The editor has the code on
the left and a live preview on the right: Ctrl+S saves and reloads the preview and the lock screen, Ctrl+O opens
the file in your normal editor (changes made there are picked up too), Esc goes back.

To get it in the app launcher and the Omarchy menu (Style -> Lock Screen):

```sh
~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer/extras/install.sh
```

Optional keybinding for `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + L", "Lock screen explorer", "omarchy-shell lock explore")
```

Other commands:

```sh
omarchy-shell lock designs
omarchy-shell lock design
omarchy-shell lock setDesign zen
omarchy-shell lock previewDesign split   # you can type in the preview
omarchy-shell lock previewFail           # show the failure state in the preview
omarchy-shell lock hidePreview
omarchy-shell lock monitors
omarchy-shell lock setInputMonitor DP-1  # or "all"
omarchy-shell lock avatar
omarchy-shell lock pickAvatar            # the file dialog, same as A in the explorer
omarchy-shell lock setAvatar ~/me.png
omarchy-shell lock clearAvatar           # back to the initial
omarchy-shell lock resetAvatar           # back to whatever is found automatically
omarchy-shell lock unlockAnimation
omarchy-shell lock setUnlockAnimation fade   # none (default), fade, zoom or rise
omarchy-shell lock setUnlockDuration 600     # milliseconds, 0-2000, 400 by default
omarchy-shell lock previewUnlock             # play it on an open preview
```

With more than one monitor you can pick which one shows the sign-in with `setInputMonitor`.
The others get a clock only screen (typing still works there).

The unlock is instant unless you ask for an animation. The Unlock chip in the explorer header
turns one on -- click it to cycle, click the milliseconds next to it for the length, or use `U`
and `Shift+U`. With one on, the lock screen animates away rather than blinking out: the design fades into the plain wallpaper and the desktop is behind it on the
same background. `fade` dissolves it, `zoom` fades with a slight push in and `rise` lifts it off
the screen, `none` is the default instant one. `setUnlockDuration` takes milliseconds.
`previewUnlock` plays the animation on the preview so you can see it without locking. The lock
screen is held for the duration of the animation, so keep it short.

Hyprland paints black under the lock screen, which is why the plain wallpaper is drawn behind the
fade: the desktop comes back on the same background instead of through a dark flash. With
`misc:session_lock_xray = true` the compositor keeps drawing the desktop under the lock screen
instead, and the fade goes straight into it.

The selected design, the avatar and the unlock animation are saved on the plugin entry in
`~/.config/omarchy/shell.json`.

With no avatar set, the first of `~/.config/omarchy/lock-avatar.{png,jpg,jpeg,webp}`, `~/.face`,
`~/.face.icon` and `/var/lib/AccountsService/icons/$USER` is used, so an existing profile picture
shows up on its own.

## Your own designs

Easiest: open the explorer, pick a design you like and press `C`. That copies it to
`~/.config/omarchy/lock-designs/` and opens the editor. `N` gives you a blank one from
`extras/lock-designs/MyDesign.qml`. You can also just drop `.qml` files in that folder yourself;
they show up under Custom, named after the file (`My Design` for `MyDesign.qml`, id `my-mydesign`).

```sh
omarchy-shell lock customize zen        # copy the Zen design to ~/.config/omarchy/lock-designs/Zen.qml
omarchy-shell lock editDesign my-zen    # open it in your editor
omarchy-shell lock rescanDesigns        # pick up files added by hand
```

Keep the `import "../plugins/io.github.sirjul1337.lock-explorer/designs"` line, that is where
`DesignBase`, `PasswordField`, `LockInput`, `Wallpaper` and `Avatar` come from.

To add a design to the plugin itself, copy one of the files in `designs/`, add it to
`Designs.js`, run `omarchy restart shell`.

A design is a `DesignBase` item. It gets `passwordText`, `failureMessage`, `failedAttempts`,
`authenticatingPassword`, `fingerprintConfigured`, `inputEnabled`, a ticking `now`, `userName`,
`hostName` and `greeting()`. Use `PasswordField` for a normal input box or `LockInput` if you
want to draw the input yourself, and point `inputItem` at it so it gets focus. Set
`shakeOnFail: true` on box-less designs (the base flashes red on a wrong password either way), and
`showPasswordToggle: false` if you do not want the eye button.

For the profile picture use `Avatar { lock: lock; width: 96 }`, which shows the chosen image
masked to a circle and the user's initial when there is none. `fontSize`, `fillColor`,
`textColor`, `borderWidth`, `borderColor` and `shadow` are there to fit it into a design. The raw
values are on the base as `hasAvatar` and `avatarUrl` if you want to draw it yourself.

## Remove

```sh
omarchy plugin remove io.github.sirjul1337.lock-explorer
omarchy restart shell
```

That restores the built-in Omarchy lock screen. Your own designs in
`~/.config/omarchy/lock-designs/` are left alone, delete that folder if you want them gone.
The optional launcher entry from `extras/install.sh` can be removed with
`rm ~/.local/share/applications/lock-screen-explorer.desktop ~/.local/share/icons/hicolor/scalable/apps/lock-screen-explorer.svg`
and by deleting the `style.lockscreen` line from `~/.config/omarchy/extensions/omarchy-menu.jsonc`.

## Troubleshooting

`omarchy-shell lock explore` says `Function not found`: the stock lock service is still the one
answering, so this plugin never took over the `lock` IPC target. Run `omarchy restart shell`.
If it persists, check that the plugin is enabled and that the stock one got disabled:

```sh
omarchy plugin list
jq '.plugins, .disabled' ~/.config/omarchy/shell.json
```

`io.github.sirjul1337.lock-explorer` should be enabled and `omarchy.lock` should be in `disabled`.

`Target not found` instead means neither service is loaded, usually because this one failed to
load. `omarchy plugin validate ~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer`
and the shell log will say why.

## Dependencies

Nothing beyond Omarchy 4 itself, except the Weather design, which runs `curl` to fetch
`https://wttr.in` (the same service and location file as the Omarchy weather widget). No other
design makes network requests. Picking an avatar runs `omarchy file select`, the desktop file
chooser that ships with Omarchy. The plugin writes only its own entry in
`~/.config/omarchy/shell.json` (the design you pick and the path to your avatar) and files you
create yourself under `~/.config/omarchy/lock-designs/`. Avatar images are read where they are,
nothing is copied.

## License

MIT, see [LICENSE](LICENSE). `Service.qml` is based on the built-in `omarchy.lock` plugin from Omarchy (MIT).

## Development

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer
qmllint -I "$OMARCHY_PATH/shell" ~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer/{*.qml,designs/*.qml}
omarchy restart shell
```
