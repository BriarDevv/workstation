<#
.SYNOPSIS
    Repository verification with no external test framework.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:passed++
        Write-Host "  [ok]   $Name" -ForegroundColor Green
    }
    catch {
        $script:failures.Add("$Name - $($_.Exception.Message)")
        Write-Host "  [FAIL] $Name - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ''
Write-Host '=== Static verification' -ForegroundColor Cyan

Test-Case 'all PowerShell files parse' {
    $parseErrors = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem $repo -Recurse -Filter *.ps1) {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        foreach ($error in $errors) {
            $parseErrors.Add("$($file.FullName):$($error.Extent.StartLineNumber) $($error.Message)")
        }
    }
    Assert-True ($parseErrors.Count -eq 0) ($parseErrors -join '; ')
}

Test-Case 'tracked JSON files parse' {
    foreach ($file in Get-ChildItem $repo -Recurse -Filter *.json) {
        try { Get-Content $file.FullName -Raw | ConvertFrom-Json | Out-Null }
        catch { throw "$($file.FullName): $($_.Exception.Message)" }
    }
}

. (Join-Path $repo '_lib.ps1')

Test-Case 'manifest tables contain no duplicate package IDs' {
    $apps = Join-Path $repo 'apps\README.md'
    $sections = @('Essentials', 'Terminal', 'Desktop / utilities', 'Games', 'Runtimes',
        'Optional', 'Microsoft Store', 'npm globals')
    $ids = @(Get-IdsFromReadme $apps $sections)
    Assert-True ($ids.Count -gt 0) 'no package rows were parsed'
    $duplicates = @($ids | Group-Object | Where-Object Count -gt 1)
    Assert-True ($duplicates.Count -eq 0) "duplicate IDs: $($duplicates.Name -join ', ')"
}

