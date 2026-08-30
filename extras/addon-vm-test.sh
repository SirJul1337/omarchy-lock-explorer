#!/bin/bash
# Prove the NO-REBUILD boot-design mechanism: deliver a Plymouth theme as a
# systemd-stub initrd ADDON instead of rebuilding the initramfs.
#
# Boots the REAL chain in QEMU — OVMF firmware → Limine (protocol: efi) →
# the host's actual, untouched UKI — with the theme sitting next to it as
#   EFI/Linux/omarchy_linux.efi.extra.d/theme.addon.efi
# systemd-stub concatenates the addon's .initrd section AFTER the UKI's
# embedded initrd, so the addon's files override the baked-in theme.
# Nothing on the host is touched; working files live in
# ~/.cache/omarchy-lock-explorer/addonvm. Passphrase of the throwaway LUKS
# disk: omarchy.
#
#   extras/addon-vm-test.sh "$(plymouth/apply.sh terminal --stage-only)"
#   extras/addon-vm-test.sh <theme-dir> headless   # monitor socket on mon.sock
#
# Headless driving:
#   echo 'screendump shot.ppm' | socat - unix-connect:mon.sock
#   echo 'sendkey o'           | socat - unix-connect:mon.sock
set -euo pipefail
work="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-lock-explorer/addonvm"; mkdir -p "$work"; cd "$work"

THEME_DIR="$(realpath "${1:?usage: addon-vm-test.sh <theme-dir> [headless]}")"
MODE="${2:-window}"
THEME_NAME="$(basename "$THEME_DIR"/*.plymouth .plymouth)"
UKI=/boot/EFI/Linux/omarchy_linux.efi
STUB=/usr/lib/systemd/boot/efi/addonx64.efi.stub

# 1. Overlay: theme + plymouthd.conf switch + font override (label-freetype in
#    the initramfs only knows /usr/share/fonts/Plymouth*.ttf)
rm -rf overlay extra.cpio
install -d overlay/usr/share/plymouth/themes/"$THEME_NAME" overlay/etc/plymouth overlay/usr/share/fonts
cp "$THEME_DIR"/* overlay/usr/share/plymouth/themes/"$THEME_NAME"/
printf '[Daemon]\nTheme=%s\n' "$THEME_NAME" > overlay/etc/plymouth/plymouthd.conf
font=$(fc-match -f %{file} 'JetBrainsMono Nerd Font')
cp "$font" overlay/usr/share/fonts/Plymouth.ttf
cp "$font" overlay/usr/share/fonts/Plymouth-monospace.ttf
(cd overlay && find . -mindepth 1 | cpio -o -H newc -R 0:0 --quiet) > extra.cpio

# 2. Addon PE: the shipped addon stub + our cpio as its .initrd section.
#    (ukify would do this too; objcopy keeps it dependency-free. The .initrd
#    VMA must land on the first SectionAlignment boundary past the last
#    existing section or the stub's PE parser rejects it.)
vma=$(objdump -h "$STUB" | awk '$2 ~ /^\./ { end = strtonum("0x"$4) + strtonum("0x"$3) }
  END { printf "0x%x", and(end + 0xfff, compl(0xfff)) }')
objcopy --add-section .initrd=extra.cpio --change-section-vma .initrd="$vma" \
  "$STUB" theme.addon.efi

# 3. ESP as a plain directory, served to QEMU by the vvfat driver: Limine as
#    the removable-media bootloader, the host UKI copied verbatim, the addon
#    in its extra.d.
rm -rf esp
install -d esp/EFI/BOOT esp/EFI/Linux/omarchy_linux.efi.extra.d
cp /usr/share/limine/BOOTX64.EFI esp/EFI/BOOT/BOOTX64.EFI
cp --no-preserve=mode,ownership "$UKI" esp/EFI/Linux/omarchy_linux.efi
cp theme.addon.efi esp/EFI/Linux/omarchy_linux.efi.extra.d/theme.addon.efi
cat > esp/limine.conf <<'EOF'
timeout: 0

/Omarchy (addon test)
protocol: efi
path: boot():/EFI/Linux/omarchy_linux.efi
cmdline: cryptdevice=/dev/vda:root root=/dev/vdb rw quiet splash loglevel=0 systemd.show_status=false rd.udev.log_level=0 vt.global_cursor_default=0 initramfs_async=0
EOF

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

exec qemu-system-x86_64 -enable-kvm -cpu host -m 4096 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=ovmf_vars.fd \
  -drive file=fat:rw:esp,if=ide \
  -drive file=luks.img,format=raw,if=virtio \
  -drive file=rootfs.img,format=raw,if=virtio \
  -vga std -serial none -no-reboot "${display_args[@]}"
# NB: -serial none is load-bearing. With a serial port present, Limine appends
# "console=uart,io,0x3f8" to the cmdline it hands the UKI, and an active
# serial console makes plymouth drop to text/details mode — the splash never
# shows even though everything else works. Real hardware has no such console.
