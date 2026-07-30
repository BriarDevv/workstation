<#
.SYNOPSIS
    Captures a read-only Windows baseline for before/after comparison.

.DESCRIPTION
    Records process and service counts, grouped working sets, startup registrations,
    relevant scheduled tasks, AppX package names, and the policies managed by install.ps1.
    It deliberately omits process command lines and startup commands so the report cannot
    accidentally collect tokens or other command-line secrets.

.PARAMETER Label
    Short name used in the report and output filename, such as stock or optimized.

.PARAMETER OutputDirectory
    Destination for JSON reports. Defaults to %LOCALAPPDATA%\workstation-audits.

.PARAMETER NoFile
    Print the summary without writing a JSON report.

.EXAMPLE
    pwsh windows\audit.ps1 -Label stock
    pwsh windows\audit.ps1 -Label optimized
#>
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()][string]$Label = 'snapshot',
    [string]$OutputDirectory,
    [switch]$NoFile
)

. "$PSScriptRoot\..\_lib.ps1"
Assert-PowerShell7

function Get-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    if (-not (Test-Path $Path)) { return $null }
    $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    return $item.$Name
}

function Get-TaskState {
    param(
        [Parameter(Mandatory)][string]$TaskPath,
        [Parameter(Mandatory)][string]$TaskName
    )
    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $task) { return 'NotPresent' }
    return [string]$task.State
}

function Get-AcPowerTimeoutSeconds {
    param([Parameter(Mandatory)][string]$SettingAlias)
    $output = & powercfg /query SCHEME_CURRENT SUB_SLEEP $SettingAlias 2>$null | Out-String
    if ($LASTEXITCODE -ne 0) { return $null }
    # The final two hexadecimal values are AC and DC. This avoids depending on localized
    # labels such as "Current AC Power Setting Index".
    $values = @([regex]::Matches($output, '0x([0-9a-fA-F]{8})') |
            ForEach-Object { [Convert]::ToUInt32($_.Groups[1].Value, 16) })
    if ($values.Count -lt 2) { return $null }
    return $values[$values.Count - 2]
}

Write-Step "Windows audit - $Label"
Write-Host '  read-only: no services, tasks, packages, registry values, or settings are changed' -ForegroundColor DarkGray

$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$processes = @(Get-CimInstance Win32_Process)
$services = @(Get-CimInstance Win32_Service)
$startup = @(Get-CimInstance Win32_StartupCommand)
$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
$appx = @(Get-AppxPackage -ErrorAction SilentlyContinue)

$cpuLoad = $null
try {
    $cpuLoad = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
}
catch {
    Write-Warn2 'instantaneous CPU load was unavailable; the rest of the audit is complete'
}

$processGroups = @($processes |
    Group-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            Name         = $_.Name
            Instances    = $_.Count
            WorkingSetMB = [math]::Round((($_.Group | Measure-Object WorkingSetSize -Sum).Sum / 1MB), 1)
        }
    } |
    Sort-Object WorkingSetMB -Descending)

$automaticServices = @($services |
    Where-Object StartMode -eq 'Auto' |
    Sort-Object Name |
    Select-Object Name, DisplayName, State, StartMode)

$startupEntries = @($startup |
    Sort-Object Name, Location, User |
    Select-Object Name, Location, User)

$nonMicrosoftTasks = @($tasks |
    Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
    Sort-Object TaskPath, TaskName |
    Select-Object TaskPath, TaskName, State)

