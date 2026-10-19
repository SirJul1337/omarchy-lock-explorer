#!/bin/bash
# Tests for plymouth/root-theme.sh: what root accepts from a staged boot theme
# and what it writes in place of the theme's .plymouth. A theme names the
# Plymouth plugin root loads, so the .plymouth root installs has to be root's
# own and every other file has to be one a generator makes.
#
# Run it directly: extras/test-root-theme.sh
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=plymouth/root-theme.sh
source "$here/../plymouth/root-theme.sh"
# shellcheck source=plymouth/common.sh
source "$here/../plymouth/common.sh"

root=$(mktemp -d) || exit 1
trap 'rm -rf "$root"' EXIT

pass=0; fail_count=0
ok()  { pass=$((pass + 1));             printf '  ok   %s\n' "$1"; }
bad() { fail_count=$((fail_count + 1)); printf '  FAIL %s\n' "$1"; }

# A 1x1 PNG, so the fixtures carry the real signature without needing magick.
python3 - "$root/pixel.png" <<'PY'
import struct, sys, zlib
def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)) \
    + chunk(b"IDAT", zlib.compress(b"\x00\x00\x00\x00\x00")) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY

# boot_theme DIR: what the generators stage for the omarchy-boot slot.
boot_theme() {
  mkdir -p "$1"
  cp "$root/pixel.png" "$1/bg.png"; cp "$root/pixel.png" "$1/preview.png"
  echo 'Window.SetBackgroundTopColor(0, 0, 0);' > "$1/omarchy-boot.script"
  echo terminal > "$1/design"
  write_theme_ini "$1" 1a1b26 "JetBrainsMono Nerd Font"
}

# stock_theme DIR: the shape of Omarchy's default/plymouth, logos/ included.
stock_theme() {
  mkdir -p "$1/logos"
  cp "$root/pixel.png" "$1/logo.png"; cp "$root/pixel.png" "$1/logos/arch.png"
  echo 'Window.SetBackgroundTopColor(0, 0, 0);' > "$1/omarchy.script"
  printf '[Plymouth Theme]\nName=Omarchy\nDescription=Omarchy splash screen.\nModuleName=script\n\n[script]\nImageDir=/usr/share/plymouth/themes/omarchy\nScriptFile=/usr/share/plymouth/themes/omarchy/omarchy.script\nConsoleLogBackgroundColor=0x1a1b26\nMonospaceFont=Cantarell 11\nFont=Cantarell 11\n' > "$1/omarchy.plymouth"
}

n=0
fresh() { n=$((n + 1)); d="$root/t$n"; "$1" "$d"; }

accepts() { # accepts DESC DIR SLOT
  if seal_theme "$2" "$3"; then ok "$1"; else bad "$1 (refused)"; fi
}
refuses() { # refuses DESC DIR SLOT
  if seal_theme "$2" "$3"; then bad "$1 (accepted)"; else ok "$1"; fi
}
ini_is() { # ini_is DESC FILE EXPECTED
  if [[ $(cat "$2") == "$3" ]]; then ok "$1"; else bad "$1"; printf '%s\n' "$(cat "$2")" | sed 's/^/         /'; fi
}

echo "root-theme tests"

# --- what the plugin makes goes through, with root's own .plymouth ----------
fresh boot_theme
accepts "a generated boot theme" "$d" omarchy-boot
ini_is "its .plymouth is root's, colour and fonts kept" "$d/omarchy-boot.plymouth" "[Plymouth Theme]
Name=Omarchy Boot (Lock Explorer)
Description=Boot screen twin of a lock screen design from omarchy-lock-explorer.
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/omarchy-boot
ScriptFile=/usr/share/plymouth/themes/omarchy-boot/omarchy-boot.script
ConsoleLogBackgroundColor=0x1a1b26
Font=JetBrainsMono Nerd Font 15
MonospaceFont=JetBrainsMono Nerd Font 15"

fresh stock_theme
accepts "the stock theme, with its logos/ directory" "$d" omarchy
grep -qx 'ModuleName=script' "$d/omarchy.plymouth" && grep -qx 'Font=Cantarell 11' "$d/omarchy.plymouth" &&
  ok "stock .plymouth rewritten the same way" || bad "stock .plymouth rewritten the same way"

# --- the finding: the theme picking the plugin root loads -------------------
fresh boot_theme
sed -i 's|^ModuleName=.*|ModuleName=../../../usr/share/plymouth/themes/omarchy-boot/evil|' "$d/omarchy-boot.plymouth"
accepts "a relative ModuleName is not refused but overwritten" "$d" omarchy-boot
grep -qx 'ModuleName=script' "$d/omarchy-boot.plymouth" && ! grep -q evil "$d/omarchy-boot.plymouth" &&
  ok "... to the script plugin" || bad "... to the script plugin"

fresh boot_theme
printf '\x7fELF\x02\x01\x01' > "$d/evil.so"
refuses "a shared library in the theme" "$d" omarchy-boot

fresh boot_theme
printf '\x7fELF\x02\x01\x01' > "$d/evil.png"
refuses "a library named .png" "$d" omarchy-boot

fresh boot_theme
mkdir -p "$d/lib"; printf '\x7fELF\x02\x01\x01' > "$d/lib/script.so"
refuses "a library in a subdirectory" "$d" omarchy-boot

fresh boot_theme
echo hi > "$d/readme.txt"
refuses "any other file" "$d" omarchy-boot

# --- the paths and values root writes ---------------------------------------
fresh boot_theme
sed -i 's|^ImageDir=.*|ImageDir=/root|; s|^ScriptFile=.*|ScriptFile=/home/u/x.script|' "$d/omarchy-boot.plymouth"
seal_theme "$d" omarchy-boot
grep -qx 'ImageDir=/usr/share/plymouth/themes/omarchy-boot' "$d/omarchy-boot.plymouth" &&
  grep -qx 'ScriptFile=/usr/share/plymouth/themes/omarchy-boot/omarchy-boot.script' "$d/omarchy-boot.plymouth" &&
  ok "ImageDir and ScriptFile pinned to the slot" || bad "ImageDir and ScriptFile pinned to the slot"

fresh boot_theme
sed -i 's|^Font=.*|Font=x; rm -rf / 15|; s|^ConsoleLogBackgroundColor=.*|ConsoleLogBackgroundColor=red|' "$d/omarchy-boot.plymouth"
printf '[Daemon]\nTheme=other\n' >> "$d/omarchy-boot.plymouth"
seal_theme "$d" omarchy-boot
! grep -qE '^(Font=|ConsoleLogBackgroundColor=|\[Daemon\]|Theme=)' "$d/omarchy-boot.plymouth" &&
  ok "values off the pattern and extra sections dropped" || bad "values off the pattern and extra sections dropped"

# --- shape ------------------------------------------------------------------
fresh boot_theme
refuses "an unknown slot" "$d" ../evil
fresh boot_theme
rm "$d/omarchy-boot.script"
refuses "a theme without its script" "$d" omarchy-boot
fresh boot_theme
head -c 300 /dev/zero > "$d/design"
refuses "an oversized design marker" "$d" omarchy-boot
fresh boot_theme
head -c 5000 /dev/zero | tr '\0' '#' >> "$d/omarchy-boot.plymouth"
refuses "an oversized .plymouth" "$d" omarchy-boot
fresh boot_theme
ln -s /etc/passwd "$d/link.png"
refuses "a symlink" "$d" omarchy-boot

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ $fail_count -eq 0 ]]
