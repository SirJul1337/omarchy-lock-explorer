# shellcheck shell=bash
# Root-side rules for a boot theme that came from the user's side, sourced by
# install-root.sh (and by extras/test-root-theme.sh). Not run on its own.
#
# Plymouth loads the plugin a theme names: ModuleName is joined onto the
# plugin directory and dlopen()ed by plymouthd, which runs as root on the way
# up and on the way down. So whoever writes the .plymouth file decides what
# native code root runs, and a relative ModuleName reaches a library shipped
# inside the theme itself. Nothing in a theme from the user's side is trusted
# for that: root writes the .plymouth itself, and builds the initrd addon
# itself, from a theme it has checked down to the file type.

plymouth_themes=/usr/share/plymouth/themes
addon_stub=/usr/lib/systemd/boot/efi/addonx64.efi.stub
png_magic=89504e470d0a1a0a

# seal_theme <dir> <slot>: <dir> is root's own unpacked copy of a theme for
# the omarchy-boot or omarchy slot. Every file has to be what the generators
# make: the slot's .plymouth and .script, the small `design` marker, and PNG
# images (checked by their signature, not their name). The .plymouth is then
# replaced with one root writes: the script plugin, ImageDir and ScriptFile
# pinned to the slot, and only the colour and font lines carried over, each
# held to a pattern. Returns non-zero, leaving the theme unusable, otherwise.
seal_theme() {
  local dir="$1" slot="$2" ini f rel bg font mono name desc
  case $slot in
    omarchy-boot)
      name="Omarchy Boot (Lock Explorer)"
      desc="Boot screen twin of a lock screen design from omarchy-lock-explorer." ;;
    omarchy)
      name="Omarchy"
      desc="Omarchy splash screen." ;;
    *) return 1 ;;
  esac
  ini="$dir/$slot.plymouth"
  [[ -f $ini && ! -L $ini && -f $dir/$slot.script && ! -L $dir/$slot.script ]] || return 1
  (( $(stat -c %s "$ini") <= 4096 )) || return 1

  while IFS= read -r -d '' f; do
    [[ -f $f && ! -L $f ]] || return 1
    rel=${f#"$dir"/}
    case $rel in
      "$slot.plymouth" | "$slot.script") ;;
      design) (( $(stat -c %s "$f") <= 256 )) || return 1 ;;
      *.png) [[ $(head -c 8 -- "$f" | od -An -tx1 | tr -d ' \n') == "$png_magic" ]] || return 1 ;;
      *) return 1 ;;
    esac
  done < <(find "$dir" -mindepth 1 ! -type d -print0)

  bg=$(sed -nE 's/^ConsoleLogBackgroundColor=(0x[0-9A-Fa-f]{6})[[:space:]]*$/\1/p' "$ini" | head -n 1)
  font=$(sed -nE 's/^Font=([A-Za-z0-9 ._-]{1,64} [0-9]{1,3})[[:space:]]*$/\1/p' "$ini" | head -n 1)
  mono=$(sed -nE 's/^MonospaceFont=([A-Za-z0-9 ._-]{1,64} [0-9]{1,3})[[:space:]]*$/\1/p' "$ini" | head -n 1)
  {
    printf '[Plymouth Theme]\nName=%s\nDescription=%s\nModuleName=script\n\n[script]\n' "$name" "$desc"
    printf 'ImageDir=%s\nScriptFile=%s\n' "$plymouth_themes/$slot" "$plymouth_themes/$slot/$slot.script"
    [[ -z $bg ]] || printf 'ConsoleLogBackgroundColor=%s\n' "$bg"
    [[ -z $font ]] || printf 'Font=%s\n' "$font"
    [[ -z $mono ]] || printf 'MonospaceFont=%s\n' "$mono"
  } > "$ini.sealed" || return 1
  mv -f "$ini.sealed" "$ini"
}

# build_addon <sealed theme dir> <out.efi>: wrap the theme as a systemd-stub
# initrd addon -- the theme, a plymouthd.conf naming it, and a system font
# under the names the initramfs' label plugin looks for. Everything in it is
# root's: the checked theme, a fixed config, a font from /usr/share/fonts and
# the stub systemd ships. An addon's initrd is laid over the image's own, so
# one built anywhere else could replace any file in it.
build_addon() {
  local theme="$1" out="$2" overlay font vma
  [[ -f $addon_stub ]] || return 1
  overlay=$(mktemp -d -p "$(dirname "$out")") || return 1
  install -d "$overlay/usr/share/plymouth/themes/omarchy-boot" \
    "$overlay/etc/plymouth" "$overlay/usr/share/fonts" || return 1
  cp -r --no-preserve=mode,ownership "$theme/." "$overlay/usr/share/plymouth/themes/omarchy-boot/" || return 1
  printf '[Daemon]\nTheme=omarchy-boot\n' > "$overlay/etc/plymouth/plymouthd.conf"
  font=$(fc-match -f '%{file}' 'JetBrainsMono Nerd Font' 2>/dev/null || true)
  if [[ $font == /usr/share/fonts/* && -f $font && ! -L $font ]]; then
    cp "$font" "$overlay/usr/share/fonts/Plymouth.ttf"
    cp "$font" "$overlay/usr/share/fonts/Plymouth-monospace.ttf"
  fi
  find "$overlay" -mindepth 1 \( -type d -exec chmod 0755 {} + \) -o \( -type f -exec chmod 0644 {} + \)
  (cd "$overlay" && find . -mindepth 1 | LC_ALL=C sort | cpio -o -H newc -R 0:0 --quiet) > "$overlay.cpio" || return 1
  vma=$(objdump -h "$addon_stub" | awk '$2 ~ /^\./ { end = strtonum("0x"$4) + strtonum("0x"$3) }
    END { printf "0x%x", and(end + 0xfff, compl(0xfff)) }')
  objcopy --add-section .initrd="$overlay.cpio" --change-section-vma .initrd="$vma" \
    "$addon_stub" "$out" || return 1
  rm -rf "$overlay" "$overlay.cpio"
}