Test-Case 'repository clone manifest has unique valid entries' {
    $names = [System.Collections.Generic.List[string]]::new()
    $remotes = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem (Join-Path $repo 'dev\repos') -Filter *.md |
            Where-Object Name -ne 'README.md') {
        $inList = $false
        foreach ($line in Get-Content $file.FullName) {
            if ($line -match '^##\s+(.+?)\s*$') { $inList = $Matches[1].Trim() -eq 'The list'; continue }
            if (-not $inList -or $line -notmatch '^\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|') { continue }
            $name = $Matches[1].Trim()
            $remote = $Matches[2].Trim()
            if ($name -eq 'Repo' -or $name -match '^-+$') { continue }
            Assert-True ($name -match '^[^\\/:*?"<>|]+$') "invalid local repo folder: $name"
            Assert-True ($remote -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') "invalid GitHub slug: $remote"
            $names.Add("$($file.BaseName)/$name")
            $remotes.Add($remote.ToLowerInvariant())
        }
    }
    Assert-True ($remotes.Count -gt 0) 'no repository entries were parsed'
    Assert-True (@($names | Group-Object | Where-Object Count -gt 1).Count -eq 0) `
        'duplicate local repository paths'
    Assert-True (@($remotes | Group-Object | Where-Object Count -gt 1).Count -eq 0) `
        'duplicate GitHub remotes'

    $installer = Get-Content (Join-Path $repo 'dev\install.ps1') -Raw
    Assert-True $installer.Contains('remote get-url origin') `
        'existing clones are not checked against the declared origin'
}

Test-Case 'Windows removal and keep manifests cannot contradict each other' {
    $windows = Join-Path $repo 'windows\README.md'
    $removeAppx = @(Get-IdsFromReadme $windows @('Inbox apps'))
    $removeWin32 = @(Get-IdsFromReadme $windows @('Win32 apps'))
    $keep = @(Get-IdsFromReadme $windows @('Deliberately kept'))

    Assert-True ($removeAppx.Count -gt 0) 'no Windows AppX removals were parsed'
    Assert-True ($removeWin32 -contains 'Microsoft.OneDrive') 'OneDrive is not a declared Win32 removal'
    Assert-True ($removeAppx -contains 'Microsoft.YourPhone') 'Phone Link is not a declared removal'
    Assert-True ($removeAppx -contains 'MicrosoftWindows.CrossDevice') 'Cross Device is not a declared removal'

    $duplicates = @(($removeAppx + $removeWin32) | Group-Object | Where-Object Count -gt 1)
    Assert-True ($duplicates.Count -eq 0) "duplicate Windows removal IDs: $($duplicates.Name -join ', ')"
    $overlap = @($removeAppx | Where-Object { $_ -in $keep })
    Assert-True ($overlap.Count -eq 0) "Windows packages marked both remove and keep: $($overlap -join ', ')"
    $xboxRemoval = @($removeAppx | Where-Object { $_ -match 'Gaming|Xbox' })
    Assert-True ($xboxRemoval.Count -eq 0) "Xbox/Game Pass package marked for removal: $($xboxRemoval -join ', ')"

    $debloatText = Get-Content (Join-Path $repo 'windows\debloat.ps1') -Raw
    $protectedBlock = [regex]::Match($debloatText, '(?ms)^\$PROTECTED\s*=\s*@\(\s*(.*?)^\)')
    Assert-True $protectedBlock.Success 'debloat protected-package guard could not be parsed'
    $protected = @([regex]::Matches($protectedBlock.Groups[1].Value, "'([^']+)'") |
            ForEach-Object { $_.Groups[1].Value })
    $infrastructure = @(
        'Microsoft.Winget.Source'
        'Microsoft.PowerShell'
        'Microsoft.ApplicationCompatibilityEnhancements'
        'MicrosoftCorporationII.WindowsSubsystemForLinux'
        'Microsoft.AV1VideoExtension'
        'Microsoft.HEVCVideoExtension'
        'Microsoft.RawImageExtension'
        'Microsoft.WebMediaExtensions'
        'AdvancedMicroDevicesInc-2.AMDRadeonSoftware'
        'NVIDIACorp.NVIDIAControlPanel'
        'RealtekSemiconductorCorp.RealtekAudioControl'
    )
    foreach ($name in $keep + $infrastructure) {
        $guarded = @($protected | Where-Object { $name -like "$_*" }).Count -gt 0
        Assert-True $guarded "$name is documented as kept but is not protected by debloat.ps1"
    }
}

Test-Case 'Windows profile encodes the selected balanced privacy policy' {
    $source = Get-Content (Join-Path $repo 'windows\install.ps1') -Raw
    Assert-True ($source -match 'Phase 6') 'Windows installer is not numbered as the final canonical phase'
    Assert-True ($source -notmatch 'Phase 5') 'stale Windows phase number remains'
    Assert-True ($source -match '381b4222-f694-41f0-9685-ff5bb260df2e') 'Balanced power scheme is not selected'
    Assert-True ($source -notmatch '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') 'High performance scheme remains selected'
    foreach ($token in @('DiagTrack', 'DODownloadMode', 'DisableAIDataAnalysis',
            'PublishUserActivities', 'DiagnosticData', 'EnableDynamicContentInWSB',
            'AllowCloudSearch')) {
        Assert-True ($source.Contains($token)) "selected Windows policy is missing: $token"
    }
    Assert-True (-not $source.Contains('ConnectedSearchUseWeb')) 'Enterprise-only search policy remains in the Pro profile'
    Assert-True (-not $source.Contains("'DisableWebSearch'")) 'legacy web-search policy remains in the Pro profile'
    Assert-True (-not $source.Contains('BingSearchEnabled')) 'legacy BingSearchEnabled setting remains'
    Assert-True (-not $source.Contains('CortanaConsent')) 'legacy CortanaConsent setting remains'
    Assert-True (Test-Path (Join-Path $repo 'windows\audit.ps1')) 'Windows audit script is missing'
    Assert-True (Test-Path (Join-Path $repo 'docs\pre-format.md')) 'pre-format checklist is missing'
}

Test-Case 'MCP placeholders all have a declared value source' {
    $manifestPath = Join-Path $repo 'claude\mcp.template.json'
    $manifestText = Get-Content $manifestPath -Raw
    $manifest = $manifestText | ConvertFrom-Json -AsHashtable
    Assert-True ($manifest.mcpServers.Count -gt 0) 'no managed MCP servers declared'
    Assert-True (@($manifest.externalServers) -contains 'pencil') 'pencil must remain externally managed'

    $required = @([regex]::Matches($manifestText, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}') |
            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)
    $secretVars = @(Get-Content (Join-Path $repo 'secrets\.env.example') |
            Where-Object { $_ -match '^([A-Za-z_][A-Za-z0-9_]*)=' } |
            ForEach-Object { $Matches[1] })
    $installerVars = @('LAYOUT_REPOS', 'CLAUDE_MEMORY_FILE')
    $declared = @($secretVars + $installerVars)
    $missing = @($required | Where-Object { $_ -notin $declared })
    $unusedSecrets = @($secretVars | Where-Object { $_ -notin $required })
    Assert-True ($missing.Count -eq 0) "placeholders with no value source: $($missing -join ', ')"
    Assert-True ($unusedSecrets.Count -eq 0) "unused secret variables: $($unusedSecrets -join ', ')"
}

Test-Case 'Claude settings contain only current repo-owned structure' {
    $settings = Get-Content (Join-Path $repo 'claude\settings.json') -Raw |
        ConvertFrom-Json -AsHashtable
    Assert-True $settings.ContainsKey('$schema') 'schema is missing'
    Assert-True (-not $settings.ContainsKey('_notes')) '_notes is historical documentation'
    Assert-True (-not $settings.ContainsKey('hooks')) 'third-party hooks must not be frozen in the repo'
    Assert-True ($settings.enabledPlugins.Count -gt 0) 'no desired plugins declared'
}

Test-Case 'Claude plugins and MCPs are clean-machine reproducible' {
    $settings = Get-Content (Join-Path $repo 'claude\settings.json') -Raw |
        ConvertFrom-Json -AsHashtable
    $marketplaces = Get-Content (Join-Path $repo 'claude\marketplaces.json') -Raw |
        ConvertFrom-Json -AsHashtable
    foreach ($id in $settings.enabledPlugins.Keys) {
        $marketplace = ($id -split '@', 2)[1]
        Assert-True $marketplaces.marketplaces.ContainsKey($marketplace) `
            "$id has no reproducible marketplace source"
    }

    $mcpText = Get-Content (Join-Path $repo 'claude\mcp.template.json') -Raw
    $mcp = $mcpText | ConvertFrom-Json -AsHashtable
    $expectedMcp = @('sequential-thinking', 'filesystem', 'memory', 'github')
    $missingMcp = @($expectedMcp | Where-Object { -not $mcp.mcpServers.ContainsKey($_) })
    $unexpectedMcp = @($mcp.mcpServers.Keys | Where-Object { $_ -notin $expectedMcp })
    Assert-True ($missingMcp.Count -eq 0) "desired MCP missing: $($missingMcp -join ', ')"
    Assert-True ($unexpectedMcp.Count -eq 0) "undeclared MCP remains: $($unexpectedMcp -join ', ')"
    Assert-True (-not $mcpText.Contains('@modelcontextprotocol/server-github')) `
        'obsolete local GitHub MCP remains'
    Assert-True $mcpText.Contains('https://api.githubcopilot.com/mcp/') `
        'hosted GitHub MCP endpoint missing'
    foreach ($name in @('sequential-thinking', 'filesystem', 'memory')) {
        Assert-True ($mcp.mcpServers[$name].command -eq 'cmd') `
            "$name does not use the documented Windows cmd wrapper"
        Assert-True (@($mcp.mcpServers[$name].args)[0] -eq '/c') `
            "$name cmd wrapper has no /c argument"
        Assert-True (@($mcp.mcpServers[$name].args)[1] -eq 'npx') `
            "$name cmd wrapper does not invoke npx"
    }
    Assert-True ($mcp.mcpServers.memory.env.MEMORY_FILE_PATH -eq '${CLAUDE_MEMORY_FILE}') `
        'Memory MCP has no stable installer-derived storage path'

    $installer = Get-Content (Join-Path $repo 'claude\install.ps1') -Raw
    Assert-True $installer.Contains('plugin marketplace add') 'marketplaces are not installed'
    Assert-True $installer.Contains('plugin install') 'plugins are not installed'
    Assert-True $installer.Contains('$failed.Add(''Claude Code CLI'')') 'missing Claude CLI is not fatal'
}

