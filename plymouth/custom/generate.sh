#!/bin/bash
# Generic boot screen generator for user made layouts: a small key = value
# format (see template.conf) describing background, logo, texts and the entry
# field, rendered both as a Plymouth theme and as the preview the explorer's
# editor shows. Everything is horizontally centered; vertical positions are
# percentages of the screen.
#
# Usage: generate.sh <staging-dir> <layout.conf> [id]
set -euo pipefail
source "$(dirname "$(realpath "$0")")/../common.sh"

staging="${1:?usage: generate.sh <staging-dir> <layout.conf> [id]}"
conf="${2:?missing layout.conf}"
id="${3:-custom:$(basename "$conf" .conf)}"

[[ -f $conf ]] || { echo "No such layout: $conf" >&2; exit 1; }
mkdir -p "$staging"

conf_get() {
  awk -F= -v k="$1" '
    /^[ \t]*#/ { next }
    {
      key = $1; gsub(/^[ \t]+|[ \t]+$/, "", key)
      if (key == k) {
        sub(/^[^=]*=/, ""); gsub(/^[ \t]+|[ \t]+$/, "")
        print; exit
      }
    }' "$conf"
}
val() { local v; v=$(conf_get "$1"); printf '%s' "${v:-$2}"; }

bg_t=$(theme_color background); fg_t=$(theme_color foreground)
accent_t=$(theme_color accent blue); [[ -n $accent_t ]] || accent_t=$fg_t
dim_t=$(mix_hex "$bg_t" "$fg_t" 0.55)
family=$(mono_font_family)
host=$(hostname); user="$USER"

expand_vars() { local s=${1//'$USER'/$user}; printf '%s' "${s//'$HOST'/$host}"; }
resolve_color() {
  case "$1" in
    foreground) printf '%s' "$fg_t" ;;
    accent)     printf '%s' "$accent_t" ;;
    dim)        printf '%s' "$dim_t" ;;
    background) printf '%s' "$bg_t" ;;
    '#'*)       printf '%s' "${1#\#}" ;;
    *)          printf '%s' "$fg_t" ;;
  esac
}

background=$(val background theme)
scanlines=$(val scanlines off)
logo=$(val logo none);            logo_y=$(val logo_y 36);        logo_h=$(val logo_height 120)
title=$(expand_vars "$(val title "")");        title_y=$(val title_y 18)
title_size=$(val title_size 26);  title_c=$(resolve_color "$(val title_color foreground)")
subtitle=$(expand_vars "$(val subtitle "")");  subtitle_y=$(val subtitle_y 26)
subtitle_size=$(val subtitle_size 15); subtitle_c=$(resolve_color "$(val subtitle_color dim)")
entry=$(val entry pill);          entry_y=$(val entry_y 72);      entry_w=$(val entry_width 380)
# "embedded" entry: the input box is part of the background image (a design
# snapshot); bullets go inside the rect given in percent of the screen,
# aligned the way the design aligns its own dots.
entry_x=$(val entry_x 50);        entry_wp=$(val entry_wp 0);     entry_hp=$(val entry_hp 0)
entry_align=$(val entry_align center)
hint=$(expand_vars "$(val hint "")")

accent_i=$(hex_ints "$accent_t"); bg_i=$(hex_ints "$bg_t")
fg_f=$(hex_floats "$fg_t"); dim_f=$(hex_floats "$dim_t"); bg_f=$(hex_floats "$bg_t")
title_f=$(hex_floats "$title_c"); subtitle_f=$(hex_floats "$subtitle_c")

# ------------------------------------------------ assets
case "$background" in
  theme) : ;;
  wallpaper)
    link="$HOME/.local/state/omarchy/current/background"
    if [[ -e $link ]]; then
      magick "$(readlink -f "$link")" -resize 1920x1080^ -gravity center -extent 1920x1080 \
        -blur 0x12 -fill black -colorize 40 "$staging/bg.png"
    fi ;;
  '#'*) magick -size 64x64 "xc:$background" "$staging/bg.png" ;;
  *) [[ -f $background ]] && magick "$background" -resize 1920x1080^ -gravity center -extent 1920x1080 "$staging/bg.png" ;;
esac

[[ $scanlines == on ]] && magick -size 8x3 xc:none -fill 'rgba(0,0,0,0.12)' -draw 'rectangle 0,2 7,2' "$staging/scanline.png"

