# Windows

The operating system itself. Target edition: **Windows 11 Pro**.

This folder runs at both ends of the install: the bootstrap goes **first** when it's needed
at all, the tweaks go **last** because they restart Explorer.

| File | When | What |
| --------------- | ------- | ---------------------------------------------------------- |
| `usb.md` | before | Building the install USB: which ISO, Rufus options, BIOS |
| `bootstrap.ps1` | phase 0 | winget, PowerShell 7, Developer Mode. **Runs on PS 5.1** |
| `debloat.ps1` | by hand | Removes the inbox apps. **Not run by the orchestrator** — see below |
| `install.ps1` | phase 5 | Explorer, power, telemetry. Restarts Explorer |

---

## Pro, not LTSC — and what that costs

Decided **2026-07-29**, reversing the earlier plan. The reasoning was never that LTSC is
worse; it's that Pro is what the licence activates and what the machine will actually run.

| | LTSC | **Pro (this machine)** |
| ----------------- | -------------------------- | ---------------------------------- |
| Microsoft Store | absent | **present** |
| `winget` | may be missing | **ships with Windows** |
| `msstore` source | can't resolve | **works** |
| Your Retail key | **doesn't activate it** | **activates, from the digital licence** |
| Feature updates | none for ~5 years | annual |
| Inbox apps | mostly stripped | **all there — see `debloat.ps1`** |
| Local account at OOBE | "Join a domain instead" | **needs a workaround, see `usb.md`** |

The trade in one line: **LTSC is a machine that doesn't change under you; Pro is a machine
you have to configure.** This folder is that configuration. It's also why `debloat.ps1`
exists at all — on LTSC there would be almost nothing for it to do.

---

## Bootstrap: usually not needed now

**Pro ships `winget`** inside App Installer, so on a fresh Pro install
`apps/install.ps1` normally just runs.

```powershell
Get-Command winget -ErrorAction SilentlyContinue   # nothing = you need the bootstrap
```

It's still worth checking rather than assuming. A brand-new install sometimes has App
Installer *provisioned but not yet registered* for your user — winget is missing for a few
minutes after first login until Windows finishes, and it can stay missing if the machine has
no network during OOBE.

If it is missing, `bootstrap.ps1` asks GitHub for the current winget-cli release, installs
the dependencies first, then the bundle. Run it from an **elevated Windows PowerShell**:

```powershell
powershell -ExecutionPolicy Bypass -File windows\bootstrap.ps1
```

> **`bootstrap.ps1` is the only script here written for PowerShell 5.1.** A fresh Windows has
> nothing else — PowerShell 7 is one of the things it installs. No `&&`, no ternaries, no
> `??`, and TLS 1.2 gets forced by hand because 5.1 still defaults to SSL3/TLS1.0 and GitHub
> refuses that.

It also installs **PowerShell 7** (via winget, or the MSI from GitHub if winget still isn't
there) and enables **Developer Mode**.

Developer Mode is what lets a **non-elevated** process create symlinks. Verified on this
machine: with the registry value unset, `New-Item -ItemType SymbolicLink` fails with
*"Administrator privilege required"*.

**No script here depends on it right now.** It stays on because it's a one-time registry
flag with no runtime cost and symlinks come up constantly in dev work — but if you want a
machine with nothing switched on that isn't earning its keep, `-SkipDevMode` is the flag and
nothing in the repo will break.

Everything after this point can run unelevated.

---

## Before you install

### Back this up — it is not anywhere else

