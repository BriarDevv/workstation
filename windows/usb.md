# Windows installation USB

This is the fallback path, not the normal reinstall. When Windows Recovery works, use
Settings → System → Recovery → Reset this PC → Remove everything → Cloud download instead.
Prepare USB media only when recovery fails, Windows cannot boot, or the target disk must be
repartitioned manually. Re-check the linked vendor guidance on the day the media is created
because Windows setup and Secure Boot requirements change.

## 1. Prepare and verify

1. Complete [`docs/pre-format.md`](../docs/pre-format.md).
2. Confirm Windows activation is linked as intended in Settings → System → Activation.
3. Confirm TPM 2.0, Secure Boot, and hardware virtualization are enabled in firmware.
4. Download the current multi-edition Windows 11 ISO from
   [Microsoft's official download page](https://www.microsoft.com/software-download/windows11).
5. Download current Rufus from its
   [official repository](https://github.com/pbatard/rufus/releases).
6. Identify the USB by model and capacity. Rufus erases the selected device completely.

Install Windows 11 Pro, not Pro N. Choosing the edition that matches the digital licence is
what allows activation to recover without embedding a key in this repository.

## 2. Create the media

Use GPT/UEFI for this Windows 11 machine and leave Rufus' filesystem choice unless the
current tool warns otherwise. After pressing Start, review the Windows User Experience
dialog instead of relying on a remembered list of options.

If a local account is desired, Rufus currently documents that its online-account option only
restores the offline local-account path; network access must also be unavailable during the
account-creation page. Treat the current
[Rufus FAQ](https://github.com/pbatard/rufus/wiki/FAQ) as authoritative for the current
offline-account flow.

Secure Boot certificate handling is evolving. Use current Rufus and follow any CA 2023 or
revoked-bootloader warning it presents for the target firmware; do not disable Secure Boot
permanently merely to boot old media.

## 3. Before booting

- Reconfirm the selected USB and the intended Windows target disk.
- Keep only the drives needed for the install connected when practical.
- Have network and storage drivers available if the installer needs them.
- Record BitLocker recovery material outside the disk being erased, if applicable.
- Boot the USB's UEFI entry, delete only the intended Windows partitions, and install Pro.

## 4. After first boot

1. Finish Windows Update and driver installation.
2. Confirm activation and edition.
3. Establish the local administrator and sign-in choices described in `README.md`.
4. Confirm `winget`; use `bootstrap.ps1` only if it remains unavailable.
5. Clone the repository, close other applications, wait five to ten minutes after boot, and
   run `pwsh windows\audit.ps1 -Label stock`.
6. Run the root restore first with `-WhatIfOnly`, then for real.
7. Reboot whenever the orchestrator stops for a pending restart and continue the restore.
8. Run the elevated `windows\install.ps1` command printed by the final phase, then reboot.
9. Preview and run `debloat.ps1` for the current user.
10. Reboot, use the same idle conditions, and run `pwsh windows\audit.ps1 -Label optimized`.
