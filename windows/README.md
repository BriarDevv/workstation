# Windows

The operating system itself. Target edition: **Windows 11 Enterprise LTSC**.

This folder runs at both ends of the install: the bootstrap goes **first** because
everything depends on it, the tweaks go **last** because they restart Explorer.

| File | When | What |
| --------------- | ------- | ---------------------------------------------------------- |
| `usb.md` | before | Building the install USB: which ISO, Rufus options, BIOS |
| `bootstrap.ps1` | phase 0 | winget, PowerShell 7, Developer Mode. **Runs on PS 5.1** |
| `install.ps1` | phase 5 | Explorer, power, telemetry. Restarts Explorer |

---

## ⚠️ Bootstrap: winget may not exist

LTSC ships without the Microsoft Store, and **`winget` comes from the Store**. On a fresh
LTSC install `apps/install.ps1` can't run at all — there's nothing to run it with.

> LTSC 2021 definitely excluded the Store. Reports on LTSC 2024 are mixed. Check on day one
> rather than assuming either way.

```powershell
Get-Command winget -ErrorAction SilentlyContinue   # nothing = you need the bootstrap
```

`bootstrap.ps1` handles it — it asks GitHub for the current winget-cli release, installs the
dependencies first, then the bundle. Run it from an **elevated Windows PowerShell**:

```powershell
powershell -ExecutionPolicy Bypass -File windows\bootstrap.ps1
```

> **`bootstrap.ps1` is the only script here written for PowerShell 5.1.** A fresh LTSC has
> nothing else — PowerShell 7 is one of the things it installs. No `&&`, no ternaries, no
> `??`, and TLS 1.2 gets forced by hand because 5.1 still defaults to SSL3/TLS1.0 and
> GitHub refuses that.

It also installs **PowerShell 7** (via winget, or the MSI from GitHub if winget still isn't
there) and enables **Developer Mode**.

Developer Mode is what lets a **non-elevated** process create symlinks. Verified on this
machine: with the registry value unset, `New-Item -ItemType SymbolicLink` fails with
*"Administrator privilege required"*.

**No script here depends on it right now.** It stays on because it's a one-time registry
flag with no runtime cost and symlinks come up constantly in dev work — but if you want a
machine with nothing switched on that isn't earning its keep, `-SkipDevMode` is the flag
and nothing in the repo will break.

Everything after this point can run unelevated.

---

## Before you install

### Back this up — it is not anywhere else

Five folders under `C:\Briar\` have no git remote and no cloud copy. Wipe the disk and
they're gone. **The list lives in the root `README.md` § Before you wipe** — one copy, so
it can't drift out of sync with the other three places that used to repeat it.

### Link the digital licence

Settings → System → Activation. If it doesn't mention your Microsoft account, link it now.

Current licence, captured 2026-07-27:

| | |
| --------------- | ----------------------------------- |
| Edition | Windows 11 Pro, 25H2, build 26200.8875 |
| Channel | **Retail** |
| Key (last 5) | `3V66T` |
| OEM key in firmware | none |
| KMS | no |

Retail is the good case: transferable, not welded to the motherboard. **It will not
activate LTSC** — different product, different key family — but it's the way back. Reinstall
Pro on this same board and it reactivates itself from the hardware-linked digital licence.

### BIOS checklist

| Setting | Why |
| ------------------ | ----------------------------------- |
| TPM 2.0 (fTPM) | Windows 11 requires it |
| Secure Boot | Windows 11 requires it |
| SVM / virtualisation | **WSL2 and Docker Desktop need it** |

Board is an ASUS ROG STRIX X870-A GAMING WIFI. LTSC 2024 is 24H2-based and supports the
800-series chipset fine.

---

## LTSC notes

**Version:** LTSC 2024 is build **26100** (24H2 base). This machine currently runs **26200**
(25H2), so LTSC is a step *back* in base build. That's the point of LTSC — it freezes and
takes no feature updates — but it's worth knowing. Check whether a newer LTSC has shipped.

**Installing without a key** is a supported Microsoft flow: click *"I don't have a product
key"* at setup. What happens next depends entirely on which ISO you used:

| ISO | Unactivated behaviour |
| --------------------- | ------------------------------------------------------------------ |
| **LTSC volume** | Runs **indefinitely**. Watermark, no personalisation. Nothing else |
| **LTSC Evaluation** | **90 days**, then reboots **every hour** |

**The Evaluation ISO cannot be converted to full with a key.** Microsoft states there's no
upgrade path. Install eval "for now" and activating later means reinstalling from scratch.
Use the volume ISO if the plan is to activate later.

**Local account at OOBE:** Enterprise and LTSC offer *"Join a domain instead"*, which drops
you into local-account creation. None of the Home/Pro workarounds needed.

**What LTSC removes:** Store, Cortana, Widgets, consumer Teams, most inbox UWP apps, Edge
preinstall. For the work stack — Docker, WSL, VS Code, Node, Python — nothing is
lost. For games, Steam is fine; anything wanting the Xbox app or Game Pass needs the Store
added back by hand.

---

## `explorer.ps1`

The Explorer settings you always end up redoing:

- Show file extensions
- Show hidden files
- Open to "This PC" instead of "Quick access"
- Don't group taskbar buttons
- Remove the taskbar search box

Only touches `HKCU:` — no admin needed, no effect on other users. Restarts `explorer.exe`
at the end, which is why this folder runs last.

---

## Install order

```
0. windows/  bootstrap    winget, if LTSC didn't bring it
1. apps/                  the binaries
2. terminal/              the look
3. dev/                   VS Code, Git, repos
4. claude/                Claude Code
5. windows/  the rest     Explorer tweaks — restarts Explorer
```
