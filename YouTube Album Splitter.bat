@echo off
set "BAT_PATH=%~f0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=$env:BAT_PATH; $c=Get-Content -LiteralPath $p -Raw; $m='# POWERSHELL_' + 'PAYLOAD'; $parts=$c -split [regex]::Escape($m),2; Invoke-Expression $parts[1]"
exit /b %ERRORLEVEL%

# POWERSHELL_PAYLOAD
$ErrorActionPreference = "Stop"

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
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

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "Windows App Installer / winget is missing. Install 'App Installer' from the Microsoft Store, then run this again."
    }

    Write-Host "$Name not found. Installing it now..."
    winget install --id $WingetId -e --accept-package-agreements --accept-source-agreements
    Refresh-Path

    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Name was installed, but Windows has not exposed it in PATH yet. Close this window and run this file again."
    }

    Write-Host "$Name installed."
}

function Invoke-YtDlpDownload {
    $ytDlpArgs = @(
        "--force-overwrites",
        "--remote-components", "ejs:github",
        "-P", $OutDir,
        "-f", "ba[acodec^=opus]/ba",
        "-x",
        "--audio-format", "opus",
        "--split-chapters",
        "--embed-metadata",
        "--embed-thumbnail",
        "--convert-thumbnails", "jpg",
        "--ppa", "ThumbnailsConvertor+ffmpeg_o:-c:v mjpeg -vf crop=ih:ih",
        "--ppa", "SplitChapters+ffmpeg_o:-vn",
        "-o", "chapter:%(section_number)d. %(section_title)s.%(ext)s",
        $Url
    )

    & yt-dlp @ytDlpArgs
    if ($LASTEXITCODE -eq 0) {
        return
    }

    Write-Host ""
    Write-Host "yt-dlp failed. Updating download tools, then trying once more..."
    winget upgrade --id yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
    winget upgrade --id DenoLand.Deno -e --accept-package-agreements --accept-source-agreements
    winget upgrade --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements

    $ytDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if ($ytDlpCommand -and $ytDlpCommand.Source -match '\\Python\d*\\Scripts\\|\\Python\\PythonCore\\|\\Scripts\\yt-dlp') {
        Write-Host "Detected Python-installed yt-dlp. Updating Python yt-dlp with default extras..."
        py -3 -m pip install --user --upgrade "yt-dlp[default]" curl-cffi
    }

    Refresh-Path

    & yt-dlp @ytDlpArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Still couldn't download after updating the tools."
        Write-Host "Common causes:"
        Write-Host "- The link is private, age-restricted, deleted, or region-locked."
        Write-Host "- The link is a playlist/channel instead of one video."
        Write-Host "- The internet connection is blocked or unstable."
        Write-Host "- YouTube changed something and yt-dlp needs another update later."
        Write-Host ""
        Write-Host "Double-check the link and try again."
        Write-Host ""
        Read-Host "Press Enter to close"
        exit 1
    }
}

Write-Host ""
Write-Host "YouTube Album Splitter"
Write-Host ""

Write-Host "Checking required tools..."
Ensure-Command -Command "yt-dlp" -WingetId "yt-dlp.yt-dlp" -Name "yt-dlp"
Ensure-Command -Command "ffmpeg" -WingetId "Gyan.FFmpeg" -Name "FFmpeg"
Ensure-Command -Command "py" -WingetId "Python.Python.3.12" -Name "Python"
Ensure-Command -Command "deno" -WingetId "DenoLand.Deno" -Name "Deno"

$ScriptDir = Split-Path -Parent $env:BAT_PATH
$DownloadsRoot = Join-Path $ScriptDir "YouTube Album Splitter Songs"
New-Item -ItemType Directory -Force -Path $DownloadsRoot | Out-Null

while ($true) {
    Write-Host ""
    Write-Host "Paste a YouTube album link, then press Enter."
    Write-Host "Press Enter with no link to close."
    Write-Host ""

    $Url = Read-Host "YouTube URL"
    if ([string]::IsNullOrWhiteSpace($Url)) {
        break
    }

    $OutDir = Join-Path $DownloadsRoot (Get-Date -Format "yyyy-MM-dd HH-mm-ss")
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

    Write-Host ""
    Write-Host "Downloading and splitting songs..."

    Invoke-YtDlpDownload

    $FullOpus = Get-ChildItem -LiteralPath $OutDir -Filter "*.opus" |
        Where-Object { $_.Name -notmatch '^\d+\. ' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    $Cover = Join-Path $OutDir "cover.jpg"
    if ($FullOpus) {
        cmd /c "ffmpeg -y -i ""$($FullOpus.FullName)"" -map 0:v:0 -frames:v 1 -vf ""crop='min(iw,ih)':'min(iw,ih)'"" -update 1 ""$Cover"" 2>nul"
    }

    if (-not (Test-Path -LiteralPath $Cover)) {
        Write-Host "Warning: could not extract album art. Tags will still be fixed, but songs may not show cover art."
    }

    Write-Host ""
    Write-Host "Preparing tag fixer..."
    py -3 -c "import mutagen" 2>$null
    if ($LASTEXITCODE -ne 0) {
        py -3 -m pip install --user mutagen
    }

    $TagScript = Join-Path $env:TEMP "fix_opus_chapter_tags.py"
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
    title = f"{number}. {song}"

    audio = OggOpus(path)
    audio["title"] = [title]
    audio["tracknumber"] = [number]
    audio.pop("track", None)
    audio.pop("genre", None)
    if cover_tag:
        audio["metadata_block_picture"] = [cover_tag]
    audio.save()

    clean_name = f"{title}.opus"
    clean_path = path.with_name(clean_name)
    if clean_path != path:
        if clean_path.exists():
            clean_path.unlink()
        path.rename(clean_path)

    print(f"Fixed: {clean_name}")
'@ | Set-Content -LiteralPath $TagScript -Encoding UTF8

    Write-Host ""
    Write-Host "Fixing album art and tags..."
    py -3 "$TagScript" "$OutDir" "$Cover"

    if (Test-Path -LiteralPath $Cover) {
        Remove-Item -LiteralPath $Cover -Force
    }

    $SongCount = (Get-ChildItem -LiteralPath $OutDir -Filter "*.opus" |
        Where-Object { $_.Name -match '^\d+\. ' } |
        Measure-Object).Count

    if ($FullOpus -and (Test-Path -LiteralPath $FullOpus.FullName)) {
        if ($SongCount -gt 0) {
            Remove-Item -LiteralPath $FullOpus.FullName -Force
        } else {
            Write-Host "No separate song files were created. Keeping the full-length Opus file."
        }
    }

    Write-Host ""
    Write-Host "Done."
    Write-Host "Files are in: $OutDir"
    if ($SongCount -gt 0) {
        Write-Host "Each song is named like '1. Song Name.opus', has album art, has tracknumber set to the number, and has no genre tag."
    } else {
        Write-Host "This video did not create separate songs, so the full audio file was kept."
    }
    Write-Host ""
}
