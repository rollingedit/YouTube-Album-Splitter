@echo off
set "BAT_PATH=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:BAT_PATH; $c=Get-Content -LiteralPath $p -Raw; $m='# POWERSHELL_' + 'PAYLOAD'; $parts=$c -split [regex]::Escape($m),2; Invoke-Expression $parts[1]"
set "ERR=%ERRORLEVEL%"
if not "%ERR%"=="0" (
    echo.
    echo YouTube Album Splitter stopped before it could finish.
    echo If an error message appeared above, copy it or screenshot this window.
    echo.
    pause
)
exit /b %ERR%

# POWERSHELL_PAYLOAD
$ErrorActionPreference = "Stop"

function Get-TableFlipText {
    return '(' + [char]0x256F + [char]0x00B0 + [char]0x25A1 + [char]0x00B0 + ')' + [char]0x256F + [char]0xFE35 + ' ' + [char]0x253B + [char]0x2501 + [char]0x253B
}

function Enable-AnsiOutput {
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
    try {
        if (-not ('VtConsole' -as [type])) {
            Add-Type -ErrorAction Stop -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class VtConsole {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
    public static bool Enable() {
        IntPtr handle = GetStdHandle(-11);
        uint mode;
        if (!GetConsoleMode(handle, out mode)) { return false; }
        return SetConsoleMode(handle, mode | 0x0004);
    }
}
'@
        }
        return [VtConsole]::Enable()
    } catch {
        return $false
    }
}

function Get-Cmd {
    param([Parameter(Mandatory = $true)][string]$Text)

    if (-not $script:AnsiEnabled) {
        return $Text
    }
    $esc = [char]27
    return "$esc[96m$Text$esc[0m"
}

function Show-TableFlip {
    $deg  = [char]0x00B0
    $box  = [char]0x25A1
    $arm  = [char]0x256F
    $wave = [char]0xFE35
    $tableUp   = [string]([char]0x2533) + [char]0x2501 + [char]0x2533
    $tableDown = [string]([char]0x253B) + [char]0x2501 + [char]0x253B

    $frames = @(
        "($deg$box$deg)    $tableUp",
        "($arm$deg$box$deg)$arm    $tableUp",
        "($arm$deg$box$deg)$arm $wave  $tableDown",
        "($arm$deg$box$deg)$arm$wave $tableDown"
    )

    $lastLen = 0
    foreach ($frame in ($frames + $frames)) {
        $pad = if ($lastLen -gt $frame.Length) { ' ' * ($lastLen - $frame.Length) } else { '' }
        Write-Host -NoNewline ("`r$frame$pad")
        $lastLen = [Math]::Max($lastLen, $frame.Length)
        Start-Sleep -Milliseconds 220
    }

    try { $width = [Console]::WindowWidth } catch { $width = 80 }
    Write-Host -NoNewline ("`r{0}`r" -f (' ' * ([Math]::Min($width - 1, $lastLen + 8))))

    $final = Get-TableFlipText
    if ($script:AnsiEnabled) {
        $esc = [char]27
        Write-Host "$esc[92m$final$esc[0m Done."
    } else {
        Write-Host "$final Done."
    }
    Start-Sleep -Milliseconds 350
}

function Get-Colored {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [string]$Color = ""
    )

    if (-not $script:AnsiEnabled -or [string]::IsNullOrEmpty($Color)) {
        return $Text
    }
    $codes = @{ "red" = "91"; "yellow" = "93"; "green" = "92"; "cyan" = "96"; "gray" = "90" }
    if (-not $codes.ContainsKey($Color)) {
        return $Text
    }
    $esc = [char]27
    return "$esc[$($codes[$Color])m$Text$esc[0m"
}

function Get-VisibleLength {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) {
        return 0
    }
    $esc = [regex]::Escape([string][char]27)
    return ($Text -replace "$esc\[[0-9;]*m", "").Length
}

function Clip-StatusLine {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][int]$MaxVisibleLength
    )

    $esc = [char]27
    $builder = New-Object System.Text.StringBuilder
    $visible = 0
    $index = 0
    $sawAnsi = $false

    while ($index -lt $Text.Length) {
        if ($Text[$index] -eq $esc) {
            [void]$builder.Append($Text[$index])
            $index++
            if ($index -lt $Text.Length -and $Text[$index] -eq '[') {
                [void]$builder.Append($Text[$index])
                $index++
                while ($index -lt $Text.Length -and $Text[$index] -ne 'm') {
                    [void]$builder.Append($Text[$index])
                    $index++
                }
                if ($index -lt $Text.Length) {
                    [void]$builder.Append($Text[$index])
                    $index++
                }
            }
            $sawAnsi = $true
            continue
        }

        if ($visible -ge $MaxVisibleLength) {
            break
        }

        [void]$builder.Append($Text[$index])
        $visible++
        $index++
    }

    if ($sawAnsi) {
        [void]$builder.Append("$esc[0m")
    }

    return $builder.ToString()
}

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host ("{0} {1}" -f (Get-Colored -Text ([string][char]0x2713) -Color "green"), $Message)
}

function Get-PercentBar {
    param(
        [object]$Percent,
        [int]$Width = 10
    )

    if ($null -eq $Percent) {
        return ""
    }
    $value = [double]$Percent
    if ($value -lt 0) { $value = 0 }
    if ($value -gt 100) { $value = 100 }
    $filled = [int][Math]::Round(($value / 100.0) * $Width)
    if ($filled -gt $Width) { $filled = $Width }
    if ($filled -lt 0) { $filled = 0 }
    $bar = ([string][char]0x2588) * $filled + ([string][char]0x2591) * ($Width - $filled)
    return "[$bar] {0}%" -f [int][Math]::Round($value)
}

function Get-CountText {
    param(
        [Parameter(Mandatory = $true)][int]$Current,
        [Parameter(Mandatory = $true)][int]$Total
    )

    $digits = ([string]$Total).Length
    return "({0}/{1})" -f $Current.ToString().PadLeft($digits), $Total
}

function Write-Mascot {
    param(
        [Parameter(Mandatory = $true)][string]$Face,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Color = ""
    )

    Write-Host ("{0} {1}" -f (Get-Colored -Text $Face -Color $Color), $Message)
}

function Get-YouTubeVideoIdFromUrl {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        $uri = [Uri]$Url
    } catch {
        return ""
    }

    if ($uri.Host -match '(^|\.)youtu\.be$') {
        return $uri.AbsolutePath.Trim('/').Split('/')[0]
    }

    if ($uri.AbsolutePath -match '^/(shorts|live|embed)/([^/?#]+)') {
        return $Matches[2]
    }

    $queryMatch = [regex]::Match($uri.Query, '(?:^\?|&)v=([^&]+)')
    if ($queryMatch.Success) {
        return [Uri]::UnescapeDataString($queryMatch.Groups[1].Value)
    }

    return ""
}

function Test-YouTubeVideoIdLooksIncomplete {
    param([Parameter(Mandatory = $true)][string]$Url)

    $videoId = Get-YouTubeVideoIdFromUrl -Url $Url
    return (-not [string]::IsNullOrWhiteSpace($videoId)) -and ($videoId -notmatch '^[A-Za-z0-9_-]{11}$')
}

