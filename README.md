# Lock Screen Explorer

A few lock screen designs for Omarchy 4 and a picker to preview and switch between them.
Colors and fonts come from your Omarchy theme.

![preview](preview.png)

Designs: Greeting Card, Classic (the stock one), Editorial, Zen, Split, Terminal.

## Install

```sh
omarchy plugin add https://github.com/SirJul1337/omarchy-lock-explorer.git --enable
```

This replaces the built-in `omarchy.lock` service (the manifest has `clonedFrom: omarchy.lock`
so the shell swaps them and everything that locks the screen keeps working). Disable or remove
the plugin to get the stock lock screen back.

## Usage

```sh
omarchy-shell lock explore
```

Arrows to browse, Space for full-size preview, Enter to select, Esc to close.

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
omarchy-shell lock previewDesign split
omarchy-shell lock hidePreview
```

The selected design is saved on the plugin entry in `~/.config/omarchy/shell.json`.

## Adding a design

Copy one of the files in `designs/`, add it to `Designs.js`, run `omarchy restart shell`.

A design is a `DesignBase` item. It gets `passwordText`, `failureMessage`, `failedAttempts`,
`authenticatingPassword`, `fingerprintConfigured`, `inputEnabled`, a ticking `now`, `userName`,
`hostName` and `greeting()`. Use `PasswordField` for a normal input box or `LockInput` if you
want to draw the input yourself, and point `inputItem` at it so it gets focus.

## Development

```sh
omarchy plugin validate ~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer
qmllint -I "$OMARCHY_PATH/shell" ~/.config/omarchy/plugins/io.github.sirjul1337.lock-explorer/{*.qml,designs/*.qml}
omarchy restart shell
```