case "$logo" in
  none) : ;;
  theme) [[ -f "$HOME/.local/state/omarchy/current/theme/unlock.png" ]] && cp "$HOME/.local/state/omarchy/current/theme/unlock.png" "$staging/logo.png" ;;
  *) [[ -f $logo ]] && cp "$logo" "$staging/logo.png" ;;
esac

case "$entry" in
  pill) magick -size "${entry_w}x50" xc:none -draw "fill rgba($bg_i,0.55) stroke rgba($accent_i,0.5) stroke-width 1 roundrectangle 1,1 $((entry_w - 2)),48 25,25" "$staging/entry.png" ;;
  line) magick -size "${entry_w}x50" xc:none -draw "fill rgba($accent_i,0.8) rectangle 0,48 $entry_w,50" "$staging/entry.png" ;;
esac

# Spinner frames for the wait after the passphrase. Pre-rendered images, not
# Image.Text: label rendering needs the font file, which is gone once
# switch_root drops the initramfs -- decoded images survive.
if [[ $entry != none ]]; then
  fg_i=$(hex_ints "$fg_t")
  # Loading: a rotating arc, clearly distinct from the passphrase bullets.
  # Pre-rendered frames -- text and font rendering die after switch_root.
  for i in $(seq 1 12); do
    a=$(( (i - 1) * 30 ))
    magick -size 22x22 xc:none -stroke "rgba($fg_i,0.95)" -strokewidth 3 -fill none \
      -draw "ellipse 11,11 8,8 $a,$((a + 120))" "$staging/spin$i.png"
  done
  # One passphrase bullet; the script draws one sprite per typed character,
  # so the row aligns exactly inside the entry box.
  magick -size 14x14 xc:none -fill "rgba($fg_i,0.95)" -draw "circle 7,7 7,2" "$staging/dot.png"
fi

write_theme_ini "$staging" "$bg_t" "$family"
printf '%s\n' "$id" > "$staging/design"

# A bg.png with the design's own input box painted in: any snapshot target
# (the explorer's grab keeps the box even when apply.sh falls back to a pill
# entry), or an embedded entry declared in the conf. Such a background must
# not sit on the reboot/shutdown splash looking like a live prompt, so the
# script gets hooks to show it only when a prompt can actually arrive.
bg_has_box=""
if [[ -f $staging/bg.png && ($id == snapshot:* || ($entry != none && ! -f $staging/entry.png)) ]]; then
  bg_has_box=1
fi
bg_show=""; bg_rehide=""
if [[ -n $bg_has_box ]]; then
  bg_show="show_bg();"
  bg_rehide="if (global.bg_wanted == 0) bg.sprite.SetOpacity(0);"
fi
hint_show=""
[[ -n $hint && $entry != none ]] && hint_show="hint.sprite.SetOpacity(1);"