function Invoke-WithMascotStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @(),
        [string]$ProgressText = "",
        [string]$Style = "Blink",
        [int]$InitialDelayMs = 0
    )

    $faces = @(
        ' (o_o) ',
        ' (o_o) ',
        ' (-_-) ',
        ' (o_o) ',
        '( o_-) ',
        ' (o_o) ',
        ' (-_o )',
        ' (o_o) '
    )
    $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    $i = 0
    $lastLineLength = 0
    Initialize-MascotStatusLine

    try {
        if ($InitialDelayMs -gt 0) {
            Start-Sleep -Milliseconds $InitialDelayMs
        }

        while ($job.State -eq "Running") {
            if ($Style -eq "AacTravel") {
                $line = Get-AacTravelStatusLine -Message $Message -ProgressText $ProgressText -Frame $i
                Write-RawMascotStatusLine -Line $line -LastLineLength ([ref]$lastLineLength)
                Start-Sleep -Milliseconds 95
            } elseif ($Style -eq "PlainProgress") {
                Write-MascotStatusLine -Message $Message -DotField "" -ProgressText $ProgressText -LastLineLength ([ref]$lastLineLength)
                Start-Sleep -Milliseconds 140
            } else {
                $face = $faces[$i % $faces.Count]
                $dots = "." * (($i % 4) + 1)
                $dotField = $dots.PadRight(4)
                Write-MascotStatusLine -Face $face -Message $Message -DotField $dotField -ProgressText $ProgressText -LastLineLength ([ref]$lastLineLength)
                Start-Sleep -Milliseconds (Get-Random -Minimum 120 -Maximum 700)
            }
            $i++
        }

        try {
            $width = [Console]::WindowWidth
        } catch {
            $width = 80
        }
        Write-Host -NoNewline ("`r{0}`r" -f (' ' * ([Math]::Min($width - 1, $lastLineLength + 1))))

        $result = Receive-Job -Job $job
        if ($job.State -eq "Failed") {
            throw ($job.ChildJobs[0].JobStateInfo.Reason)
        }
        return $result
    } finally {
        Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
    }
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"

    # Make sure the App Execution Alias folder (where the winget alias lives) is
    # reachable, even if it was missing from the saved PATH.
    $windowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    if ((Test-Path -LiteralPath $windowsApps) -and (($env:Path -split ';') -notcontains $windowsApps)) {
        $env:Path = "$env:Path;$windowsApps"
    }
}

function Resolve-WingetPath {
    if ($script:WingetPath -and (Test-Path -LiteralPath $script:WingetPath)) {
        return $script:WingetPath
    }

    $command = Get-Command winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        $command = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source)) {
        $script:WingetPath = $command.Source
        return $script:WingetPath
    }

    $aliasPath = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
    if (Test-Path -LiteralPath $aliasPath) {
        $script:WingetPath = $aliasPath
        return $script:WingetPath
    }

    try {
        $package = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
        if ($package -and $package.InstallLocation) {
            $packageWinget = Join-Path $package.InstallLocation "winget.exe"
            if (Test-Path -LiteralPath $packageWinget) {
                $script:WingetPath = $packageWinget
                return $script:WingetPath
            }
        }
    } catch {}

    return $null
}

function Invoke-Winget {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $winget = Resolve-WingetPath
    if (-not $winget) {
        throw "winget is not available."
    }
    & $winget @Arguments
}

function Show-WingetMissingHelp {
    Write-Host ""
    Write-Mascot "(o_o?)" "Windows could not find 'winget', the App Installer tool this needs." -Color "yellow"
    Write-Host "This usually means Windows 'App Installer' is missing or out of date."
    Write-Host ""
    Write-Host "To fix it:"
    Write-Host "  1. Open Microsoft Store (this file will try to open it for you)."
    Write-Host "  2. Search for 'App Installer', then click Update, or Get if it is missing."
    Write-Host "  3. Close this window and run this file again."
    Write-Host ""
    Write-Host "If the Store is blocked on this PC, winget can also be turned off under:"
    Write-Host "  Settings > Apps > Advanced app settings > App execution aliases > App Installer (winget.exe)."
    $storeOpened = $false
    if (Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue) {
        try {
            Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1" -ErrorAction Stop | Out-Null
            $storeOpened = $true
        } catch {
            $storeOpened = $false
        }
    }
    if (-not $storeOpened) {
        try { Start-Process "https://apps.microsoft.com/detail/9NBLGGH4NNS1" -ErrorAction SilentlyContinue | Out-Null } catch {}
    }
}

function Ensure-Command {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string]$WingetId,
        [Parameter(Mandatory = $true)][string]$Name
    )

    Refresh-Path
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Host "$Name found."
        return
    }

    if (-not (Resolve-WingetPath)) {
        Show-WingetMissingHelp
        throw "Windows App Installer / winget is missing or out of date. Follow the steps above, then run this file again."
    }

    Write-Host "$Name not found. Installing it now..."
    Invoke-Winget -Arguments @("install", "--id", $WingetId, "-e", "--accept-package-agreements", "--accept-source-agreements")
    Refresh-Path

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Name was installed, but Windows has not exposed it in PATH yet. Close this window and run this file again."
    }

    Write-Host "$Name installed."
}

function Resolve-PythonCommand {
    Refresh-Path

    $candidates = @(
        @{ Command = "py"; Args = @("-3") },
        @{ Command = "python"; Args = @() },
        @{ Command = "python3"; Args = @() }
    )

    foreach ($candidate in $candidates) {
        $command = Get-Command $candidate.Command -ErrorAction SilentlyContinue
        if (-not $command) {
            continue
        }

        $allArgs = @()
        $allArgs += $candidate.Args
        $allArgs += @("-c", "import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)")

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & $command.Source @allArgs *> $null
            $pythonCheckExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        if ($pythonCheckExitCode -eq 0) {
            return [pscustomobject]@{
                Command = $command.Source
                Args = $candidate.Args
            }
        }
    }

    return $null
}

function Ensure-PythonCommand {
    $script:PythonCommand = Resolve-PythonCommand
    if ($script:PythonCommand) {
        Write-Host "Python found."
        return
    }

    if (-not (Resolve-WingetPath)) {
        Show-WingetMissingHelp
        throw "Windows App Installer / winget is missing or out of date. Follow the steps above, then run this file again."
    }

    Write-Host "Python not found. Installing it now..."
    Invoke-Winget -Arguments @("install", "--id", "Python.Python.3.12", "-e", "--accept-package-agreements", "--accept-source-agreements")
    Refresh-Path

    $script:PythonCommand = Resolve-PythonCommand
    if (-not $script:PythonCommand) {
        throw "Python was installed, but Windows has not exposed it in PATH yet. Close this window and run this file again."
    }

    Write-Host "Python installed."
}

function Invoke-Python {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    if (-not $script:PythonCommand) {
        $script:PythonCommand = Resolve-PythonCommand
    }

    if (-not $script:PythonCommand) {
        throw "Python is not available."
    }

    $allArgs = @()
    $allArgs += $script:PythonCommand.Args
    $allArgs += $Arguments
    & $script:PythonCommand.Command @allArgs
}