Test-Case 'settings serializer preserves empty and single-element arrays' {
    # PowerShell unrolls arrays returned from functions: an empty array becomes $null and a
    # one-element array becomes its element. Claude rejects hooks serialized that way, and
    # every OMC hook event holds exactly one matcher group.
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $repo 'claude\install.ps1'), [ref]$tokens, [ref]$errors)
    $func = $ast.Find({ param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'ConvertTo-Sorted' }, $true)
    Assert-True ($null -ne $func) 'ConvertTo-Sorted was not found in claude/install.ps1'
    . ([scriptblock]::Create($func.Extent.Text))

    $settings = @{
        hooks = @{
            Stop             = @(@{ hooks = @(@{ type = 'command'; command = 'node stop.mjs' }) })
            UserPromptSubmit = @()
        }
    }
    $json = (ConvertTo-Sorted $settings) | ConvertTo-Json -Depth 100 -Compress
    Assert-True ($json.Contains('"UserPromptSubmit":[]')) `
        "empty hook event was not preserved as an array: $json"
    Assert-True ($json.Contains('"Stop":[{')) `
        "single matcher group lost its array wrapper: $json"
    Assert-True ($json.Contains('"hooks":[{')) `
        "single hook entry lost its array wrapper: $json"
}

Test-Case 'global rules directory has no generic resident rules' {
    $rules = @(Get-ChildItem (Join-Path $repo 'claude\rules\common') -Filter *.md -ErrorAction SilentlyContinue)
    Assert-True ($rules.Count -eq 0) "unexpected global rules: $($rules.Name -join ', ')"
}

Test-Case 'all normal installers expose WhatIfOnly and explicit success' {
    foreach ($relative in @('layout\install.ps1', 'apps\install.ps1', 'terminal\install.ps1',
            'dev\install.ps1', 'claude\install.ps1', 'accounts\install.ps1', 'windows\install.ps1')) {
        $source = Get-Content (Join-Path $repo $relative) -Raw
        Assert-True ($source -match '\[switch\]\$WhatIfOnly') "$relative has no WhatIfOnly switch"
        Assert-True ($source -match '(?m)^exit 0\s*$') "$relative has no explicit exit 0"
    }
    $rootText = Get-Content (Join-Path $repo 'install.ps1') -Raw
    Assert-True ($rootText.Contains("'terminal' { if (`$SkipUpgrade)")) 'root does not forward terminal options'
    Assert-True ($rootText.Contains('if ($WhatIfOnly) { $argv.WhatIfOnly = $true }')) 'root does not forward dry run'
}

