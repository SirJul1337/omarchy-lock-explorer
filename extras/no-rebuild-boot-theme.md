# Changing Omarchy's LUKS boot screen without rebuilding the initramfs

**Status: mechanism proven end-to-end in a VM against the real, untouched host
UKI** (see `addon-vm-test.sh`, 2026-08-24).

## The wrong assumption

"The boot decrypt screen is baked into the encrypted disk, so it can't be
changed without rebuilding" is only half right. The Plymouth theme *is* baked
into the initramfs — but the initramfs lives inside the UKI at
`/boot/EFI/Linux/omarchy_linux.efi`, which sits on the **unencrypted ESP**
(firmware has to read it before LUKS is unlocked). What made theme changes
expensive was never encryption; it was that the UKI is a packed archive that
`limine-mkinitcpio` regenerates as a whole (~30s).

## The mechanism: systemd-stub initrd addons

Omarchy's boot chain is:

    OVMF/firmware → Limine (`protocol: efi`) → omarchy_linux.efi (systemd-stub UKI)

systemd-stub (v256+, Omarchy currently ships 261) loads **companion addons**
from the ESP next to the UKI, with no signature requirement while Secure Boot
is disabled (Omarchy's default):

    /boot/EFI/Linux/omarchy_linux.efi.extra.d/*.addon.efi

An addon is a tiny PE file whose `.initrd` section holds a cpio archive. The
stub concatenates addon initrds **after** the UKI's embedded initrd — the
stub source says verbatim: *"We want addons to take precedence over the base
initrds."* Since later cpio entries win during kernel unpacking, an addon
containing

    /usr/share/plymouth/themes/<name>/...   (the theme)
    /etc/plymouth/plymouthd.conf            (Theme=<name>)
    /usr/share/fonts/Plymouth.ttf           (font for label-freetype)

completely replaces the baked-in boot design. The UKI itself is untouched, so:

- **No mkinitcpio / limine-mkinitcpio run.** Generating the addon is
  `cpio | objcopy` — sub-second, a few MB on the ESP.
- **Limine's hash pinning is unaffected** — limine.conf pins the UKI's hash;
  the addon is loaded by the stub, not by Limine, and is not hash-checked.
  (Trust model unchanged: without Secure Boot the ESP is unauthenticated
  anyway, and `hash_mismatch_panic: no`.)
- **Kernel updates don't invalidate it.** Build the addon *without* a
  `.uname` section and the stub accepts it for any kernel. mkinitcpio can
  rebuild the UKI all it wants; the addon is a separate file.
- **Snapshots keep a safe fallback.** limine-snapper-sync's history entries
  boot UKI copies under different filenames, so their `.extra.d/` dirs don't
  exist — snapshots boot the stock baked-in theme. Rollbacks are never at the
  mercy of a broken theme addon.
- **Removal = deleting one file** → stock theme is back.

## Building an addon (no ukify needed)

```sh
# theme cpio
(cd overlay && find . -mindepth 1 | cpio -o -H newc -R 0:0) > theme.cpio

# .initrd VMA must land on the first SectionAlignment boundary past the
# stub's last section (base+0x3000 for the shipped stub)
stub=/usr/lib/systemd/boot/efi/addonx64.efi.stub
vma=$(objdump -h "$stub" | awk '$2 ~ /^\./ { end = strtonum("0x"$4) + strtonum("0x"$3) }
  END { printf "0x%x", and(end + 0xfff, compl(0xfff)) }')
objcopy --add-section .initrd=theme.cpio --change-section-vma .initrd=$vma \
  "$stub" theme.addon.efi
```

`ukify build --stub .../addonx64.efi.stub --initrd theme.cpio` does the same
if `systemd-ukify` is installed. Install to
`/boot/EFI/Linux/omarchy_linux.efi.extra.d/` (root). Multiple addons are
loaded in sorted filename order.

The addon isn't limited to theme assets: it's an arbitrary initrd overlay, so
it can also carry extra Plymouth plugins/renderers a fancier design needs, or
a `.cmdline` section could tweak kernel args. Full flexibility, zero rebuild.

## What this means for Omarchy ("the API")

1. `omarchy-plymouth-set` (and `-set-by-theme`) can drop its
   `limine-mkinitcpio`/`mkinitcpio -P` step: stage the recolored theme as
   today, then emit `boot-theme.addon.efi` instead. Theme switching updates
   the boot screen instantly instead of in ~30s.
2. The baked-in `omarchy` theme stays in the initramfs as the guaranteed
   fallback (and for snapshots).
3. New lock-screen designs with matching boot twins (the DHH ask) become a
   file-drop: one addon per design, swapping = replacing one small file on
   the ESP. First-boot/installer flows can select a design without ever
   rebuilding the shipped image.
4. If Omarchy ever enables Secure Boot, addons need an `sbsign` pass with the
   same key as the UKI — same pipeline, still no rebuild.

## Caveats / verification notes

- Addon loading with `.initrd` sections needs systemd-stub ≥ 256 in the UKI.
  Omarchy installs are on 261; old installs that predate stub 256 would need
  one regular UKI rebuild to pick up a newer stub first.
- Proven in QEMU with the full real chain (OVMF → Limine `protocol: efi` →
  host's actual UKI + addon, throwaway LUKS disk): themed prompt, bullet
  feedback, successful unlock. A reboot test on real hardware is the last
  confirmation step.
- VM testing gotcha: give QEMU **no serial port**. Limine appends
  `console=uart,io,0x3f8` when it finds one, and an active serial console
  makes Plymouth fall back to the plain text prompt. This cost an hour of
  debugging; real machines are unaffected.