function Remove-StaleAacWorkFiles {
    param([Parameter(Mandatory = $true)][string]$Root)

    $staleFiles = Get-ChildItem -LiteralPath $Root -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\..*\.(tmp|backup)\.m4a$|^\..*\.cover\.tmp\.jpg$' }

    foreach ($file in $staleFiles) {
        Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Convert-ExistingOpusToAac {
    param([Parameter(Mandatory = $true)][string]$Root)

    Remove-StaleAacWorkFiles -Root $Root

    $opusFiles = Get-ChildItem -LiteralPath $Root -Recurse -Filter "*.opus" -File -ErrorAction SilentlyContinue
    if (-not $opusFiles) {
        Write-Host ""
        Write-Mascot "(._.)" "No Opus files found in: $Root"
        Remove-StaleAacWorkFiles -Root $Root
        return
    }

    Write-Host ""
    Write-Host "Converting Opus files to AAC .m4a..."
    Write-Host "Folder: $Root"

    $folderCount = ($opusFiles | ForEach-Object { $_.DirectoryName } | Sort-Object -Unique | Measure-Object).Count
    Write-Host ""
    Write-Host "Found $($opusFiles.Count) Opus file(s) in $folderCount album folder(s)."
    Write-Host "This will convert them to AAC .m4a and remove each Opus original after successful conversion."
    $confirmAac = Read-Host "Continue? Type $(Get-Cmd 'yes') to continue"
    if ($confirmAac.Trim() -ine "yes") {
        Write-Mascot "(u_u)" "AAC conversion cancelled."
        return
    }

    Write-Host ""
    Write-Host "Preparing M4A tag fixer..."
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        Invoke-Python -Arguments @("-c", "import mutagen") 2>$null
        $mutagenCheckExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($mutagenCheckExitCode -ne 0) {
        Invoke-Python -Arguments @("-m", "pip", "install", "--user", "mutagen")
    }

    $M4aTagScript = Join-Path $env:TEMP ("fix_m4a_tags." + [guid]::NewGuid().ToString("N") + ".py")
    @'
from __future__ import annotations

import re
import sys
import base64
from pathlib import Path

from mutagen.flac import Picture
from mutagen.mp4 import MP4, MP4Cover
from mutagen.oggopus import OggOpus

opus_path = Path(sys.argv[1])
m4a_path = Path(sys.argv[2])

NAME = b"\xa9nam".decode("latin-1")
ARTIST = b"\xa9ART".decode("latin-1")
ALBUM = b"\xa9alb".decode("latin-1")

def first(tags, *names):
    for name in names:
        value = tags.get(name)
        if value:
            if isinstance(value, (list, tuple)):
                return str(value[0])
            return str(value)
    return ""

def cover_from_opus(tags):
    pictures = tags.get("metadata_block_picture")
    if not pictures:
        return None

    try:
        picture = Picture(base64.b64decode(pictures[0]))
    except Exception:
        return None

    image_format = MP4Cover.FORMAT_PNG if picture.mime == "image/png" else MP4Cover.FORMAT_JPEG
    return MP4Cover(picture.data, imageformat=image_format)

source = OggOpus(opus_path)
audio = MP4(m4a_path)
audio.clear()

title = first(source, "title") or re.sub(r"^\d+\.\s*", "", opus_path.stem).strip()
artist = first(source, "artist")
album = first(source, "album")
album_artist = first(source, "albumartist", "album_artist")
track_text = first(source, "tracknumber", "track")
track_match = re.search(r"\d+", track_text)

if title:
    audio[NAME] = [title]
if artist:
    audio[ARTIST] = [artist]
if album:
    audio[ALBUM] = [album]
if album_artist:
    audio["aART"] = [album_artist]
if track_match:
    audio["trkn"] = [(int(track_match.group(0)), 0)]

cover = cover_from_opus(source)
if cover is not None:
    audio["covr"] = [cover]

audio.save()
'@ | Set-Content -LiteralPath $M4aTagScript -Encoding UTF8

    $converted = 0
    $replaced = 0
    $failed = 0
    $deleted = 0
    $aacIndex = 0

    foreach ($opus in $opusFiles) {
        $aacIndex++
        $aacPath = [System.IO.Path]::ChangeExtension($opus.FullName, ".m4a")
        $aacWorkId = [guid]::NewGuid().ToString("N")
        $tempAacPath = Join-Path $opus.DirectoryName ("." + $opus.BaseName + ".$aacWorkId.tmp.m4a")
        $backupAacPath = Join-Path $opus.DirectoryName ("." + $opus.BaseName + ".$aacWorkId.backup.m4a")
        $hadExistingAac = $false
        if (Test-Path -LiteralPath $aacPath) {
            Write-Host "Replacing existing AAC: $([System.IO.Path]::GetFileName($aacPath))"
            Move-Item -LiteralPath $aacPath -Destination $backupAacPath -Force
            $hadExistingAac = $true
            $replaced++
        }

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $ffmpegResult = Invoke-WithMascotStatus -Message "Converting AAC: $($opus.Name)" -ProgressText (Get-CountText -Current $aacIndex -Total $opusFiles.Count) -Style "AacTravel" -ScriptBlock {
                param([string]$InputPath, [string]$OutputPath)
                $output = & ffmpeg -hide_banner -y -i $InputPath -map "0:a:0" -vn -dn -sn -map_chapters -1 -map_metadata -1 -c:a aac -b:a 192k $OutputPath 2>&1
                [pscustomobject]@{
                    Output = @($output)
                    ExitCode = $LASTEXITCODE
                }
            } -ArgumentList @($opus.FullName, $tempAacPath)
            $ffmpegOutput = @($ffmpegResult.Output)
            $ffmpegExitCode = $ffmpegResult.ExitCode
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $tempAacFile = Get-Item -LiteralPath $tempAacPath -ErrorAction SilentlyContinue
        if ($ffmpegExitCode -eq 0 -and $tempAacFile -and $tempAacFile.Length -gt 0) {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $tagOutput = Invoke-Python -Arguments @($M4aTagScript, $opus.FullName, $tempAacPath) 2>&1
                $tagExitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $previousErrorActionPreference
            }

            if ($tagExitCode -ne 0) {
                $failed++
                if (Test-Path -LiteralPath $tempAacPath) {
                    Remove-Item -LiteralPath $tempAacPath -Force
                }
                if ($hadExistingAac -and (Test-Path -LiteralPath $backupAacPath)) {
                    Move-Item -LiteralPath $backupAacPath -Destination $aacPath -Force
                }
                Write-Mascot "(>_<)" "Could not tag AAC file: $($opus.Name)" -Color "red"
                Write-Host "Kept original Opus file."
                $tagOutput | Select-Object -Last 6 | ForEach-Object { Write-Host $_ }
                continue
            }

            try {
                Move-Item -LiteralPath $tempAacPath -Destination $aacPath -Force
                Remove-Item -LiteralPath $opus.FullName -Force
                if (Test-Path -LiteralPath $backupAacPath) {
                    Remove-Item -LiteralPath $backupAacPath -Force
                }
                $converted++
                $deleted++
            } catch {
                $failed++
                if (Test-Path -LiteralPath $tempAacPath) {
                    Remove-Item -LiteralPath $tempAacPath -Force
                }
                if (Test-Path -LiteralPath $aacPath) {
                    Remove-Item -LiteralPath $aacPath -Force
                }
                if ($hadExistingAac -and (Test-Path -LiteralPath $backupAacPath)) {
                    Move-Item -LiteralPath $backupAacPath -Destination $aacPath -Force
                }
                Write-Mascot "(>_<)" "Could not finalize AAC file: $($opus.Name)" -Color "red"
                Write-Host "Kept original Opus file."
            }
            continue
        }

        $failed++
        if (Test-Path -LiteralPath $tempAacPath) {
            Remove-Item -LiteralPath $tempAacPath -Force
        }
        if ($hadExistingAac -and (Test-Path -LiteralPath $backupAacPath)) {
            Move-Item -LiteralPath $backupAacPath -Destination $aacPath -Force
        }
        Write-Mascot "(>_<)" "Could not convert: $($opus.Name)" -Color "red"
        Write-Host "Kept original Opus file."
        $ffmpegOutput | Select-Object -Last 6 | ForEach-Object { Write-Host $_ }
    }

    Write-Host ""
    Write-Host "AAC conversion finished. Converted: $converted. Replaced existing AAC: $replaced. Failed: $failed."
    Write-Host "Removed Opus originals after successful AAC conversion: $deleted."
    if (Test-Path -LiteralPath $M4aTagScript) {
        Remove-Item -LiteralPath $M4aTagScript -Force -ErrorAction SilentlyContinue
    }
    Remove-StaleAacWorkFiles -Root $Root
}

function Write-YtDlpFailureIfNonRetryable {
    param([Parameter(Mandatory = $true)][string]$Text)

    if ($Text -match 'is not a valid URL|Unsupported URL|Invalid URL') {
        Write-Host ""
        Write-Mascot "(o_o?)" "That does not look like a valid YouTube video link." -Color "yellow"
        Write-Host "Copy the full link from YouTube and try again."
        return $true
    }

    if ($Text -match 'Sign in to confirm|not a bot|LOGIN_REQUIRED|confirm you.?re not a bot|cookies from browser') {
        Write-Host ""
        Write-Mascot "(o_o?)" "YouTube is asking this machine to sign in or confirm it is not a bot." -Color "yellow"
        Write-Host "Updating the tools will not fix that."
        Write-Host "Try again later, or try from a different network/browser session."
        return $true
    }

    if ($Text -match 'Incomplete YouTube ID|Video unavailable|This video is unavailable|This video isn.?t available|This video has been removed|Private video|Video not available|Video not found|HTTP Error 404|HTTP Error 410') {
        Write-Host ""
        Write-Mascot "(o_o?)" "YouTube could not find or play that video." -Color "yellow"
        Write-Host "Updating the tools will not fix a missing, private, deleted, or incomplete video link."
        Write-Host "Double-check the pasted link and try again."
        return $true
    }

    return $false
}

function ConvertTo-ProcessArgument {
    param([Parameter(Mandatory = $true)][string]$Argument)

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    # Quote for CommandLineToArgvW: double any backslash run that precedes a quote
    # or the closing quote, and escape embedded quotes. This keeps paths with spaces
    # and YouTube URLs intact when the argument is passed to a directly launched exe.
    $escaped = $Argument -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

function Get-LastDownloadPercent {
    param([string]$Text)

    $matches = [regex]::Matches($Text, '\[download\]\s+([0-9]+(?:\.[0-9]+)?)%')
    if ($matches.Count -eq 0) {
        return $null
    }

    return [double]$matches[$matches.Count - 1].Groups[1].Value
}

function Initialize-MascotStatusLine {
    try {
        $script:MascotStatusLastWidth = [Console]::WindowWidth
    } catch {
        $script:MascotStatusLastWidth = 80
    }
    $script:MascotStatusLastResizeAt = (Get-Date).AddMilliseconds(-200)
    $script:MascotStatusResizeCooldownMs = 100
    $script:MascotStatusWasResizing = $false
}

function Test-MascotStatusResizeStable {
    try {
        $width = [Console]::WindowWidth
    } catch {
        $width = 80
    }

    if (-not $script:MascotStatusResizeCooldownMs) {
        $script:MascotStatusResizeCooldownMs = 100
    }

    if (-not $script:MascotStatusLastResizeAt) {
        $script:MascotStatusLastResizeAt = (Get-Date).AddMilliseconds(-200)
    }

    if ($script:MascotStatusLastWidth -and $width -ne $script:MascotStatusLastWidth) {
        $script:MascotStatusLastResizeAt = Get-Date
        $script:MascotStatusLastWidth = $width
        $script:MascotStatusWasResizing = $true
        return $false
    }

    $script:MascotStatusLastWidth = $width
    return (((Get-Date) - $script:MascotStatusLastResizeAt).TotalMilliseconds -ge $script:MascotStatusResizeCooldownMs)
}

function Write-RawMascotStatusLine {
    param(
        [Parameter(Mandatory = $true)][string]$Line,
        [Parameter(Mandatory = $true)][ref]$LastLineLength
    )

    try {
        $width = [Console]::WindowWidth
    } catch {
        $width = 80
    }

    if (-not (Test-MascotStatusResizeStable)) {
        return
    }

    $maxLineLength = [Math]::Max(20, $width - 1)
    if ($script:MascotStatusWasResizing) {
        Write-Host -NoNewline ("`r{0}`r" -f (' ' * $maxLineLength))
        $LastLineLength.Value = 0
        $script:MascotStatusWasResizing = $false
    }

    $line = Clip-StatusLine -Text $Line -MaxVisibleLength $maxLineLength
    $visibleLength = Get-VisibleLength -Text $line
    $padLength = if ($LastLineLength.Value -gt $visibleLength) { $LastLineLength.Value - $visibleLength } else { 0 }
    $padLength = [Math]::Min($padLength, [Math]::Max(0, $maxLineLength - $visibleLength))
    $pad = if ($padLength -gt 0) { ' ' * $padLength } else { '' }
    Write-Host -NoNewline ("`r{0}{1}" -f $line, $pad)
    $LastLineLength.Value = [Math]::Max($LastLineLength.Value, $visibleLength)
}

function Get-StatusDancer {
    param([Parameter(Mandatory = $true)][int]$Frame)

    $note = [string][char]0x266A
    $frames = @(
        "\(o_o) $note",
        "\(o_o)/",
        "$note (o_o)/",
        "(o_o)"
    )
    return Get-Colored -Text $frames[$Frame % $frames.Count] -Color "cyan"
}

function Get-StatusBlinker {
    param([Parameter(Mandatory = $true)][int]$Frame)

    $frames = @(
        " (o_o) ",
        " (o_o) ",
        " (-_-) ",
        " (o_o) ",
        "( o_-) ",
        " (o_o) ",
        " (-_o )",
        " (o_o) "
    )
    return $frames[$Frame % $frames.Count]
}

function Get-StatusBallAt {
    param(
        [Parameter(Mandatory = $true)][int]$Column,
        [Parameter(Mandatory = $true)][int]$Frame,
        [int]$Direction = 1,
        [int]$TrailLength = 2
    )

    $phases = @([string][char]0x25D0, [string][char]0x25D3, [string][char]0x25D1, [string][char]0x25D2)
    $phase = $phases[$Frame % $phases.Count]
    if ($Direction -ge 0) {
        $trail = [Math]::Min($TrailLength, $Column)
        return (' ' * ($Column - $trail)) + (Get-Colored -Text (('=' * $trail) + $phase) -Color "cyan")
    }
    return (' ' * $Column) + (Get-Colored -Text ($phase + ('=' * $TrailLength)) -Color "cyan")
}

function Get-AacLandedFace {
    param(
        [bool]$Cramped,
        [int]$Phase,
        [string]$Side = "Right"
    )

    if ($Cramped) {
        $angry = @("(>_<)", "(#>_<)", "(>_<#)", "(#>_<)", "(>_<#)")
        return Get-Colored -Text $angry[$Phase % $angry.Count] -Color "red"
    }

    if ($Side -eq "Left") {
        $left = @("(o_o)", "(o_o)", "(-_-)", "(o_o)", "d(o_o)", "d(o_o)")
        $face = $left[$Phase % $left.Count]
        if ($face -eq "d(o_o)") {
            return Get-Colored -Text $face -Color "green"
        }
        return $face
    }

    $right = @("(o_o)", "(o_o)b", "(o_o)b", "(o_o)b", "(-_-)", "(o_o)", "(o_o)")
    $face = $right[$Phase % $right.Count]
    if ($face -eq "(o_o)b") {
        return Get-Colored -Text $face -Color "green"
    }
    return $face
}

function Get-AacTravelStatusLine {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$ProgressText,
        [Parameter(Mandatory = $true)][int]$Frame
    )

    try {
        $width = [Console]::WindowWidth
    } catch {
        $width = 80
    }

    $maxLineLength = [Math]::Max(20, $width - 1)
    $basePrefix = if ([string]::IsNullOrWhiteSpace($ProgressText)) { "" } else { "$ProgressText " }
    $minTravelRoom = 14
    $messageLimit = [Math]::Max(8, $maxLineLength - $basePrefix.Length - $minTravelRoom)
    $displayMessage = $Message
    if ($displayMessage.Length -gt $messageLimit) {
        $displayMessage = $displayMessage.Substring(0, [Math]::Max(5, $messageLimit - 3)).TrimEnd() + "..."
    }

    $prefix = "$basePrefix$displayMessage    "
    $available = $maxLineLength - (Get-VisibleLength -Text $prefix)
    $zone = [Math]::Max(0, [Math]::Min(20, $available - 7))
    $cramped = ($available -lt 13 -or $zone -lt 10)

    $leftDwell = 6
    $rightDwell = if ($cramped) { 7 } else { 7 }
    $cycleLength = $leftDwell + $zone + $rightDwell + $zone
    $step = $Frame % $cycleLength

    if ($step -lt $leftDwell) {
        return $prefix + (Get-AacLandedFace -Cramped $false -Phase $step -Side "Left")
    }

    $travelRightStep = $step - $leftDwell
    if ($travelRightStep -lt $zone) {
        return $prefix + (Get-StatusBallAt -Column ($travelRightStep + 1) -Frame $Frame -Direction 1 -TrailLength 2)
    }

    $rightDwellStep = $travelRightStep - $zone
    if ($rightDwellStep -lt $rightDwell) {
        return $prefix + (' ' * $zone) + (Get-AacLandedFace -Cramped $cramped -Phase $rightDwellStep -Side "Right")
    }

    $travelLeftStep = $rightDwellStep - $rightDwell
    $column = [Math]::Max(0, $zone - $travelLeftStep - 1)
    return $prefix + (Get-StatusBallAt -Column $column -Frame $Frame -Direction -1 -TrailLength 2)
}

function Write-MascotStatusLine {
    param(
        [string]$Face = "",
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$DotField = "",
        [string]$ProgressText = "",
        [string]$TailText = "",
        [Parameter(Mandatory = $true)][ref]$LastLineLength
    )

    try {
        $width = [Console]::WindowWidth
    } catch {
        $width = 80
    }
    $maxLineLength = [Math]::Max(20, $width - 1)
    $progressSuffix = if ([string]::IsNullOrWhiteSpace($ProgressText)) { "" } else { "   $ProgressText" }
    $tailSuffix = if ([string]::IsNullOrWhiteSpace($TailText)) { "" } else { "    $TailText" }
    $prefix = if ([string]::IsNullOrWhiteSpace($Face)) { "" } else { "{0} " -f $Face }
    $reservedLength = (Get-VisibleLength -Text $prefix) + (Get-VisibleLength -Text $DotField) + (Get-VisibleLength -Text $progressSuffix) + (Get-VisibleLength -Text $tailSuffix)
    $messageLimit = [Math]::Max(8, $maxLineLength - $reservedLength)
    $displayMessage = $Message
    if ($displayMessage.Length -gt $messageLimit) {
        $displayMessage = $displayMessage.Substring(0, [Math]::Max(5, $messageLimit - 4)).TrimEnd() + "... "
    }

    $line = "{0}{1}{2}{3}{4}" -f $prefix, $displayMessage, $DotField, $progressSuffix, $tailSuffix
    Write-RawMascotStatusLine -Line $line -LastLineLength $LastLineLength
}

function Clear-MascotStatusLine {
    param([int]$LastLineLength)

    try {
        $width = [Console]::WindowWidth
    } catch {
        $width = 80
    }
    Write-Host -NoNewline ("`r{0}`r" -f (' ' * ([Math]::Min($width - 1, $LastLineLength + 1))))
}

function Invoke-YtDlpDownloadProcess {
    param(
        [Parameter(Mandatory = $true)][object[]]$YtDlpArgs,
        [Parameter(Mandatory = $true)][string]$Message,
        [int]$TrackCount = 0
    )

    $ytDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if (-not $ytDlpCommand) {
        throw "yt-dlp is not available."
    }

    $lastLineLength = 0
    $i = 0
    $process = $null
    $stdoutSub = $null
    $stderrSub = $null
    $captured = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))

    try {
        # Launch yt-dlp directly, with no cmd.exe shell in between, so URL characters
        # like & ? ^ and the %(...)s output template are passed through literally and
        # paths with spaces stay intact. Output is captured asynchronously so the
        # status animation can still show live download progress.
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $ytDlpCommand.Source
        $startInfo.Arguments = ($YtDlpArgs | ForEach-Object { ConvertTo-ProcessArgument ([string]$_) }) -join " "
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo

        $onData = {
            if ($null -ne $EventArgs.Data) {
                [void]$Event.MessageData.Add($EventArgs.Data)
            }
        }
        $stdoutSub = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action $onData -MessageData $captured
        $stderrSub = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action $onData -MessageData $captured

        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        Initialize-MascotStatusLine

        while (-not $process.HasExited) {
            $text = ($captured.ToArray() -join "`n")
            $percent = Get-LastDownloadPercent -Text $text
            $progressText = Get-PercentBar -Percent $percent
            $dots = "." * (($i % 4) + 1)
            $tailText = if ($null -eq $percent) { Get-StatusBlinker -Frame $i } else { Get-StatusDancer -Frame $i }
            Write-MascotStatusLine -Message $Message -DotField $dots.PadRight(4) -ProgressText $progressText -TailText $tailText -LastLineLength ([ref]$lastLineLength)
            Start-Sleep -Milliseconds (Get-Random -Minimum 120 -Maximum 700)
            $i++
        }

        # No-argument WaitForExit flushes the redirected output streams; the short
        # pause lets the PowerShell event handlers drain the last queued lines.
        $process.WaitForExit()
        Start-Sleep -Milliseconds 200
        Clear-MascotStatusLine -LastLineLength $lastLineLength

        $output = @($captured.ToArray() | Where-Object { $_ -ne "" })

        return [pscustomobject]@{
            Output = @($output)
            ExitCode = $process.ExitCode
        }
    } finally {
        if ($process -and -not $process.HasExited) {
            $process.Kill()
        }
        if ($stdoutSub) {
            Unregister-Event -SourceIdentifier $stdoutSub.Name -ErrorAction SilentlyContinue
            Remove-Job -Name $stdoutSub.Name -Force -ErrorAction SilentlyContinue
        }
        if ($stderrSub) {
            Unregister-Event -SourceIdentifier $stderrSub.Name -ErrorAction SilentlyContinue
            Remove-Job -Name $stderrSub.Name -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-YtDlpWithRecovery {
    param(
        [Parameter(Mandatory = $true)][object[]]$YtDlpArgs,
        [Parameter(Mandatory = $true)][string]$Message,
        [Parameter(Mandatory = $true)][string]$RetryMessage,
        [bool]$EchoOutput = $true,
        [string]$ProgressText = ""
    )

    $firstResult = Invoke-WithMascotStatus -Message $Message -ProgressText $ProgressText -ScriptBlock {
        param([object[]]$ArgsForYtDlp)
        $output = & yt-dlp @ArgsForYtDlp 2>&1
        [pscustomobject]@{
            Output = @($output)
            ExitCode = $LASTEXITCODE
        }
    } -ArgumentList (,$YtDlpArgs)
    $firstOutput = @($firstResult.Output)
    if ($EchoOutput) {
        $firstOutput | ForEach-Object { Write-Host $_ }
    }
    if ($firstResult.ExitCode -eq 0) {
        return [pscustomobject]@{
            Succeeded = $true
            Output = $firstOutput
        }
    }

    $firstText = $firstOutput -join "`n"
    if (Write-YtDlpFailureIfNonRetryable -Text $firstText) {
        return [pscustomobject]@{
            Succeeded = $false
            Output = $firstOutput
        }
    }

    Write-Host ""
    if (Resolve-WingetPath) {
        if ($firstText -match 'no such option') {
            Write-Host "yt-dlp looks too old for one of the required options. Updating tools, then trying once more..."
        } else {
            Write-Host "yt-dlp failed. Updating download tools, then trying once more..."
        }
        Invoke-Winget -Arguments @("upgrade", "--id", "yt-dlp.yt-dlp", "-e", "--accept-package-agreements", "--accept-source-agreements")
        Invoke-Winget -Arguments @("upgrade", "--id", "DenoLand.Deno", "-e", "--accept-package-agreements", "--accept-source-agreements")
        Invoke-Winget -Arguments @("upgrade", "--id", "Gyan.FFmpeg", "-e", "--accept-package-agreements", "--accept-source-agreements")
    } else {
        Write-Host "yt-dlp failed, and winget is unavailable, so tool updates were skipped. Trying once more..."
    }

    $ytDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if ($ytDlpCommand -and $ytDlpCommand.Source -match '\\Python\d*\\Scripts\\|\\Python\\PythonCore\\|\\Scripts\\yt-dlp') {
        Write-Host "Detected Python-installed yt-dlp. Updating Python yt-dlp with default extras..."
        Invoke-Python -Arguments @("-m", "pip", "install", "--user", "--upgrade", "yt-dlp[default]", "curl-cffi")
    }

    Refresh-Path

    $retryResult = Invoke-WithMascotStatus -Message $RetryMessage -ProgressText $ProgressText -ScriptBlock {
        param([object[]]$ArgsForYtDlp)
        $output = & yt-dlp @ArgsForYtDlp 2>&1
        [pscustomobject]@{
            Output = @($output)
            ExitCode = $LASTEXITCODE
        }
    } -ArgumentList (,$YtDlpArgs)
    $retryOutput = @($retryResult.Output)
    if ($EchoOutput) {
        $retryOutput | ForEach-Object { Write-Host $_ }
    }
    if ($retryResult.ExitCode -ne 0) {
        $retryText = $retryOutput -join "`n"
        if (Write-YtDlpFailureIfNonRetryable -Text $retryText) {
            return [pscustomobject]@{
                Succeeded = $false
                Output = $retryOutput
            }
        }

        Write-Host ""
        Write-Mascot "(x_x)" "Still couldn't download after updating the tools." -Color "red"
        Write-Host "Common causes:"
        Write-Host "- The link is private, age-restricted, deleted, or region-locked."
        Write-Host "- The link is a playlist/channel instead of one video."
        Write-Host "- The internet connection is blocked or unstable."
        Write-Host "- YouTube changed something and yt-dlp needs another update later."
        Write-Host ""
        Write-Host "Double-check the link and try again."
        Write-Host ""
        return [pscustomobject]@{
            Succeeded = $false
            Output = $retryOutput
        }
    }

    return [pscustomobject]@{
        Succeeded = $true
        Output = $retryOutput
    }
}

function Get-YtDlpMetadata {
    param([Parameter(Mandatory = $true)][string]$Url)

    $metadataArgs = @(
        "--skip-download",
        "--dump-single-json",
        "--no-warnings",
        "--no-playlist",
        "--remote-components", "ejs:github",
        $Url
    )

    $metadataResult = Invoke-YtDlpWithRecovery -YtDlpArgs $metadataArgs -Message "Reading video track info" -RetryMessage "Reading video track info again" -EchoOutput $false
    if (-not $metadataResult.Succeeded) {
        return $null
    }

    try {
        return (($metadataResult.Output -join "`n") | ConvertFrom-Json)
    } catch {
        Write-Mascot "(u_u)" "Could not parse video metadata." -Color "yellow"
        return $null
    }
}

function Invoke-YtDlpDownloadFullAudio {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutDir,
        [int]$TrackCount = 0
    )

    $downloadArgs = @(
        "--force-overwrites",
        "--no-playlist",
        "--newline",
        "--remote-components", "ejs:github",
        "-P", $OutDir,
        "-f", "ba[acodec^=opus]/ba",
        "-x",
        "--audio-format", "opus",
        "--embed-metadata",
        "--embed-thumbnail",
        "--convert-thumbnails", "jpg",
        "-o", "%(title)s [%(id)s].%(ext)s",
        $Url
    )

    $firstResult = Invoke-YtDlpDownloadProcess -YtDlpArgs $downloadArgs -Message "Downloading album audio" -TrackCount $TrackCount
    if ($firstResult.ExitCode -eq 0) {
        return $true
    }

    $firstText = (@($firstResult.Output) -join "`n")
    if (Write-YtDlpFailureIfNonRetryable -Text $firstText) {
        return $false
    }

    Write-Host ""
    if (Resolve-WingetPath) {
        if ($firstText -match 'no such option') {
            Write-Host "yt-dlp looks too old for one of the required options. Updating tools, then trying once more..."
        } else {
            Write-Host "yt-dlp failed. Updating download tools, then trying once more..."
        }
        Invoke-Winget -Arguments @("upgrade", "--id", "yt-dlp.yt-dlp", "-e", "--accept-package-agreements", "--accept-source-agreements")
        Invoke-Winget -Arguments @("upgrade", "--id", "DenoLand.Deno", "-e", "--accept-package-agreements", "--accept-source-agreements")
        Invoke-Winget -Arguments @("upgrade", "--id", "Gyan.FFmpeg", "-e", "--accept-package-agreements", "--accept-source-agreements")
    } else {
        Write-Host "yt-dlp failed, and winget is unavailable, so tool updates were skipped. Trying once more..."
    }

    $ytDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if ($ytDlpCommand -and $ytDlpCommand.Source -match '\\Python\d*\\Scripts\\|\\Python\\PythonCore\\|\\Scripts\\yt-dlp') {
        Write-Host "Detected Python-installed yt-dlp. Updating Python yt-dlp with default extras..."
        Invoke-Python -Arguments @("-m", "pip", "install", "--user", "--upgrade", "yt-dlp[default]", "curl-cffi")
    }

    Refresh-Path

    $retryResult = Invoke-YtDlpDownloadProcess -YtDlpArgs $downloadArgs -Message "Trying the download again" -TrackCount $TrackCount
    if ($retryResult.ExitCode -eq 0) {
        return $true
    }

    $retryText = (@($retryResult.Output) -join "`n")
    if (Write-YtDlpFailureIfNonRetryable -Text $retryText) {
        return $false
    }

    Write-Host ""
    Write-Mascot "(x_x)" "Still couldn't download after updating the tools." -Color "red"
    Write-Host "Common causes:"
    Write-Host "- The link is private, age-restricted, deleted, or region-locked."
    Write-Host "- The link is a playlist/channel instead of one video."
    Write-Host "- The internet connection is blocked or unstable."
    Write-Host "- YouTube changed something and yt-dlp needs another update later."
    Write-Host ""
    Write-Host "Double-check the link and try again."
    Write-Host ""
    return $false
}

function Get-DescriptionTimestampChapters {
    param([Parameter(Mandatory = $true)]$Metadata)

    $metadata = $Metadata
    if ([string]::IsNullOrWhiteSpace($metadata.description) -or -not $metadata.duration) {
        return @()
    }

    $duration = [double]$metadata.duration
    $chapters = @()

    foreach ($rawLine in ($metadata.description -split "`n")) {
        $line = $rawLine.Trim()
        $line = $line -replace '^[\s\-\*\u2022]+', ''
        $line = $line -replace '^\d+[\.)]\s+', ''
        $line = $line -replace '^\d+\s*[-–—]\s+', ''

        if ($line -match '^[\[\(]?(?<time>(?:(?<hours>\d{1,2}):)?(?<minutes>\d{1,2}):(?<seconds>\d{2}))[\]\)]?\s*(?:[-–—:|]\s*)?(?<title>.+?)\s*$') {
            $title = $Matches.title.Trim()
        } elseif ($line -match '^(?<title>.+?)\s*(?:[-–—:|]\s*)?[\(\[](?<time>(?:(?<hours>\d{1,2}):)?(?<minutes>\d{1,2}):(?<seconds>\d{2}))[\)\]]\s*$') {
            $title = $Matches.title.Trim()
        } else {
            continue
        }

        $hours = 0
        if ($Matches.hours) {
            $hours = [int]$Matches.hours
        }

        $startTime = ($hours * 3600) + ([int]$Matches.minutes * 60) + [int]$Matches.seconds
        $title = $title.Trim().Trim("-").Trim()
        if ([string]::IsNullOrWhiteSpace($title)) {
            continue
        }

        $chapters += [pscustomobject]@{
            StartTime = [double]$startTime
            Title = $title
        }
    }

    if ($chapters.Count -lt 2) {
        return @()
    }

    if ($chapters[0].StartTime -ne 0) {
        Write-Mascot "(._.)" "Timestamp fallback skipped because the first timestamp is not 0:00."
        return @()
    }

    for ($i = 0; $i -lt $chapters.Count; $i++) {
        if ($chapters[$i].StartTime -ge $duration) {
            return @()
        }

        if ($i -gt 0 -and $chapters[$i].StartTime -le $chapters[$i - 1].StartTime) {
            return @()
        }
    }

    $result = @()
    for ($i = 0; $i -lt $chapters.Count; $i++) {
        $endTime = if ($i + 1 -lt $chapters.Count) {
            $chapters[$i + 1].StartTime
        } else {
            $duration
        }

        if ($endTime -le $chapters[$i].StartTime) {
            return @()
        }

        $result += [pscustomobject]@{
            StartTime = $chapters[$i].StartTime
            EndTime = [double]$endTime
            Title = $chapters[$i].Title
        }
    }

    return $result
}

function Get-YouTubeChapterTracks {
    param([Parameter(Mandatory = $true)]$Metadata)

    if (-not $Metadata.chapters -or -not $Metadata.duration) {
        return @()
    }

    $duration = [double]$Metadata.duration
    $sourceChapters = @($Metadata.chapters)
    if ($sourceChapters.Count -lt 2) {
        return @()
    }

    $tracks = @()
    for ($i = 0; $i -lt $sourceChapters.Count; $i++) {
        $chapter = $sourceChapters[$i]
        if ($null -eq $chapter.start_time) {
            return @()
        }

        $startTime = [double]$chapter.start_time
        if ($startTime -lt 0 -or $startTime -ge $duration) {
            return @()
        }

        if ($i -gt 0 -and $startTime -le [double]$sourceChapters[$i - 1].start_time) {
            return @()
        }

        $endTime = if ($i + 1 -lt $sourceChapters.Count) {
            [double]$sourceChapters[$i + 1].start_time
        } elseif ($null -ne $chapter.end_time) {
            [double]$chapter.end_time
        } else {
            $duration
        }

        if ($endTime -gt $duration) {
            $endTime = $duration
        }

        if ($endTime -le $startTime) {
            return @()
        }

        $title = [string]$chapter.title
        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = "Track " + ($i + 1)
        }

        $tracks += [pscustomobject]@{
            StartTime = $startTime
            EndTime = [double]$endTime
            Title = $title.Trim()
        }
    }

    return $tracks
}