# ------------------------------------------------ plymouth script
{
cat <<EOF
# Custom boot layout ($id), generated by omarchy-lock-explorer.

fg.r = ${fg_f%%,*}; fg.g = $(echo "$fg_f" | cut -d, -f2); fg.b = $(echo "$fg_f" | cut -d, -f3);
dim.r = ${dim_f%%,*}; dim.g = $(echo "$dim_f" | cut -d, -f2); dim.b = $(echo "$dim_f" | cut -d, -f3);

Window.SetBackgroundTopColor(${bg_f});
Window.SetBackgroundBottomColor(${bg_f});

screen.w = Window.GetWidth();
screen.h = Window.GetHeight();
EOF

if [[ -n $bg_has_box ]]; then
cat <<'EOF'
# The design's input box is painted into bg.png itself, so no sprite toggle
# can remove just the box. On the way down (plymouthd --mode=reboot/shutdown)
# no prompt is expected: leave the image out and show the plain theme
# background. A prompt that does fire brings it back -- the bullets belong
# inside the painted box -- and loading lazily spares the decode entirely on
# a promptless shutdown.
bg.sprite = Sprite();
bg.sprite.SetPosition(0, 0, 0);
global.bg_loaded = 0;
fun show_bg() {
  if (global.bg_loaded == 0) {
    bg.sprite.SetImage(Image("bg.png").Scale(screen.w, screen.h));
    global.bg_loaded = 1;
  }
  bg.sprite.SetOpacity(1);
}
mode = Plymouth.GetMode();
global.bg_wanted = 1;
if (mode == "reboot" || mode == "shutdown") global.bg_wanted = 0;
if (global.bg_wanted == 1) show_bg();
EOF
elif [[ -f $staging/bg.png ]]; then
cat <<'EOF'
bg.sprite = Sprite(Image("bg.png").Scale(screen.w, screen.h));
bg.sprite.SetPosition(0, 0, 0);
EOF
fi

[[ -f $staging/scanline.png ]] && cat <<'EOF'
scan.sprite = Sprite(Image("scanline.png").Tile(screen.w, screen.h));
scan.sprite.SetPosition(0, 0, 1);
EOF

[[ -f $staging/logo.png ]] && cat <<EOF
logo.image = Image("logo.png");
logo.scaled = logo.image.Scale(logo.image.GetWidth() * $logo_h / logo.image.GetHeight(), $logo_h);
logo.sprite = Sprite(logo.scaled);
logo.sprite.SetPosition(screen.w / 2 - logo.scaled.GetWidth() / 2, screen.h * $logo_y / 100 - logo.scaled.GetHeight() / 2, 5);
EOF

[[ -n $title ]] && cat <<EOF
title.image = Image.Text("$title", $title_f, 1, "$family $title_size");
title.sprite = Sprite(title.image);
title.sprite.SetPosition(screen.w / 2 - title.image.GetWidth() / 2, screen.h * $title_y / 100 - title.image.GetHeight() / 2, 5);
EOF

[[ -n $subtitle ]] && cat <<EOF
subtitle.image = Image.Text("$subtitle", $subtitle_f, 1, "$family $subtitle_size");
subtitle.sprite = Sprite(subtitle.image);
subtitle.sprite.SetPosition(screen.w / 2 - subtitle.image.GetWidth() / 2, screen.h * $subtitle_y / 100 - subtitle.image.GetHeight() / 2, 5);
EOF

if [[ $entry != none ]]; then
if [[ -f $staging/entry.png ]]; then
cat <<EOF
entry.image = Image("entry.png");
entry.sprite = Sprite(entry.image);
entry.cx = screen.w * $entry_x / 100;
entry.cy = screen.h * $entry_y / 100;
entry.iw = entry.image.GetWidth() - 48;
entry.sprite.SetPosition(entry.cx - entry.image.GetWidth() / 2, entry.cy - entry.image.GetHeight() / 2, 5);

# Hidden until a passphrase prompt actually fires: plymouthd runs this theme
# for reboot/shutdown too (and for unencrypted boots), where a visible entry
# reads as a prompt that will never accept input.
entry.sprite.SetOpacity(0);
EOF
else
cat <<EOF
# Embedded entry: the input box is drawn in the background image already;
# only the bullets and the spinner go on top of it.
entry.sprite = Sprite();
entry.cx = screen.w * $entry_x / 100;
entry.cy = screen.h * $entry_y / 100;
entry.iw = screen.w * $entry_wp / 100;
EOF
fi
cat <<EOF

# One sprite per typed character, spread around the entry center, so the row
# is pixel-centered in the box both ways.
bullet.image = Image("dot.png");
for (i = 0; i < 24; i++) {
  bullets[i] = Sprite(bullet.image);
  bullets[i].SetOpacity(0);
}

fun hide_bullets() {
  for (i = 0; i < 24; i++) bullets[i].SetOpacity(0);
}

# After the passphrase is submitted the entry swaps for pulsing dots, so a
# slow unlock or a long boot does not look frozen. A wrong passphrase brings
# the entry straight back. Cross-callback state lives in global.* -- bare
# assignments inside script functions create locals.
global.prompt_seen = 0;
global.boot_wait = 0;
global.boot_frame = 0;
booting.sprite = Sprite();
booting.sprite.SetOpacity(0);
EOF
# Literal lines: plymouth script string+number concatenation is unreliable.
for i in $(seq 1 12); do echo "spin[$i] = Image(\"spin$i.png\");"; done
cat <<EOF

fun display_password_callback(prompt_text, count) {
  global.prompt_seen = 1;
  global.boot_wait = 0;
  $bg_show
  entry.sprite.SetOpacity(1);
  $hint_show
  booting.sprite.SetOpacity(0);
  if (count > 24) count = 24;
  step = bullet.image.GetWidth() + 8;
  align = "$entry_align";
  if (align == "left") x0 = entry.cx - entry.iw / 2;
  else if (align == "right") x0 = entry.cx + entry.iw / 2 - (count * step - 8);
  else x0 = entry.cx - (count * step - 8) / 2;
  for (i = 0; i < 24; i++) {
    if (i < count) {
      bullets[i].SetPosition(x0 + i * step, entry.cy - bullet.image.GetHeight() / 2, 6);
      bullets[i].SetOpacity(1);
    } else {
      bullets[i].SetOpacity(0);
    }
  }
}

fun display_normal_callback() {
  hide_bullets();
  $bg_rehide
  if (global.prompt_seen == 1) {
    global.boot_wait = 1;
    entry.sprite.SetOpacity(0);
    booting.sprite.SetOpacity(1);
  }
}

fun refresh_callback() {
  if (global.boot_wait == 1) {
    global.boot_frame = global.boot_frame + 1;
    k = Math.Int(global.boot_frame / 4);
    n = k - Math.Int(k / 12) * 12 + 1;
    b = spin[n];
    booting.sprite.SetImage(b);
    booting.sprite.SetPosition(entry.cx - b.GetWidth() / 2, entry.cy - b.GetHeight() / 2, 6);
  }
}

Plymouth.SetDisplayPasswordFunction(display_password_callback);
Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetRefreshFunction(refresh_callback);
EOF
fi

if [[ -n $hint ]]; then
cat <<EOF
hint.image = Image.Text("$hint", dim.r, dim.g, dim.b, 1, "$family 12");
hint.sprite = Sprite(hint.image);
hint.sprite.SetPosition(screen.w - hint.image.GetWidth() - 60, screen.h - hint.image.GetHeight() - 50, 5);
EOF
[[ $entry != none ]] && cat <<'EOF'
# Hidden until a prompt fires, like the entry it explains.
hint.sprite.SetOpacity(0);
EOF
fi

cat <<EOF

message_sprite = Sprite();
message_sprite.SetPosition(20, screen.h - 40, 6);

fun display_message_callback(text) {
  message_sprite.SetImage(Image.Text(text, dim.r, dim.g, dim.b, 1, "$family 12"));
  message_sprite.SetOpacity(1);
}

fun hide_message_callback(text) {
  message_sprite.SetOpacity(0);
}

Plymouth.SetDisplayMessageFunction(display_message_callback);
Plymouth.SetHideMessageFunction(hide_message_callback);
EOF
} > "$staging/omarchy-boot.script"

