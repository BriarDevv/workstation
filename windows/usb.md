# Building the install USB

Everything to check before booting the installer. Written 2026-07-27 from the actual USB
that was built, not from a guide.

---

## 1. Pick the right ISO

The filename tells you what you're holding:

```
26100.1742.240906-0331.ge_release_svc_refresh_CLIENT_LTSC_EVAL_x64FRE_en-us.iso
└─────┬────┘                                  └─────┬────┘ └─┬─┘
   build 26100                              LTSC     EVAL   64-bit
   (24H2 base)
```

`EVAL` is the part that matters. Verify it from the image rather than trusting the name —
mount the ISO (or plug the USB) and read the WIM header:

```powershell
# needs elevation
Get-WindowsImage -ImagePath D:\sources\install.wim
```

What the current media contains:

```
[1] Windows 11 Enterprise LTSC 2024 Evaluation   EditionID: EnterpriseSEval    ← pick this
[2] Windows 11 Enterprise N Evaluation           EditionID: EnterpriseSNEval

sources\ei.cfg → [Channel] eval
```

**Pick [1] at setup.** The `N` editions ship without Media Foundation — no codecs, which
breaks video and audio playback, screen sharing in Teams/Zoom/Discord, Electron apps that
use Media Foundation, and WSLg. Fixable with the Media Feature Pack, but there's no reason
to walk into it when the non-N edition is right there in the same image.

### `EditionID` is the thing to look at

`EnterpriseSEval` and `EnterpriseS` are **different SKUs**, not the same product in two
states. A licence key for `EnterpriseS` will not apply to an `EnterpriseSEval` install —
`slmgr /ipk` rejects it. Microsoft states client evaluations cannot be upgraded to a
licensed version.

| ISO | Unactivated behaviour |
| ------------------- | ----------------------------------------------- |
| **LTSC volume** | Runs indefinitely. Watermark, no personalisation |
| **LTSC Evaluation** | **90 days**, then reboots **every hour** |

So the evaluation is for deciding whether LTSC is worth it, not for running long-term.
Reinstalling with volume media later is the price, and this repo is what makes that price
small.

**Set a reminder at day 60, not day 85.** Sourcing volume media or an IoT licence takes time.

---

## 2. Rufus — Windows User Experience

Rufus's customisation dialog is legitimate and does what it says. What each option is worth:

| Option | Verdict |
| ------------------------------------------- | ------------------------------------------------------------------- |
| Remove requirement for RAM / Secure Boot / TPM 2.0 | Unnecessary here — the X870 board has real TPM 2.0 and Secure Boot. Harmless either way; it only removes the installer's check |
| Remove requirement for an online Microsoft account | Fine. Enterprise/LTSC offers a local account anyway via "Join a domain instead" |
| **Create a local account** | **Use `mateo`.** Anything else changes `C:\Users\<name>` and breaks the absolute path in `claude/mcp.template.json`. The `.ps1` scripts use `$HOME` and adapt on their own |
| Set regional options to this user's | Fine |
| Disable data collection | Fine |
| **⚠️ SILENTLY erase disk and install** | **Leave unchecked.** It formats with no confirmation. The edition dropdown next to it only applies when this is on — with it off you pick the edition during setup |
| **Disable BitLocker automatic device encryption** | **Check it.** With a local account there's nowhere to escrow the recovery key. On a desktop that never leaves the house, encryption adds data-loss risk without adding much security |
| QoL improvements | Yes. Disables Copilot, OneDrive, Outlook and Fast Startup |

### Fast Startup — what it actually is

With Fast Startup on, "Shut down" doesn't shut down. Windows hibernates the kernel session
to `hiberfil.sys` and restores it on boot. Faster to start, but:

- The NTFS volume is left in a locked state — a Linux dual-boot can't safely mount it
- **Driver and BIOS updates don't apply on shutdown, only on restart.** You can lose an
  hour debugging something that a real reboot would have fixed
- WSL2 and Docker end up in strange states after a hibernated shutdown
- On NVMe the time saved is a couple of seconds

Turn it off on a dev machine.

---

## 3. Verify what Rufus actually wrote

**Rufus does not put `autounattend.xml` at the root of the USB.** It goes here:

```
D:\sources\$OEM$\$$\Panther\unattend.xml
```

which Windows Setup copies to `C:\Windows\Panther\` during install. Looking only at the
root of the drive and concluding the customisations didn't apply is an easy mistake.

Read it back before booting:

```powershell
$f = "D:\sources\`$OEM`$\`$`$\Panther\unattend.xml"
Select-String $f -Pattern '<Name>|BypassNRO|ProtectYourPC|PreventDeviceEncryption|HiberbootEnabled|Copilot|OneDrive|Outlook'
```

What the built USB reported:

| Setting | Value |
| ------------------------ | -------------------------------------- |
| Username | `mateo` ✅ |
| Groups | `Administrators;Power Users` |
| Microsoft account | `BypassNRO` — skipped |
| Telemetry | `ProtectYourPC = 3` (minimum) |
| EULA | `HideEULAPage` |
| BitLocker | `PreventDeviceEncryption` |
| Fast Startup | `HiberbootEnabled` disabled |
| Copilot / OneDrive / Outlook | disabled |

---

## 4. Before booting

### Back this up — it's the only irreversible part

No git remote, no cloud copy:

```
C:\Briar\Facultad     C:\Briar\Trabajo     C:\Briar\WAND
C:\Briar\Pen          C:\Briar\Paginas
```

### The way back

Windows 11 Pro licence as of 2026-07-27:

| | |
| ------------------- | ---------------------------------------------- |
| Channel | **Retail** |
| Key (last 5) | `3V66T` |
| OEM key in firmware | none |
| Digital licence | **linked to `mateogarcia1660@gmail.com`** ✅ |

Verified in Settings → System → Activation: *"Windows is activated with a digital licence
linked to your Microsoft account."* That's stronger than a hardware-only link — it survives
a board swap through the activation troubleshooter.

It will **not** activate LTSC (different product), but reinstalling Pro on this machine
reactivates itself. Nothing to do here; it's already set up.

### BIOS

| Setting | Why |
| -------------------- | ----------------------------------- |
| TPM 2.0 (fTPM) | Windows 11 requires it |
| Secure Boot | Windows 11 requires it |
| SVM / virtualisation | **WSL2 and Docker Desktop need it** |

---

## 5. After first boot

`winget` may not exist — LTSC ships without the Microsoft Store, and winget comes from the
Store. Nothing in this repo runs without it.

```powershell
Get-Command winget    # nothing? run windows\bootstrap.ps1
```

That script has to run under **PowerShell 5.1**, because a fresh LTSC has nothing else.