function Invoke-KnownTrackSplit {
    param(
        [Parameter(Mandatory = $true)][object[]]$Tracks,
        [Parameter(Mandatory = $true)][string]$OutDir,
        [Parameter(Mandatory = $true)][string]$FullOpusPath,
        [Parameter(Mandatory = $true)][string]$SourceName
    )

    $existingSongs = Get-ChildItem -LiteralPath $OutDir -Filter "*.opus" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+\. ' }

    if ($existingSongs) {
        return $false
    }

    $tracks = @($Tracks)
    if ($tracks.Count -lt 2) {
        return $false
    }

    Write-Host "Splitting $($tracks.Count) track(s) from $SourceName..."

    $createdFiles = @()
    $splitLastLineLength = 0
    Initialize-MascotStatusLine

    for ($i = 0; $i -lt $tracks.Count; $i++) {
        $trackNumber = $i + 1
        $trackTitle = $tracks[$i].Title
        $safeTitle = Get-SafeName $trackTitle
        $outputPath = Join-Path $OutDir ("$trackNumber. $safeTitle.opus")
        $startSeconds = $tracks[$i].StartTime
        $durationSeconds = [Math]::Max(0.001, $tracks[$i].EndTime - $tracks[$i].StartTime)

        if (Test-Path -LiteralPath $outputPath) {
            Remove-Item -LiteralPath $outputPath -Force
        }

        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            Write-MascotStatusLine -Message "Splitting track: $trackTitle" -DotField "" -ProgressText (Get-CountText -Current $trackNumber -Total $tracks.Count) -LastLineLength ([ref]$splitLastLineLength)
            $ffmpegOutput = @(& ffmpeg -hide_banner -y -ss $startSeconds -i $FullOpusPath -t $durationSeconds -map "0:a:0" -vn -dn -sn -map_metadata -1 -map_chapters -1 -c:a copy $outputPath 2>&1)
            $ffmpegExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $createdFile = Get-Item -LiteralPath $outputPath -ErrorAction SilentlyContinue
        if ($ffmpegExitCode -ne 0 -or -not $createdFile -or $createdFile.Length -le 0) {
            Clear-MascotStatusLine -LastLineLength $splitLastLineLength
            Write-Mascot "(>_<)" "Could not split track: $trackTitle" -Color "red"
            $ffmpegOutput | Select-Object -Last 6 | ForEach-Object { Write-Host $_ }
            foreach ($file in $createdFiles) {
                if (Test-Path -LiteralPath $file) {
                    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
                }
            }
            if (Test-Path -LiteralPath $outputPath) {
                Remove-Item -LiteralPath $outputPath -Force -ErrorAction SilentlyContinue
            }
            return $false
        }

        $createdFiles += $outputPath
    }

    Clear-MascotStatusLine -LastLineLength $splitLastLineLength
    Write-Step "Split $($createdFiles.Count) track(s)."
    return $true
}