# ------------------------------------------------ preview (720x405 mirror)
pv=( -size 720x405 "xc:#$bg_t" )
[[ -f $staging/bg.png ]] && pv=( "$staging/bg.png" -resize '720x405^' -gravity center -extent 720x405 )
args=( magick "${pv[@]}" -gravity northwest )
[[ -f $staging/scanline.png ]] && args+=( \( -size 8x3 xc:none -fill 'rgba(0,0,0,0.12)' -draw 'rectangle 0,2 7,2' -write mpr:sc +delete -size 720x405 tile:mpr:sc \) -composite )
if [[ -f $staging/logo.png ]]; then
  lh=$(awk -v h="$logo_h" 'BEGIN{printf "%d", h * 0.375}')
  args+=( \( "$staging/logo.png" -resize x$lh \) -gravity north -geometry +0+$(awk -v y="$logo_y" -v h="$lh" 'BEGIN{printf "%d", 405*y/100 - h/2}') -composite )
fi
font_file=$(fc-match -f '%{file}' "$family")
if [[ -n $title ]]; then
  ts=$(awk -v s="$title_size" 'BEGIN{printf "%d", s*0.6 < 8 ? 8 : s*0.6}')
  args+=( -font "$font_file" -pointsize "$ts" -fill "#$title_c" -gravity north -annotate +0+$(awk -v y="$title_y" -v s="$ts" 'BEGIN{printf "%d", 405*y/100 - s/2}') "$title" )
fi
if [[ -n $subtitle ]]; then
  ss=$(awk -v s="$subtitle_size" 'BEGIN{printf "%d", s*0.6 < 7 ? 7 : s*0.6}')
  args+=( -font "$font_file" -pointsize "$ss" -fill "#$subtitle_c" -gravity north -annotate +0+$(awk -v y="$subtitle_y" -v s="$ss" 'BEGIN{printf "%d", 405*y/100 - s/2}') "$subtitle" )
fi
if [[ -f $staging/entry.png ]]; then
  ew=$(awk -v w="$entry_w" 'BEGIN{printf "%d", w*0.5}')
  args+=( \( "$staging/entry.png" -resize "${ew}x" \) -gravity north -geometry +0+$(awk -v y="$entry_y" 'BEGIN{printf "%d", 405*y/100 - 12}') -composite )
fi
[[ -n $hint ]] && args+=( -font "$font_file" -pointsize 8 -fill "#$dim_t" -gravity southeast -annotate +24+20 "$hint" )
args+=( "$staging/preview.png" )
"${args[@]}"
