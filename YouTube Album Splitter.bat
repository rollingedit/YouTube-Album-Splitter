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
        Write-Host "No Opus files found in: $Root"
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
    $confirmAac = Read-Host "Continue? Type yes to continue"
    if ($confirmAac.Trim() -ine "yes") {
        Write-Host "AAC conversion cancelled."
        return
    }

    Write-Host ""
    Write-Host "Preparing M4A tag fixer..."
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        py -3 -c "import mutagen" 2>$null
        $mutagenCheckExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($mutagenCheckExitCode -ne 0) {
        py -3 -m pip install --user mutagen
    }

    $M4aTagScript = Join-Path $env:TEMP "fix_m4a_tags.py"
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

    foreach ($opus in $opusFiles) {
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

        Write-Host "Converting: $($opus.Name)"
        $previousErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $ffmpegOutput = & ffmpeg -hide_banner -y -i $opus.FullName -map "0:a:0" -vn -dn -sn -map_chapters -1 -map_metadata -1 -c:a aac -b:a 192k $tempAacPath 2>&1
            $ffmpegExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }

        $tempAacFile = Get-Item -LiteralPath $tempAacPath -ErrorAction SilentlyContinue
        if ($ffmpegExitCode -eq 0 -and $tempAacFile -and $tempAacFile.Length -gt 0) {
            $previousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $tagOutput = & py -3 "$M4aTagScript" "$($opus.FullName)" "$tempAacPath" 2>&1
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
                Write-Host "Could not tag AAC file: $($opus.Name)"
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
                Write-Host "Could not finalize AAC file: $($opus.Name)"
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
        Write-Host "Could not convert: $($opus.Name)"
        Write-Host "Kept original Opus file."
        $ffmpegOutput | Select-Object -Last 6 | ForEach-Object { Write-Host $_ }
    }

    Write-Host ""
    Write-Host "AAC conversion finished. Converted: $converted. Replaced existing AAC: $replaced. Failed: $failed."
    Write-Host "Removed Opus originals after successful AAC conversion: $deleted."
    Remove-StaleAacWorkFiles -Root $Root
}

function Invoke-YtDlpDownload {
    $ytDlpArgs = @(
        "--force-overwrites",
        "--no-playlist",
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

    $firstOutput = & yt-dlp @ytDlpArgs 2>&1
    $firstOutput | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -eq 0) {
        $script:DownloadSucceeded = $true
        return
    }

    $firstText = $firstOutput -join "`n"
    if ($firstText -match 'is not a valid URL|Unsupported URL|Invalid URL') {
        Write-Host ""
        Write-Host "That does not look like a valid YouTube video link."
        Write-Host "Copy the full link from YouTube and try again."
        $script:DownloadSucceeded = $false
        return
    }

    if ($firstText -match 'Sign in to confirm|not a bot|LOGIN_REQUIRED|confirm you.?re not a bot|cookies from browser') {
        Write-Host ""
        Write-Host "YouTube is asking this machine to sign in or confirm it is not a bot."
        Write-Host "Updating the tools will not fix that."
        Write-Host "Try again later, or try from a different network/browser session."
        $script:DownloadSucceeded = $false
        return
    }

    Write-Host ""
    if ($firstText -match 'no such option') {
        Write-Host "yt-dlp looks too old for one of the required options. Updating tools, then trying once more..."
    } else {
        Write-Host "yt-dlp failed. Updating download tools, then trying once more..."
    }
    winget upgrade --id yt-dlp.yt-dlp -e --accept-package-agreements --accept-source-agreements
    winget upgrade --id DenoLand.Deno -e --accept-package-agreements --accept-source-agreements
    winget upgrade --id Gyan.FFmpeg -e --accept-package-agreements --accept-source-agreements

    $ytDlpCommand = Get-Command yt-dlp -ErrorAction SilentlyContinue
    if ($ytDlpCommand -and $ytDlpCommand.Source -match '\\Python\d*\\Scripts\\|\\Python\\PythonCore\\|\\Scripts\\yt-dlp') {
        Write-Host "Detected Python-installed yt-dlp. Updating Python yt-dlp with default extras..."
        py -3 -m pip install --user --upgrade "yt-dlp[default]" curl-cffi
    }

    Refresh-Path

    $retryOutput = & yt-dlp @ytDlpArgs 2>&1
    $retryOutput | ForEach-Object { Write-Host $_ }
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
        $script:DownloadSucceeded = $false
        return
    }

    $script:DownloadSucceeded = $true
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

    if ($clean -match '^\s*(?<artist>.+?)\s+-\s+(?<album>.+?)\s*$') {
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
    Write-Host "Type aac to convert existing Opus files to AAC .m4a."
    Write-Host "Press Enter with no link to close."
    Write-Host ""

    $Url = Read-Host "YouTube URL"
    if ([string]::IsNullOrWhiteSpace($Url)) {
        break
    }

    if ($Url.Trim() -ieq "aac") {
        Convert-ExistingOpusToAac -Root $DownloadsRoot
        Write-Host ""
        Write-Host "Paste another link, type aac again, or press Enter with no link to close."
        continue
    }

    if ($Url -notmatch '^https?://((www|m|music)\.)?(youtube\.com|youtu\.be)/') {
        Write-Host ""
        Write-Host "That does not look like a YouTube link."
        Write-Host "Copy the full YouTube video link and try again."
        continue
    }

    try {
        $OutDir = Join-Path $DownloadsRoot (Get-Date -Format "yyyy-MM-dd HH-mm-ss")
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

        Write-Host ""
        Write-Host "Downloading and splitting songs..."

        $script:DownloadSucceeded = $false
        Invoke-YtDlpDownload
        if (-not $script:DownloadSucceeded) {
            if ((Test-Path -LiteralPath $OutDir) -and -not (Get-ChildItem -LiteralPath $OutDir -Force -ErrorAction SilentlyContinue)) {
                Remove-Item -LiteralPath $OutDir -Force
            }
            Write-Host ""
            Write-Host "Paste another link to try again, or press Enter with no link to close."
            continue
        }

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
        cmd /c "ffmpeg -y -i ""$($FullOpus.FullName)"" -map 0:v:0 -frames:v 1 -vf ""crop='min(iw,ih)':'min(iw,ih)'"" -update 1 ""$Cover"" 2>nul"
    }

    if (-not (Test-Path -LiteralPath $Cover)) {
        Write-Host "Warning: could not extract album art. Tags will still be fixed, but songs may not show cover art."
    }

    Write-Host ""
    Write-Host "Preparing tag fixer..."
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        py -3 -c "import mutagen" 2>$null
        $mutagenCheckExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    if ($mutagenCheckExitCode -ne 0) {
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
    py -3 "$TagScript" "$OutDir" "$Cover" "$AlbumTitle" "$AlbumArtist"

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
    } catch {
        Write-Host ""
        Write-Host "Something went wrong while processing that link."
        Write-Host $_.Exception.Message
        Write-Host ""
        Write-Host "Paste another link to try again, or press Enter with no link to close."
        Write-Host ""
    }
}