function Get-SafeName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $safe = $Name -replace '[<>:"/\\|?*]', ''
    $safe = $safe -replace '\s+', ' '
    $safe = $safe.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return "Unknown Album"
    }
    return $safe
}

function Get-AlbumInfoFromTitle {
    param([Parameter(Mandatory = $true)][string]$Title)

    $fallback = $Title
    $fallback = $fallback -replace '\s*\[[^\]]+\]$', ''
    $fallback = $fallback -replace '\s+', ' '
    $fallback = $fallback.Trim()
    if ([string]::IsNullOrWhiteSpace($fallback)) {
        $fallback = $Title.Trim()
    }

    $clean = $Title
    $clean = $clean -replace '\s*\[[^\]]*?\]\s*$', ''
    $clean = $clean -replace '\s*-\s*(?:full album|full ep|full lp|album|ep)\s*(?:\d{4})?\s*$',''
    $clean = $clean -replace '\s*\([^)]*?(?:instrumental|official|audio|remaster|remastered)[^)]*?\)\s*', ' '
    $clean = $clean -replace '\s*-\s*(?:instrumental only|instrumental|official audio|audio|remaster|remastered)\s*(?:\d{4})?\s*$',''
    $clean = $clean -replace '\s+', ' '
    $clean = $clean.Trim()

    if ([string]::IsNullOrWhiteSpace($clean)) {
        $clean = $fallback
    }

    $artist = ""
    $album = $clean

    if ($clean -match '^\s*(?<artist>.+?)\s+[-–—]\s+(?<album>.+?)\s*$') {
        $artist = $Matches.artist.Trim()
        $album = $Matches.album.Trim()
    }

    if ([string]::IsNullOrWhiteSpace($album)) {
        $artist = ""
        $album = $fallback
    }

    [pscustomobject]@{
        Artist = $artist
        Album = $album
    }
}

