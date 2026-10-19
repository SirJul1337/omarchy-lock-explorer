#!/bin/bash
# Tests for the boot layout reader (layout_val, layout_text) and image_in in
# plymouth/common.sh. A layout is a file anyone can hand over, and its values
# end up in generated Plymouth script, lock design QML, magick arguments and
# shell arithmetic, so everything off a key's pattern has to come back as the
# default.
#
# Run it directly: extras/test-layout-values.sh
set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=plymouth/common.sh
source "$here/../plymouth/common.sh"

root=$(mktemp -d) || exit 1
trap 'rm -rf "$root"' EXIT

pass=0; fail_count=0
ok()  { pass=$((pass + 1));             printf '  ok   %s\n' "$1"; }
bad() { fail_count=$((fail_count + 1)); printf '  FAIL %s\n' "$1"; }

conf="$root/layout.conf"
gives() { # gives DESC KEY VALUE DEFAULT EXPECTED
  printf '%s = %s\n' "$2" "$3" > "$conf"
  local got
  got=$(layout_val "$conf" "$2" "$4")
  if [[ $got == "$5" ]]; then ok "$1"; else bad "$1 (got '$got')"; fi
}

echo "layout value tests"

# --- ordinary values pass ---------------------------------------------------
gives "a number"                title_y 18 0 18
gives "a negative decimal"      entry_x -12.5 0 -12.5
gives "an integer size"         entry_width 380 0 380
gives "an enum"                 entry_align right center right
gives "a colour role"           title_color accent foreground accent
gives "a hex colour"            title_color '#1a1b26' foreground '#1a1b26'
gives "an image path"           background /home/u/Pictures/wall.png theme /home/u/Pictures/wall.png
gives "plain text"              title 'Omarchy Linux' '' 'Omarchy Linux'
gives "text with \$USER"        subtitle 'Hi $USER' '' 'Hi $USER'

# --- the injections the generators were open to ----------------------------
gives "arithmetic command"      entry_width 'x[$(touch /tmp/pwned)]' 380 380
gives "QML through a number"    title_y "1) + Qt.createQmlObject('x', lock) + (1" 18 18
gives "script through text"     title 'a"); Plymouth.SetQuitFunction(x); ("' '' ''
gives "backslash in text"       hint 'a\b' '' ''
gives "backtick in text"        hint 'a`id`b' '' ''
gives "@file for magick"        title '@/etc/passwd' '' ''
gives "QML through a colour"    title_color '#fff"; Component.onCompleted: x(); //' foreground foreground
gives "colour into background"  background '#fff" }' theme theme
gives "relative path"           logo 'Pictures/logo.png' none none
gives "path climbing out"       background '/home/u/../../etc/shadow' theme theme
gives "path with a quote"       logo '/home/u/a"b.png' none none
gives "an unknown key"          frobnicate 'anything' def def
gives "an enum off the list"    entry 'pill; rm -rf' pill pill
gives "overlong text"           title "$(printf 'x%.0s' {1..81})" '' ''

printf 'title = a\n' > "$conf"; printf 'title = b\n' >> "$conf"
[[ $(layout_val "$conf" title '') == a ]] && ok "first match wins" || bad "first match wins"
[[ $(layout_val "$root/missing.conf" title def) == def ]] && ok "a missing file gives the default" || bad "a missing file gives the default"
mkfifo "$root/fifo.conf"
got=$(timeout 5 bash -c 'source "$1"; layout_val "$2" title def' _ "$here/../plymouth/common.sh" "$root/fifo.conf")
[[ $got == def ]] && ok "a FIFO is not read" || bad "a FIFO is not read (got '$got')"
ln -s "$conf" "$root/link.conf"
[[ $(layout_val "$root/link.conf" title def) == def ]] && ok "a symlinked layout is not read" || bad "a symlinked layout is not read"

# --- layout_text after $USER/$HOST expansion --------------------------------
[[ $(layout_text 'Hello niklas') == 'Hello niklas' ]] && ok "expanded text passes" || bad "expanded text passes"
[[ -z $(layout_text 'evil"name') ]] && ok "an expanded quote empties it" || bad "an expanded quote empties it"

# --- image_in ---------------------------------------------------------------
printf '\x89PNG\r\n\x1a\n0000' > "$root/a.png"
printf '\xff\xd8\xff\xe0' > "$root/b.jpg"
printf 'RIFF0000WEBPVP8 ' > "$root/c.webp"
printf '<svg xmlns="http://www.w3.org/2000/svg"/>' > "$root/d.png"
printf '<?xml version="1.0"?><image><read filename="/etc/passwd"/></image>' > "$root/e.msl"
[[ $(image_in "$root/a.png") == "png:$root/a.png" ]] && ok "PNG decoded as png" || bad "PNG decoded as png"
[[ $(image_in "$root/b.jpg") == "jpeg:$root/b.jpg" ]] && ok "JPEG decoded as jpeg" || bad "JPEG decoded as jpeg"
[[ $(image_in "$root/c.webp") == "webp:$root/c.webp" ]] && ok "WebP decoded as webp" || bad "WebP decoded as webp"
image_in "$root/d.png" >/dev/null && bad "SVG named .png refused" || ok "SVG named .png refused"
image_in "$root/e.msl" >/dev/null && bad "MSL refused" || ok "MSL refused"
image_in "$root/none.png" >/dev/null && bad "missing file refused" || ok "missing file refused"

printf '\n%d passed, %d failed\n' "$pass" "$fail_count"
[[ $fail_count -eq 0 ]]
