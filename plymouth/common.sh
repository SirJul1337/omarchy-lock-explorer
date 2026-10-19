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

# layout_val <conf> <key> <default>: one key of a boot design layout
# (~/.config/omarchy/boot-designs/*.conf), held to the pattern its key allows.
# These values end up inside generated Plymouth script and lock design QML,
# in magick arguments and in shell arithmetic, and a layout is a file anyone
# can hand over, so anything off the pattern -- or an unknown key -- gives
# the default instead. Nothing is escaped; nothing that would need it passes.
layout_val() {
  local conf="$1" key="$2" default="$3" v re
  # The first match only, from at most 64 KiB of a regular file.
  [[ -f $conf && ! -L $conf ]] || { printf '%s' "$default"; return; }
  v=$(head -c 65536 -- "$conf" | awk -F= -v k="$key" '
    /^[ \t]*#/ { next }
    { name = $1; gsub(/^[ \t]+|[ \t]+$/, "", name)
      if (name == k) { sub(/^[^=]*=/, ""); gsub(/^[ \t\r]+|[ \t\r]+$/, ""); print; exit } }')
  case $key in
    logo_y | title_y | subtitle_y | entry_y | entry_x | entry_wp | entry_hp)
      re='^-?[0-9]{1,4}(\.[0-9]{1,3})?$' ;;
    logo_height | title_size | subtitle_size | entry_width)
      re='^[0-9]{1,4}$' ;;
    scanlines | clock) re='^(on|off)$' ;;
    entry) re='^(pill|line|none|embedded)$' ;;
    entry_align) re='^(left|center|right)$' ;;
    title_color | subtitle_color)
      re='^(foreground|accent|dim|background|#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?)$' ;;
    background)
      re='^(theme|wallpaper|#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?|/[A-Za-z0-9._/@+ -]{1,255})$' ;;
    logo) re='^(theme|none|/[A-Za-z0-9._/@+ -]{1,255})$' ;;
    background_plain) re='^/[A-Za-z0-9._/@+ -]{1,255}$' ;;
    # Text: no quote, backslash, backtick or control character, at most 80
    # characters, and no leading @ (magick -annotate reads @file).
    title | subtitle | hint) re='^([^@"\`[:cntrl:]][^"\`[:cntrl:]]{0,79})?$' ;;
    *) re='' ;;
  esac
  if [[ -n $v && -n $re && $v =~ $re && $v != *..* ]]; then
    printf '%s' "$v"
  else
    printf '%s' "$default"
  fi
}

# layout_text <string>: a layout text after $USER/$HOST expansion, held to
# the same pattern as the raw text (an account or host name could carry
# anything the pattern refuses); empty when it does not fit.
layout_text() {
  local re='^([^@"\`[:cntrl:]][^"\`[:cntrl:]]{0,95})?$'
  if [[ $1 =~ $re ]]; then printf '%s' "$1"; fi
}

# image_in <file>: the file as a magick input with its decoder named after
# the file's own signature -- PNG, JPEG, WebP or GIF -- so magick never picks
# a coder from what the content claims to be (SVG, MSL, text: and the like
# can read other files). Prints nothing, and fails, for anything else.
image_in() {
  local f="$1" sig
  [[ -f $f ]] || return 1
  sig=$(head -c 12 -- "$f" | od -An -tx1 | tr -d ' \n')
  case $sig in
    89504e470d0a1a0a*) printf 'png:%s' "$f" ;;
    ffd8ff*) printf 'jpeg:%s' "$f" ;;
    52494646????????57454250) printf 'webp:%s' "$f" ;;
    474946383761* | 474946383961*) printf 'gif:%s' "$f" ;;
    *) return 1 ;;
  esac
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
  # Lands inside script strings; a family name off the pattern falls back.
  local family
  family=$(fc-match -f '%{family}' monospace | cut -d, -f1)
  [[ $family =~ ^[A-Za-z0-9\ ._-]{1,64}$ ]] || family=monospace
  printf '%s
' "$family"
}

# The boot-chrome contract: plymouthd runs the applied theme on the way down
# too (plymouth-reboot.service and friends), where no passphrase prompt ever
# fires. Generators must keep all passphrase chrome -- entry, bullets,
# placeholders, hints -- hidden until display_password_callback actually
# fires; that also keeps dead entry boxes off boots that never prompt. Work
# that must not happen on the way down at all (frame preloads, boxed
# backgrounds) hangs off the gate fragment below.

# emit_downward_gate <name> — plymouth-script fragment that sets global.<name>
# to 0 when the theme runs on the way down (reboot/poweroff), 1 otherwise.
emit_downward_gate() {
  cat <<EOF
mode = Plymouth.GetMode();
global.$1 = 1;
if (mode == "reboot" || mode == "shutdown") global.$1 = 0;
EOF
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