$script:AnsiEnabled = Enable-AnsiOutput

Write-Host ""
Write-Host "YouTube Album Splitter"
Write-Host ""

Write-Host "Checking required tools..."
Ensure-Command -Command "yt-dlp" -WingetId "yt-dlp.yt-dlp" -Name "yt-dlp"
Ensure-Command -Command "ffmpeg" -WingetId "Gyan.FFmpeg" -Name "FFmpeg"
Ensure-PythonCommand
Ensure-Command -Command "deno" -WingetId "DenoLand.Deno" -Name "Deno"

$ScriptDir = Split-Path -Parent $env:BAT_PATH
$DownloadsRoot = Join-Path $ScriptDir "YouTube Album Splitter Songs"
New-Item -ItemType Directory -Force -Path $DownloadsRoot | Out-Null

while ($true) {
    Write-Host ""
    Write-Host "Paste a YouTube album link, then press Enter."
    Write-Host "Type $(Get-Cmd 'aac') to convert existing Opus files to AAC .m4a."
    Write-Host "Press Enter with no link to close."
    Write-Host ""

    $Url = (Read-Host "YouTube URL").Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($Url)) {
        break
    }

    if ($Url.Trim() -ieq "aac") {
        Convert-ExistingOpusToAac -Root $DownloadsRoot
        Write-Host ""
        Write-Host "Paste another link, type $(Get-Cmd 'aac') again, or press Enter with no link to close."
        continue
    }

    if ($Url -notmatch '^https?://((www|m|music)\.)?(youtube\.com|youtu\.be)/') {
        Write-Host ""
        Write-Mascot "(o_o?)" "That does not look like a YouTube link." -Color "yellow"
        Write-Host "Copy the full YouTube video link and try again."
        continue
    }

    if (Test-YouTubeVideoIdLooksIncomplete -Url $Url) {
        Write-Host ""
        Write-Mascot "(o_o?)" "That YouTube video ID looks incomplete." -Color "yellow"
        Write-Host "Copy the full YouTube video link and try again."
        continue
    }

    try {
        $OutDir = Join-Path $DownloadsRoot (Get-Date -Format "yyyy-MM-dd HH-mm-ss")
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

        Write-Host ""
        Write-Host "Reading track info..."

        $Metadata = Get-YtDlpMetadata -Url $Url
        if (-not $Metadata) {
            if ((Test-Path -LiteralPath $OutDir) -and -not (Get-ChildItem -LiteralPath $OutDir -Force -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $OutDir -Force
            }
            Write-Host ""
            Write-Host "Paste another link to try again, or press Enter with no link to close."
            continue
        }

        $TrackSource = ""
        $TrackList = @(Get-YouTubeChapterTracks -Metadata $Metadata)
        if ($TrackList.Count -ge 2) {
            $TrackSource = "YouTube chapter markers"
            Write-Step "Found $($TrackList.Count) YouTube chapter track(s)."
        } else {
            Write-Host "No usable YouTube chapter markers were found. Checking description timestamps..."
            $TrackList = @(Get-DescriptionTimestampChapters -Metadata $Metadata)
            if ($TrackList.Count -ge 2) {
                $TrackSource = "description timestamps"
                Write-Step "Found $($TrackList.Count) timestamped track(s) in the description."
            } else {
                Write-Mascot "(._.)" "No usable description timestamps were found."
            }
        }

        Write-Host ""

        $DownloadSucceeded = Invoke-YtDlpDownloadFullAudio -Url $Url -OutDir $OutDir -TrackCount $TrackList.Count
        if (-not $DownloadSucceeded) {
            if ((Test-Path -LiteralPath $OutDir) -and -not (Get-ChildItem -LiteralPath $OutDir -Force -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $OutDir -Force
            }
            Write-Host ""
            Write-Host "Paste another link to try again, or press Enter with no link to close."
            continue
        }

        Write-Step "Downloaded album audio."

        $FullOpus = Get-ChildItem -LiteralPath $OutDir -Filter "*.opus" |
        Where-Object { $_.Name -notmatch '^\d+\. ' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $AlbumArtist = ""
    $AlbumTitle = ""
    if ($FullOpus) {
        $VideoTitle = $FullOpus.BaseName -replace '\s*\[[^\]]+\]$', ''
        $AlbumInfo = Get-AlbumInfoFromTitle -Title $VideoTitle
        $AlbumArtist = $AlbumInfo.Artist
        $AlbumTitle = $AlbumInfo.Album

        $FolderName = if ($AlbumArtist) {
            Get-SafeName "$AlbumArtist - $AlbumTitle"
        } else {
            Get-SafeName $AlbumTitle
        }

        $AlbumDir = Join-Path $DownloadsRoot $FolderName
        if (Test-Path -LiteralPath $AlbumDir) {
            $AlbumDir = Join-Path $DownloadsRoot ("$FolderName " + (Get-Date -Format "yyyy-MM-dd HH-mm-ss"))
        }

        Move-Item -LiteralPath $OutDir -Destination $AlbumDir
        $OutDir = $AlbumDir
        $FullOpus = Get-ChildItem -LiteralPath $OutDir -Filter "*.opus" |
            Where-Object { $_.Name -notmatch '^\d+\. ' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    }

    $Cover = Join-Path $OutDir "cover.jpg"
    if ($FullOpus) {
        # yt-dlp embeds the source thumbnail first. We extract a square cover from
        # the full Opus and later re-embed it with Mutagen into each split file's
        # Opus METADATA_BLOCK_PICTURE tag, which music players read reliably.
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            & ffmpeg -hide_banner -y -i $FullOpus.FullName -map "0:v:0" -frames:v 1 -vf "crop=min(iw\,ih):min(iw\,ih)" -update 1 $Cover 2>$null
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }

    if (-not (Test-Path -LiteralPath $Cover)) {
        Write-Mascot "(u_u)" "Warning: could not extract album art. Tags will still be fixed, but songs may not show cover art." -Color "yellow"
    }

    if ($TrackList.Count -ge 2 -and $FullOpus -and (Test-Path -LiteralPath $FullOpus.FullName)) {
        Write-Host ""
        Invoke-KnownTrackSplit -Tracks $TrackList -OutDir $OutDir -FullOpusPath $FullOpus.FullName -SourceName $TrackSource | Out-Null
    }

    Write-Host ""
    Write-Host "Preparing tag fixer..."
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        Invoke-Python -Arguments @("-c", "import mutagen") 2>$null
        $mutagenCheckExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($mutagenCheckExitCode -ne 0) {
        Invoke-Python -Arguments @("-m", "pip", "install", "--user", "mutagen")
    }

    $TagScript = Join-Path $env:TEMP ("fix_opus_chapter_tags." + [guid]::NewGuid().ToString("N") + ".py")
    @'
from __future__ import annotations

import base64
import re
import sys
from pathlib import Path

from mutagen.flac import Picture
from mutagen.oggopus import OggOpus

chapter_dir = Path(sys.argv[1])
cover_path = Path(sys.argv[2])
album_title = sys.argv[3] if len(sys.argv) > 3 else ""
album_artist = sys.argv[4] if len(sys.argv) > 4 else ""
chapter_re = re.compile(r"^(?P<number>\d+)\.\s*(?P<title>.+)\.opus$", re.IGNORECASE)

cover_tag = None
if cover_path.is_file():
    pic = Picture()
    pic.type = 3
    pic.mime = "image/jpeg"
    pic.desc = "Cover (front)"
    pic.data = cover_path.read_bytes()
    cover_tag = base64.b64encode(pic.write()).decode("ascii")

for path in sorted(chapter_dir.glob("*.opus")):
    match = chapter_re.match(path.name)
    if not match:
        continue

    number = str(int(match.group("number")))
    song = match.group("title").strip()
    filename_title = f"{number}. {song}"

    audio = OggOpus(path)
    audio["title"] = [song]
    audio["tracknumber"] = [number]
    if album_title:
        audio["album"] = [album_title]
    if album_artist:
        audio["albumartist"] = [album_artist]
        audio["artist"] = [album_artist]
    audio.pop("track", None)
    audio.pop("genre", None)
    if cover_tag:
        audio["metadata_block_picture"] = [cover_tag]
    audio.save()

    clean_name = f"{filename_title}.opus"
    clean_path = path.with_name(clean_name)
    if clean_path != path:
        if clean_path.exists():
            clean_path.unlink()
        path.rename(clean_path)

    print(f"Fixed: {clean_name}")
'@ | Set-Content -LiteralPath $TagScript -Encoding UTF8

    Write-Host ""
    Write-Host "Fixing album art and tags..."
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $tagOutput = Invoke-Python -Arguments @($TagScript, $OutDir, $Cover, $AlbumTitle, $AlbumArtist) 2>&1
        $tagExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($tagExitCode -eq 0) {
        $tagOutput | ForEach-Object { Write-Host $_ }
    } else {
        Write-Mascot "(;_;)" "Tag fixer failed. Keeping the full-length Opus file if it still exists." -Color "red"
        $tagOutput | Select-Object -Last 8 | ForEach-Object { Write-Host $_ }
    }

    if (Test-Path -LiteralPath $TagScript) {
        Remove-Item -LiteralPath $TagScript -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $Cover) {
        Remove-Item -LiteralPath $Cover -Force
    }

    $SongCount = (Get-ChildItem -LiteralPath $OutDir -Filter "*.opus" |
        Where-Object { $_.Name -match '^\d+\. ' } |
        Measure-Object).Count

    if ($FullOpus -and (Test-Path -LiteralPath $FullOpus.FullName)) {
        if ($SongCount -gt 0 -and $tagExitCode -eq 0) {
            Remove-Item -LiteralPath $FullOpus.FullName -Force
        } elseif ($SongCount -gt 0) {
            Write-Mascot "(;_;)" "Separate song files exist, but tag cleanup did not finish successfully. Keeping the full-length Opus file too." -Color "red"
        } else {
            Write-Mascot "(._.)" "No separate song files were created. Keeping the full-length Opus file."
        }
    }

    if ($SongCount -gt 0 -and $tagExitCode -eq 0) {
        Write-Step "Tagged $SongCount song(s) and embedded album art."
    }

    Write-Host ""
    Show-TableFlip
    Write-Host "Files are in: $OutDir"
    if ($SongCount -gt 0) {
        Write-Host "Each song is named like '1. Song Name.opus', has album art, has tracknumber set to the number, and has no genre tag."
    } else {
        Write-Mascot "(._.)" "This video did not create separate songs, so the full audio file was kept."
    }
    Write-Host ""
    } catch {
        Write-Host ""
        Write-Mascot "(x_x)" "Something went wrong while processing that link." -Color "red"
        Write-Host $_.Exception.Message
        Write-Host ""
        Write-Host "Paste another link to try again, or press Enter with no link to close."
        Write-Host ""
    }
}
