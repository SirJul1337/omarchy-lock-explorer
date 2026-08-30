#!/bin/bash
# Boot the machine's real kernel + initramfs in QEMU against a throwaway LUKS
# disk (passphrase: omarchy), with a staged Plymouth theme overlaid on top of
# the initramfs. Nothing on the host is touched; working files live in
# ~/.cache/omarchy-lock-explorer/bootvm. Needs qemu-system-x86, edk2-ovmf and
# qemu-ui-gtk for the window mode.
#
#   extras/boot-vm-test.sh "$(plymouth/apply.sh terminal --stage-only)"
#   extras/boot-vm-test.sh <theme-dir> headless   # monitor socket on mon.sock
#
# Headless driving:
#   echo 'screendump shot.ppm' | socat - unix-connect:mon.sock
#   echo 'sendkey o'           | socat - unix-connect:mon.sock
set -euo pipefail
work="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-lock-explorer/bootvm"; mkdir -p "$work"; cd "$work"

THEME_DIR="$(realpath "${1:?usage: run-vm.sh <theme-dir> [headless]}")"
MODE="${2:-window}"
THEME_NAME="$(basename "$THEME_DIR"/*.plymouth .plymouth)"
UKI=/boot/EFI/Linux/omarchy_linux.efi

# 1. Extract kernel + initramfs from the UKI (cached until the UKI changes)
if [[ ! -f vmlinuz || ! -f main.cpio || $UKI -nt vmlinuz ]]; then
  objcopy --dump-section .linux=vmlinuz --dump-section .initrd=initrd.orig "$UKI" /dev/null 2>/dev/null || true
  python3 - <<'EOF'
d = open('initrd.orig', 'rb').read()
i = d.find(b'TRAILER!!!')
# skip trailing NULs of the early (microcode/firmware) cpio, then find the
# zstd frame that holds the main image
j = i + len('TRAILER!!!')
while d[j] == 0:
    j += 1
assert d[j:j+4] == bytes.fromhex('28b52ffd'), 'expected zstd magic'
open('early.cpio', 'wb').write(d[:j])
open('main.zst', 'wb').write(d[j:])
EOF
  zstd -dqf main.zst -o main.cpio
fi

# 2. Overlay: theme + plymouthd.conf + font override (label-freetype in the
#    initramfs only knows /usr/share/fonts/Plymouth*.ttf)
rm -rf overlay extra.cpio
install -d overlay/usr/share/plymouth/themes/"$THEME_NAME" overlay/etc/plymouth overlay/usr/share/fonts
cp "$THEME_DIR"/* overlay/usr/share/plymouth/themes/"$THEME_NAME"/
sed -i "s|^ImageDir=.*|ImageDir=/usr/share/plymouth/themes/$THEME_NAME|;s|^ScriptFile=.*|ScriptFile=/usr/share/plymouth/themes/$THEME_NAME/$THEME_NAME.script|" \
  overlay/usr/share/plymouth/themes/"$THEME_NAME"/"$THEME_NAME".plymouth
printf '[Daemon]\nTheme=%s\n' "$THEME_NAME" > overlay/etc/plymouth/plymouthd.conf
font=$(fc-match -f %{file} 'JetBrainsMono Nerd Font')
cp "$font" overlay/usr/share/fonts/Plymouth.ttf
cp "$font" overlay/usr/share/fonts/Plymouth-monospace.ttf
(cd overlay && find . -mindepth 1 | cpio -o -H newc -R 0:0 --quiet) > extra.cpio

# 3. All-uncompressed concatenation: kernel unpacks each cpio in order and
#    later entries win, so the overlay replaces the stock theme config
cat early.cpio main.cpio extra.cpio > test-initrd.img

# 4. Throwaway LUKS disk (passphrase: omarchy)
if [[ ! -f luks.img ]]; then
  truncate -s 64M luks.img
  echo -n omarchy | cryptsetup luksFormat --type luks2 --pbkdf pbkdf2 --pbkdf-force-iterations 1000 -q luks.img -
fi

# 5. Tiny root so boot continues quietly after the unlock instead of dropping
#    to the emergency shell, which would cut the splash off after a second.
if [[ ! -f rootfs.img ]] && command -v gcc >/dev/null 2>&1; then
  printf '#include <unistd.h>\nint main(void){for(;;)pause();}\n' > pause.c
  gcc -static -Os -o pause-init pause.c
  mkdir -p rootfs/sbin && cp pause-init rootfs/sbin/init
  truncate -s 16M rootfs.img
  mkfs.ext4 -q -d rootfs rootfs.img
fi

[[ -f ovmf_vars.fd ]] || cp /usr/share/edk2/x64/OVMF_VARS.4m.fd ovmf_vars.fd

display_args=(-display gtk)
[[ $MODE == headless ]] && display_args=(-display none -monitor unix:mon.sock,server,nowait)

# With rootfs.img present, boot continues into a tiny do-nothing root after
# the unlock instead of hitting the emergency shell (which would kill the
# splash) — needed for themes with an unlock animation.
root_args=(root=/dev/mapper/root)
extra_drives=()
if [[ -f rootfs.img ]]; then
  root_args=(root=/dev/vdb)
  extra_drives=(-drive file=rootfs.img,format=raw,if=virtio)
fi

exec qemu-system-x86_64 -enable-kvm -cpu host -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=ovmf_vars.fd \
  -kernel vmlinuz -initrd test-initrd.img \
  -append "cryptdevice=/dev/vda:root ${root_args[*]} rw quiet splash loglevel=0 systemd.show_status=false rd.udev.log_level=0 vt.global_cursor_default=0" \
  -drive file=luks.img,format=raw,if=virtio \
  "${extra_drives[@]}" \
  -vga std -serial file:serial.log -no-reboot "${display_args[@]}"