Test-Case 'bootstrap recursive cleanup is confined to a unique temp workspace' {
    $source = Get-Content (Join-Path $repo 'windows\bootstrap.ps1') -Raw
    Assert-True $source.Contains('workstation-bootstrap-$PID-') 'bootstrap temp path is not unique'
    Assert-True $source.Contains('Refusing recursive removal outside the bootstrap workspace') `
        'bootstrap recursive removal has no boundary guard'
    Assert-True (-not $source.Contains('Remove-Item $ext -Recurse')) `
        'unguarded bootstrap dependency cleanup remains'
    Assert-True $source.Contains('Start-Process msiexec.exe -Wait -PassThru') `
        'PowerShell MSI exit code cannot be verified'
}

Test-Case 'root preserves canonical order and contains child exceptions' {
    $rootText = Get-Content (Join-Path $repo 'install.ps1') -Raw
    Assert-True $rootText.Contains('$STEPS | Where-Object { $_.Name -in $Only }') `
        'selected folders follow caller order instead of canonical order'
    Assert-True ($rootText -match '(?s)try\s*\{\s*& \$script @argv.*?catch\s*\{') `
        'unexpected child errors are not contained'
    Assert-True $rootText.Contains("if (`$Secrets) { `$resumeArgs.Add('-Secrets') }") `
        'post-reboot command drops the requested MCP secret sync'
    Assert-True $rootText.Contains("if (`$SkipUpgrade) { `$resumeArgs.Add('-SkipUpgrade') }") `
        'post-reboot command drops the requested upgrade policy'
}

Test-Case 'clean-machine previews do not require files they only plan to create' {
    $layoutText = Get-Content (Join-Path $repo 'layout\install.ps1') -Raw
    Assert-True ($layoutText -match '(?s)if \(-not \(Test-Path \$root\)\).*?if \(\$script:DryRun\)') `
        'layout still reads a missing root ACL during dry run'

    $appsText = Get-Content (Join-Path $repo 'apps\install.ps1') -Raw
    Assert-True $appsText.Contains('$haveNode = Test-Path $nodeExe') `
        'apps conflates installed Node with dry-run Node'
    Assert-True $appsText.Contains('$nodeWillExist = $haveNode -or $script:DryRun') `
        'apps does not model planned Node separately'
    Assert-True ($appsText -match 'Invoke-RestMethod "https://registry\.npmjs\.org/') `
        'npm version checks still require a local npm command during dry run'
    Assert-True $appsText.Contains('unsafe Node path in layout/LAYOUT.md') `
        'recursive Node replacement has no strict layout-root boundary check'

    $terminalText = Get-Content (Join-Path $repo 'terminal\install.ps1') -Raw
    Assert-True $terminalText.Contains('$script:DryRun -and -not (Test-WingetInstalled $id)') `
        'terminal queries upgrades for packages that only the apps dry run would install'
}

Test-Case 'debloat is deliberately current-user only' {
    $source = Get-Content (Join-Path $repo 'windows\debloat.ps1') -Raw
    Assert-True (-not $source.Contains('AllUsers')) 'all-user debloat logic remains'
    Assert-True (-not $source.Contains('Get-AppxProvisionedPackage')) 'provisioned packages remain in scope'
    Assert-True $source.Contains('Get-AppxPackage -Name $name') 'current-user package query is missing'
}

Test-Case 'optional packages are informational in snapshot drift' {
    $source = Get-Content (Join-Path $repo 'snapshot.ps1') -Raw
    Assert-True ($source.Contains("`$optionalIds = @(Get-IdsFromReadme `$readme @('Optional'))")) `
        'snapshot does not track optional packages separately'
    $requiredLine = @($source -split "`r?`n" | Where-Object { $_ -match '^\s*\$ids = .*Get-IdsFromReadme' })
    Assert-True ($requiredLine.Count -eq 1) 'required winget snapshot declaration is ambiguous'
    Assert-True (-not $requiredLine[0].Contains("'Optional'")) `
        'optional packages are still counted as required drift'
}

Test-Case 'layout ACL checks use language-independent SIDs' {
    $source = Get-Content (Join-Path $repo 'layout\install.ps1') -Raw
    Assert-True $source.Contains("Get-AclRulesForSid `$acl 'S-1-5-11'") `
        'Authenticated Users ACL detection is not SID-based'
    Assert-True (-not $source.Contains("IdentityReference.Value -eq 'NT AUTHORITY\Authenticated Users'")) `
        'locale-dependent Authenticated Users comparison remains'
}

Test-Case 'Windows audit covers desired policy, power, and debloat state' {
    $source = Get-Content (Join-Path $repo 'windows\audit.ps1') -Raw
    foreach ($token in @('SchemaVersion = 2', 'ManagedRegistryState', 'PowerState',
            'DebloatState', 'STANDBYIDLE', 'HIBERNATEIDLE', 'HiberbootEnabled')) {
        Assert-True $source.Contains($token) "audit coverage missing: $token"
    }
}

Test-Case 'post-format handoff contains every human bootstrap prerequisite' {
    $guide = Get-Content (Join-Path $repo 'docs\post-format.md') -Raw
    foreach ($token in @('Git.Git', 'GitHub.cli', 'Microsoft.PowerShell',
            'https://claude.ai/install.ps1', 'gh auth login', 'claude doctor',
            'BriarDevv/workstation.git', '-WhatIfOnly')) {
        Assert-True $guide.Contains($token) "post-format guide is missing: $token"
    }
    Assert-True $guide.Contains('nunca uses -AllUsers') 'handoff does not lock debloat to the current user'
    $instructions = Get-Content (Join-Path $repo 'CLAUDE.md') -Raw
    Assert-True $instructions.Contains('`docs/post-format.md` handoff, which stays in Spanish') `
        'repository language rule contradicts the Spanish post-format handoff'
}

Test-Case 'relative Markdown links resolve inside the repository' {
    $broken = [System.Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem $repo -Recurse -Filter *.md) {
        $text = Get-Content $file.FullName -Raw
        foreach ($match in [regex]::Matches($text, '!?(?<!\!)\[[^\]]*\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value.Trim().Trim('<', '>')
            if ($target -match '^(?:https?:|mailto:|#)') { continue }
            $pathPart = ($target -split '#', 2)[0]
            if (-not $pathPart) { continue }
            $resolved = Join-Path $file.DirectoryName ([Uri]::UnescapeDataString($pathPart))
            if (-not (Test-Path $resolved)) {
                $broken.Add("$($file.FullName) -> $target")
            }
        }
    }
    Assert-True ($broken.Count -eq 0) ($broken -join '; ')
}

Test-Case 'winget query failures are not reported as current' {
    $existingFunction = Get-Item Function:\global:winget -ErrorAction SilentlyContinue
    try {
        function global:winget { $global:LASTEXITCODE = 37 }
        $result = Get-WingetUpdate 'Workstation.Test.Package'
        Assert-True ($result.Status -eq 'check-failed') "status was $($result.Status)"
        Assert-True ($result.ExitCode -eq 37) "exit code was $($result.ExitCode)"
        Assert-True ((Update-WingetPackage 'Workstation.Test.Package') -eq 'fail') 'update did not propagate failure'
    }
    finally {
        Remove-Item Function:\global:winget -ErrorAction SilentlyContinue
        if ($existingFunction) { Set-Item Function:\global:winget $existingFunction.ScriptBlock }
    }
}

Write-Host ''
Write-Host '=== Backup and writer behavior' -ForegroundColor Cyan
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "workstation-tests-$PID-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $script:BackupDir = Join-Path $testRoot 'backup'
    $script:DryRun = $false
    $a = Join-Path $testRoot 'one\settings.json'
    $b = Join-Path $testRoot 'two\settings.json'
    New-Item -ItemType Directory -Path (Split-Path $a -Parent), (Split-Path $b -Parent) | Out-Null
    Set-Content -LiteralPath $a -Value 'original-a' -NoNewline
    Set-Content -LiteralPath $b -Value 'original-b' -NoNewline

    Test-Case 'same leaf name produces distinct backup paths' {
        $backupA = Get-BackupPath $a
        $backupB = Get-BackupPath $b
        Assert-True ($backupA -cne $backupB) 'backup paths collided'
        Assert-True ($backupA.EndsWith('one\settings.json')) 'first relative path was not preserved'
        Assert-True ($backupB.EndsWith('two\settings.json')) 'second relative path was not preserved'
    }

    Test-Case 'first original survives multiple writes in one run' {
        Assert-True (Install-ConfigText -Destination $a -Text 'replacement-1') 'first write failed'
        Assert-True (Install-ConfigText -Destination $a -Text 'replacement-2') 'second write failed'
        $backup = Get-BackupPath $a
        Assert-True ((Get-Content $backup -Raw) -ceq 'original-a') 'backup was overwritten by intermediate state'
    }

    Test-Case 'shared text writer honors dry run' {
        $before = Get-Content $b -Raw
        $script:DryRun = $true
        Assert-True (Install-ConfigText -Destination $b -Text 'must-not-land') 'dry-run call failed'
        Assert-True ((Get-Content $b -Raw) -ceq $before) 'dry run changed the destination'
        $script:DryRun = $false
    }
}
finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ''
Write-Host '=== Result' -ForegroundColor Cyan
if ($failures.Count) {
    Write-Host "  $passed passed, $($failures.Count) failed" -ForegroundColor Red
    foreach ($failure in $failures) { Write-Host "  - $failure" -ForegroundColor Red }
    exit 1
}

Write-Host "  $passed passed, 0 failed" -ForegroundColor Green
exit 0
