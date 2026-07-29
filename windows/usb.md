# Building the install USB

Everything to check before booting the installer.

Sections 2–4 were written 2026-07-27 from the actual USB that was built and are unchanged.
Sections 1 and 5 were rewritten **2026-07-29**, when the target went from Enterprise LTSC to
**Windows 11 Pro**.

---

## 1. Get the ISO

From Microsoft directly: **microsoft.com/software-download/windows11** → *Download Windows 11
Disk Image (ISO) for x64 devices*. That is the multi-edition consumer image; Pro is one of the
editions inside it.

Rufus needs the ISO, so download the image rather than running the Media Creation Tool.

### At setup, pick **Windows 11 Pro** — not Pro N

The `N` editions ship **without Media Foundation**. No codecs, which breaks video and audio
playback, screen sharing in Discord and Zoom, Electron apps that use Media Foundation, and
WSLg. It's fixable with the Media Feature Pack, but there is no reason to walk into it when
the non-N edition is in the same image.

Verify what you're holding rather than trusting the filename:

```powershell
# needs elevation
Get-WindowsImage -ImagePath D:\sources\install.wim
```

### No time bomb this time

The previous plan used an LTSC **Evaluation** ISO, which expires after 90 days and then
reboots hourly, and which cannot be converted to a licensed install — a reinstall was the
only way out.

None of that applies to Pro. Your Retail digital licence activates it, and reinstalling on
this board **reactivates itself with no key typed**. You can also click *"I don't have a
product key"* and let it sort itself out after first boot.

---

## 2. Rufus — Windows User Experience

Rufus's customisation dialog is legitimate and does what it says. What each option is worth:

| Option | Verdict |
| ------------------------------------------- | ------------------------------------------------------------------- |
| Remove requirement for RAM / Secure Boot / TPM 2.0 | Unnecessary here — the X870 board has real TPM 2.0 and Secure Boot. Harmless either way; it only removes the installer's check |
| **Remove requirement for an online Microsoft account** | **Check it.** This one got more important: LTSC offered *"Join a domain instead"* as an escape hatch and Pro does not, so without this you are pushed into signing in |
| **Create a local account** | **Use `mateo`.** Anything else changes `C:\Users\<name>`. The `.ps1` scripts use `$HOME` and adapt on their own |
| Set regional options to this user's | Fine |
| Disable data collection | Fine |
| **⚠️ SILENTLY erase disk and install** | **Leave unchecked.** It formats with no confirmation. The edition dropdown next to it only applies when this is on — with it off you pick the edition during setup |
| **Disable BitLocker automatic device encryption** | **Check it.** With a local account there's nowhere to escrow the recovery key. On a desktop that never leaves the house, encryption adds data-loss risk without adding much security |
| QoL improvements | Yes. Disables Copilot, OneDrive, Outlook and Fast Startup |

> **Do the local-account bypass here, at USB-creation time.** The old trick typed at OOBE —
> `Shift+F10`, then `oobe\bypassnro` — was removed by Microsoft in recent Windows 11 builds.
> Letting Rufus write it into the answer file doesn't depend on a workaround still existing
> on the day you boot.

### A local account and the Store are not in conflict

`apps/README.md` § Microsoft Store installs the NVIDIA App from `msstore`, which needs a
signed-in Microsoft account — and you'll be on a local one.

Those are different things. **The Windows account stays local; you sign into the Store app
itself** when you want a Store package. If that hasn't been done, the NVIDIA row fails, the
script says so, and you install it from `nvidia.com` instead. Nothing else in the restore
depends on it.

### Fast Startup — what it actually is

With Fast Startup on, "Shut down" doesn't shut down. Windows hibernates the kernel session to
`hiberfil.sys` and restores it on boot. Faster to start, but:

- The NTFS volume is left in a locked state — a Linux dual-boot can't safely mount it
- **Driver and BIOS updates don't apply on shutdown, only on restart.** You can lose an hour
  debugging something that a real reboot would have fixed
- WSL2 and Docker end up in strange states after a hibernated shutdown
- On NVMe the time saved is a couple of seconds

Turn it off on a dev machine. `windows/install.ps1` also sets this, so it survives a Windows
update that turns it back on.

---

## 3. Verify what Rufus actually wrote

**Rufus does not put `autounattend.xml` at the root of the USB.** It goes here:

```
D:\sources\$OEM$\$$\Panther\unattend.xml
```

which Windows Setup copies to `C:\Windows\Panther\` during install. Looking only at the root
of the drive and concluding the customisations didn't apply is an easy mistake.

Read it back before booting:

```powershell
$f = "D:\sources\`$OEM`$\`$`$\Panther\unattend.xml"
Select-String $f -Pattern '<Name>|BypassNRO|ProtectYourPC|PreventDeviceEncryption|HiberbootEnabled|Copilot|OneDrive|Outlook'
```

What the previously built USB reported — the same checks apply to the Pro one:

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

**`BypassNRO` is the line to confirm.** It's the one that decides whether you can finish setup
without a Microsoft account, and on Pro there's no menu option to fall back on.

---

## 4. Before booting

### Back this up — it's the only irreversible part

Five folders under `C:\Briar\` exist on this disk and nowhere else: no git remote, no cloud
copy. **Open the root `README.md` § Before you wipe and copy them off now.** The list is kept
in exactly one place so it can't go stale; this is the step where a stale copy would cost you
the data.

### The way back

Windows 11 Pro licence as of 2026-07-27:

| | |
| ------------------- | ---------------------------------------------- |
| Channel | **Retail** |
| Key (last 5) | `3V66T` |
| OEM key in firmware | none |
| Digital licence | **linked to `mateogarcia1660@gmail.com`** ✅ |

Verified in Settings → System → Activation: *"Windows is activated with a digital licence
linked to your Microsoft account."* That's stronger than a hardware-only link — it survives a
board swap through the activation troubleshooter.

Since the target is Pro, this **is** the licence for what you're installing. Reinstalling on
this machine reactivates itself. Nothing to do here.

### BIOS

| Setting | Why |
| -------------------- | ----------------------------------- |
| TPM 2.0 (fTPM) | Windows 11 requires it |
| Secure Boot | Windows 11 requires it |
| SVM / virtualisation | **WSL2 and Docker Desktop need it** |

---

## 5. After first boot

`winget` ships with Pro, so the restore should just run. Check anyway — App Installer can be
provisioned without having registered for your user yet, which happens when the machine had
no network during setup:

```powershell
Get-Command winget    # nothing? run windows\bootstrap.ps1
```

That script runs under **PowerShell 5.1**, because a fresh Windows has nothing else.

Then the whole restore is one command — root `README.md` has the three steps that get you to
it:

```powershell
pwsh .\install.ps1
```

Expect it to **stop after `apps/`** and tell you to reboot. Docker and WSL don't work until
the machine restarts, and it prints the command to resume.

### Then debloat

Pro arrives with the inbox apps LTSC would have stripped. Check the list against reality
before removing anything:

```powershell
pwsh windows\debloat.ps1 -List        # what this machine actually has
pwsh windows\debloat.ps1 -WhatIfOnly  # what the table would remove
```

`windows/README.md` § Inbox apps is the list, and § Day one explains why it needs checking:
it was written before this machine existed.
