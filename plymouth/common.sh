# shellcheck shell=bash
# Shared helpers for the Plymouth boot screen generators. Sourced, not run.
# Colors come from the active Omarchy theme so the boot screen matches the
# shell, the same way omarchy-plymouth-set-by-theme reads them.

omarchy_theme_dir="$HOME/.local/state/omarchy/current/theme"

# theme_color <key> [fallback-key] -> hex without '#', empty if neither is set
# or the value is not a plain hex color. Theme files are third-party input and
# these values end up inside generated scripts and privileged commands, so
# anything that is not hex is dropped here at the source.
theme_color() {
  awk -F= -v key="$1" -v fallback="${2:-}" '
    function clean(raw) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw)
      if (raw ~ /^"/) { sub(/^"/, "", raw); sub(/".*$/, "", raw) }
      sub(/^#/, "", raw)
      if (raw !~ /^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/) raw = ""
      return raw
    }
    {
      field = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
      if (field == key) { print clean($2); found = 1; exit }
      if (fallback != "" && field == fallback) fallback_value = clean($2)
    }
    END { if (!found && fallback_value != "") print fallback_value }
  ' "$omarchy_theme_dir/colors.toml"
}

# hex_floats aabbcc -> "0.667, 0.733, 0.800" (plymouth script color args)
hex_floats() {
  awk -v h="$1" 'BEGIN {
    printf "%.3f, %.3f, %.3f",
      strtonum("0x" substr(h,1,2)) / 255,
      strtonum("0x" substr(h,3,2)) / 255,
      strtonum("0x" substr(h,5,2)) / 255
  }'
}

# hex_ints aabbcc -> "170,187,204" (magick rgba() args)
hex_ints() {
  awk -v h="$1" 'BEGIN {
    printf "%d,%d,%d",
      strtonum("0x" substr(h,1,2)),
      strtonum("0x" substr(h,3,2)),
      strtonum("0x" substr(h,5,2))
  }'
}

# mix_hex <a> <b> <t> -> a blended toward b by t (0..1), e.g. dim text on bg
mix_hex() {
  awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN {
    for (i = 1; i <= 5; i += 2) {
      v = strtonum("0x" substr(a,i,2)) * (1-t) + strtonum("0x" substr(b,i,2)) * t
      printf "%02x", int(v + 0.5)
    }
  }'
}

# darker_hex <hex> <factor> -> Qt.darker equivalent (divide by factor)
darker_hex() {
  awk -v h="$1" -v f="$2" 'BEGIN {
    for (i = 1; i <= 5; i += 2) printf "%02x", int(strtonum("0x" substr(h,i,2)) / f + 0.5)
  }'
}

# The monospace family the theme resolves to; plymouth's label plugin gets the
# same name via the Font= line so the initramfs embeds the right file.
mono_font_family() {
  fc-match -f '%{family}' monospace | cut -d, -f1
}

# write_theme_ini <staging> <bg-hex> <family> — the .plymouth for the
# omarchy-boot slot every generator installs into.
write_theme_ini() {
  cat > "$1/omarchy-boot.plymouth" <<EOF
[Plymouth Theme]
Name=Omarchy Boot (Lock Explorer)
Description=Boot screen twin of a lock screen design from omarchy-lock-explorer.
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/omarchy-boot
ScriptFile=/usr/share/plymouth/themes/omarchy-boot/omarchy-boot.script
ConsoleLogBackgroundColor=0x$2
Font=$3 15
MonospaceFont=$3 15
EOF
}