Five folders under `C:\Briar\` have no git remote and no cloud copy. Wipe the disk and
they're gone. **The list lives in the root `README.md` § Before you wipe** — one copy, so it
can't drift out of sync with the other three places that used to repeat it.

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

**Reinstalling Pro on this board reactivates itself** from the hardware-linked digital
licence — you don't need to type the key. Retail is the good case besides: transferable, not
welded to the motherboard.

You can still click *"I don't have a product key"* at setup and let it activate afterwards;
it's a supported flow, and unlike an Evaluation ISO there's no time bomb attached.

### BIOS checklist

| Setting | Why |
| ------------------ | ----------------------------------- |
| TPM 2.0 (fTPM) | Windows 11 requires it |
| Secure Boot | Windows 11 requires it |
| SVM / virtualisation | **WSL2 and Docker Desktop need it** |

Board is an ASUS ROG STRIX X870-A GAMING WIFI, fully supported on current Windows 11.

---

## `debloat.ps1`

Removes the inbox apps Pro ships and LTSC didn't. **Read its own section in this file before
running it** — it's the one script here that deletes rather than configures.

```powershell
pwsh windows\debloat.ps1 -WhatIfOnly    # always do this first
pwsh windows\debloat.ps1
```

The table below is the complete list — the script reads it, exactly like `apps/install.ps1`
reads its own. It removes **per-user** by default, which is reversible from the Store;
`-AllUsers` also strips the provisioned copy so new profiles don't get it back.

Pair it with `install.ps1`, which sets `DisableWindowsConsumerFeatures` — without that,
Windows reinstalls a fresh batch of suggestions on the next feature update and you get to do
this twice.

### Day one: check the list before trusting it

**This table was written before the machine existed.** Package names change between Windows
releases, and a name that's gone is a row that does nothing.

```powershell
pwsh windows\debloat.ps1 -List        # everything removable on this machine
pwsh windows\debloat.ps1 -WhatIfOnly  # what the table would actually remove
```

`-List` is the reconciliation. Anything it shows that you don't want gets a row here;
anything the table names and it doesn't show gets reported as *not found*, which means the
row is stale and should go.

## Inbox apps

| Package | What it is |
| --------------------------------------- | ------------------------------------------------ |
| `Microsoft.BingNews`                     | News                                             |
| `Microsoft.BingWeather`                  | Weather                                          |
| `Microsoft.BingSearch`                   | Web results inside the Start menu search         |
| `Microsoft.GetHelp`                      | "Get Help"                                       |
| `Microsoft.Getstarted`                   | "Tips"                                           |
| `Microsoft.MicrosoftOfficeHub`           | Office upsell tile, not Office                   |
| `Microsoft.MicrosoftSolitaireCollection` | Solitaire, with ads                              |
| `Microsoft.People`                       | People                                           |
| `Microsoft.WindowsFeedbackHub`           | Feedback Hub                                     |
| `Microsoft.WindowsMaps`                  | Maps                                             |
| `Microsoft.ZuneVideo`                    | Movies & TV                                      |
| `Microsoft.Todos`                        | To Do                                            |
| `Microsoft.PowerAutomateDesktop`         | Power Automate                                   |
| `Microsoft.OutlookForWindows`            | The new Outlook, preinstalled                    |
| `Microsoft.WindowsSoundRecorder`         | Sound Recorder                                   |
| `Microsoft.QuickAssist`                  | Quick Assist                                     |
| `Clipchamp.Clipchamp`                    | Video editor                                     |
| `MSTeams`                                | Consumer Teams. You said you don't use it        |
| `Microsoft.549981C3F5F10`                | Cortana. May already be gone on this build       |

## Deliberately kept

**This has to be its own `##` section, not a second table under the one above.**
`Get-IdsFromReadme` reads by section, so two tables under one heading are one list — and the
first version of this file put them together, which made `debloat.ps1` plan to remove the
exact five apps documented here as keepers. The dry run caught it; nothing else would have.

Judgement calls rather than bloat:

| Kept | Why |
| ------------------------- | ------------------------------------------------------------ |
| `Microsoft.ZuneMusic` | This is Media Player now, not Zune. It's the default audio handler |
| `Microsoft.GamingApp` | The Xbox app. You game — removing it also removes Game Pass  |
| `Microsoft.YourPhone` | Phone Link. Useless until you pair a phone, harmless if you do |
| `Microsoft.WindowsCamera` | Small, and there's no second camera app                       |
| `Microsoft.WindowsStore` | Removing the Store is a one-way door on Pro                   |

---

## Explorer tweaks (`install.ps1`)

The Explorer settings you always end up redoing:

- Show file extensions
- Show hidden files
- Open to "This PC" instead of "Quick access"
- Don't group taskbar buttons
- Remove the taskbar search box

Only touches `HKCU:` — no admin needed, no effect on other users. Restarts `explorer.exe` at
the end, which is why this folder runs last.

### Telemetry, and a Pro-specific catch

`AllowTelemetry = 0` means "Security", and **Pro does not honour it** — it clamps to `1`
("Required"). Level 0 needs Enterprise, Education or LTSC.

The script still writes 0, so the intent survives an edition change, but its message says
what actually happens. A line claiming "Security" on a Pro box is a lie you would only catch
by reading Microsoft's own documentation.

---

## Install order

The root `install.ps1` runs this. The order lives in that script's `$STEPS` table.

```
0. windows/  bootstrap    winget, only if Windows didn't bring it
1. layout/                the folder tree
2. apps/                  the binaries
3. terminal/              the look
4. dev/                   Git, repos
5. claude/                Claude Code
6. windows/  the rest     Explorer tweaks — restarts Explorer
```

**`debloat.ps1` is deliberately not in that list.** It's the one script here that deletes,
and its table was written before the machine existed — running it unattended as part of a
restore would remove things nobody checked. Run it yourself, after `-List`, once you've seen
what the machine actually shipped with.