$diagnosticTasks = @(
    [pscustomobject]@{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser Exp' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'ProgramDataUpdater' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\Application Experience\'; Name = 'StartupAppTask' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'UsbCeip' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\DiskDiagnostic\'; Name = 'Microsoft-Windows-DiskDiagnosticDataCollector' }
    [pscustomobject]@{ Path = '\Microsoft\Windows\Autochk\'; Name = 'Proxy' }
)
$diagnosticTaskStates = @($diagnosticTasks | ForEach-Object {
        [pscustomobject]@{
            TaskPath = $_.Path
            TaskName = $_.Name
            State    = Get-TaskState -TaskPath $_.Path -TaskName $_.Name
        }
    })

$dataCollection = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
$searchPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
$systemPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
$edgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$aiPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'
$deliveryPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'
$explorerAdvanced = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$contentDelivery = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
$international = 'HKCU:\Control Panel\International'

$managedRegistry = @(
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'HideFileExt'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'Hidden'; Expected = 1 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'LaunchTo'; Expected = 1 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'ShowTaskViewButton'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'TaskbarDa'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'TaskbarMn'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'TaskbarAl'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'ShowSyncProviderNotifications'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'Start_IrisRecommendations'; Expected = 0 }
    @{ Area = 'Explorer'; Path = $explorerAdvanced; Name = 'Start_TrackProgs'; Expected = 0 }
    @{ Area = 'Explorer'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name = 'SearchboxTaskbarMode'; Expected = 0 }
    @{ Area = 'Explorer'; Path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Name = '(Default)'; Expected = '' }
    @{ Area = 'Regional'; Path = $international; Name = 'sShortDate'; Expected = 'dd/MM/yyyy' }
    @{ Area = 'Regional'; Path = $international; Name = 'sLongDate'; Expected = 'dddd, d MMMM yyyy' }
    @{ Area = 'Regional'; Path = $international; Name = 'iDate'; Expected = '1' }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'ContentDeliveryAllowed'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'OemPreInstalledAppsEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'PreInstalledAppsEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'PreInstalledAppsEverEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'SilentInstalledAppsEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'SoftLandingEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'SystemPaneSuggestionsEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'RotatingLockScreenEnabled'; Expected = 0 }
    @{ Area = 'Consumer'; Path = $contentDelivery; Name = 'RotatingLockScreenOverlayEnabled'; Expected = 0 }
    @{ Area = 'Privacy'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name = 'Enabled'; Expected = 0 }
    @{ Area = 'Privacy'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'; Name = 'TailoredExperiencesWithDiagnosticDataEnabled'; Expected = 0 }
    @{ Area = 'Privacy'; Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiencesWithDiagnosticData'; Expected = 1 }
    @{ Area = 'Privacy'; Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'DisableSearchBoxSuggestions'; Expected = 1 }
    @{ Area = 'Privacy'; Path = $searchPolicy; Name = 'AllowCloudSearch'; Expected = 0 }
    @{ Area = 'Privacy'; Path = $searchPolicy; Name = 'EnableDynamicContentInWSB'; Expected = 0 }
    @{ Area = 'Privacy'; Path = $systemPolicy; Name = 'PublishUserActivities'; Expected = 0 }
    @{ Area = 'Privacy'; Path = $systemPolicy; Name = 'UploadUserActivities'; Expected = 0 }
    @{ Area = 'AI'; Path = $aiPolicy; Name = 'DisableAIDataAnalysis'; Expected = 1 }
    @{ Area = 'AI'; Path = $aiPolicy; Name = 'DisableClickToDo'; Expected = 1 }
    @{ Area = 'AI'; Path = 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Expected = 1 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'BackgroundModeEnabled'; Expected = 0 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'StartupBoostEnabled'; Expected = 0 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'HideFirstRunExperience'; Expected = 1 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'DefaultBrowserSettingEnabled'; Expected = 0 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'DiagnosticData'; Expected = 0 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'UrlDiagnosticDataEnabled'; Expected = 0 }
    @{ Area = 'Edge'; Path = $edgePolicy; Name = 'PersonalizationReportingEnabled'; Expected = 0 }
    @{ Area = 'Power'; Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Expected = 0 }
    @{ Area = 'SignIn'; Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; Name = 'NoLockScreen'; Expected = 1 }
    @{ Area = 'Telemetry'; Path = $dataCollection; Name = 'AllowTelemetry'; Expected = 1 }
    @{ Area = 'Telemetry'; Path = $dataCollection; Name = 'LimitDiagnosticLogCollection'; Expected = 1 }
    @{ Area = 'Telemetry'; Path = $dataCollection; Name = 'LimitDumpCollection'; Expected = 1 }
    @{ Area = 'Telemetry'; Path = $dataCollection; Name = 'DoNotShowFeedbackNotifications'; Expected = 1 }
    @{ Area = 'Updates'; Path = $deliveryPolicy; Name = 'DODownloadMode'; Expected = 0 }
)
$managedRegistryState = @($managedRegistry | ForEach-Object {
        $actual = Get-RegValue $_.Path $_.Name
        [pscustomobject]@{
            Area      = $_.Area
            Path      = $_.Path
            Name      = $_.Name
            Expected  = $_.Expected
            Actual    = $actual
            Compliant = $null -ne $actual -and $actual -eq $_.Expected
        }
    })

$activePowerText = & powercfg /getactivescheme 2>$null | Out-String
$activePowerGuid = if ($activePowerText -match '(?i)([a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12})') {
    $Matches[1].ToLowerInvariant()
}
else { $null }
$balancedGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
$acStandbySeconds = Get-AcPowerTimeoutSeconds 'STANDBYIDLE'
$acHibernateSeconds = Get-AcPowerTimeoutSeconds 'HIBERNATEIDLE'

$debloatReadme = Join-Path $PSScriptRoot 'README.md'
$wantedAppxRemovals = @(Get-IdsFromReadme $debloatReadme @('Inbox apps'))
$remainingAppxRemovals = @($wantedAppxRemovals | Where-Object {
        $name = $_
        @($appx | Where-Object Name -like "$name*").Count -gt 0
    })
$wantedWin32Removals = @(Get-IdsFromReadme $debloatReadme @('Win32 apps'))
$remainingWin32Removals = if (Test-Cmd winget) {
    @($wantedWin32Removals | Where-Object { Test-WingetInstalled $_ })
}
else { @() }

$report = [ordered]@{
    SchemaVersion = 2
    Timestamp     = (Get-Date).ToString('o')
    Label         = $Label
    ComputerName  = $env:COMPUTERNAME
    OperatingSystem = [ordered]@{
        Caption      = $os.Caption
        Edition      = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
        Version      = $os.Version
        Build        = $os.BuildNumber
        LastBootTime = $os.LastBootUpTime
    }
    Hardware = [ordered]@{
        Processor     = $cpu.Name
        LogicalCores  = $computer.NumberOfLogicalProcessors
        TotalMemoryGB = [math]::Round(($computer.TotalPhysicalMemory / 1GB), 1)
    }
    Summary = [ordered]@{
        ProcessCount             = $processes.Count
        ServiceHostProcessCount  = @($processes | Where-Object Name -eq 'svchost.exe').Count
        RunningServiceCount      = @($services | Where-Object State -eq 'Running').Count
        AutomaticServiceCount    = $automaticServices.Count
        StartupEntryCount        = $startupEntries.Count
        NonMicrosoftTaskCount    = $nonMicrosoftTasks.Count
        CurrentUserAppxCount     = $appx.Count
        CpuLoadPercentAtCapture  = $cpuLoad
        FreeMemoryGBAtCapture    = [math]::Round(($os.FreePhysicalMemory * 1KB / 1GB), 1)
    }
    ProcessGroups             = $processGroups
    AutomaticServices         = $automaticServices
    StartupEntries            = $startupEntries
    NonMicrosoftScheduledTasks = $nonMicrosoftTasks
    CurrentUserAppxPackages   = @($appx | Sort-Object Name | Select-Object Name, Version)
    ManagedRegistryState     = $managedRegistryState
    PowerState = [ordered]@{
        ActiveSchemeGuid          = $activePowerGuid
        BalancedSchemeExpected    = $balancedGuid
        IsBalanced                = $activePowerGuid -eq $balancedGuid
        AcStandbyTimeoutSeconds   = $acStandbySeconds
        AcHibernateTimeoutSeconds = $acHibernateSeconds
        FastStartupEnabled        = Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled'
    }
    DebloatState = [ordered]@{
        Scope                         = 'CurrentUser'
        DeclaredAppxRemovals          = $wantedAppxRemovals
        RemainingAppxRemovals         = $remainingAppxRemovals
        DeclaredWin32Removals         = $wantedWin32Removals
        RemainingVisibleWin32Removals = $remainingWin32Removals
    }
    PrivacyState = [ordered]@{
        Services = @($services |
            Where-Object { $_.Name -in @('WbioSrvc', 'lfsvc', 'MapsBroker', 'PhoneSvc',
                    'DiagTrack', 'dmwappushservice') -or $_.Name -like 'CDPUserSvc*' } |
            Sort-Object Name |
            Select-Object Name, State, StartMode)
        DiagnosticTasks                   = $diagnosticTaskStates
        AllowTelemetry                    = Get-RegValue $dataCollection 'AllowTelemetry'
        DoNotShowFeedbackNotifications    = Get-RegValue $dataCollection 'DoNotShowFeedbackNotifications'
        AllowCloudSearch                  = Get-RegValue $searchPolicy 'AllowCloudSearch'
        SearchHighlights                  = Get-RegValue $searchPolicy 'EnableDynamicContentInWSB'
        PublishUserActivities             = Get-RegValue $systemPolicy 'PublishUserActivities'
        UploadUserActivities              = Get-RegValue $systemPolicy 'UploadUserActivities'
        DisableAIDataAnalysis             = Get-RegValue $aiPolicy 'DisableAIDataAnalysis'
        DisableClickToDo                  = Get-RegValue $aiPolicy 'DisableClickToDo'
        DeliveryOptimizationDownloadMode  = Get-RegValue $deliveryPolicy 'DODownloadMode'
        EdgeDiagnosticData                = Get-RegValue $edgePolicy 'DiagnosticData'
        EdgePersonalizationReporting      = Get-RegValue $edgePolicy 'PersonalizationReportingEnabled'
    }
}

Write-Host "  processes $($report.Summary.ProcessCount) · service hosts $($report.Summary.ServiceHostProcessCount) · running services $($report.Summary.RunningServiceCount)"
Write-Host "  startup entries $($report.Summary.StartupEntryCount) · current-user AppX packages $($report.Summary.CurrentUserAppxCount)"
Write-Host "  CPU $($report.Summary.CpuLoadPercentAtCapture)% · free memory $($report.Summary.FreeMemoryGBAtCapture) GB" -ForegroundColor DarkGray
$policyOk = @($managedRegistryState | Where-Object Compliant).Count
Write-Host "  managed registry $policyOk/$($managedRegistryState.Count) compliant · Balanced $($report.PowerState.IsBalanced) · AC sleep $acStandbySeconds s" -ForegroundColor DarkGray
Write-Host "  debloat remaining: $($remainingAppxRemovals.Count) AppX · $($remainingWin32Removals.Count) Win32" -ForegroundColor DarkGray

if ($NoFile) {
    Write-Skip 'NoFile selected - report was not written'
    exit 0
}

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'workstation-audits'
}
$safeLabel = ($Label -replace '[^A-Za-z0-9._-]', '-').Trim('-')
if (-not $safeLabel) { $safeLabel = 'snapshot' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputPath = Join-Path $OutputDirectory "$(Get-Date -Format 'yyyy-MM-dd_HHmmss')-$safeLabel.json"
$report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Ok "report -> $outputPath"
exit 0
