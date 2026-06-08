# Security Policy

## Reporting Security Issues

If you believe you found a security issue in YouTube Album Splitter, please do not post exploit details in a public issue.

Open a private security advisory on GitHub if available, or contact the maintainer privately through the repository owner's GitHub profile.

Please include:

* the affected version, release, tag, or commit;
* the file or behavior involved;
* steps to reproduce the issue;
* the expected and actual result;
* any relevant terminal output, screenshots, or proof of concept details.

## Supported Versions

Security fixes target the latest released `YouTube Album Splitter.bat` and current `main` branch.

Older release assets may not receive separate backports. Users should update to the newest release unless they have a specific reason to audit and run an older version.

## Security, Privacy, And System Changes

This project is open source, and the release download is the same plain-text `.bat` script from this repo. The release exists to make downloading easier for beginners.

Because the script can install helper tools automatically, this file lists what it may change.

## Unsigned Script And Unknown Publisher Warnings

Windows may show an **Open File - Security Warning** or **Unknown Publisher** prompt because the release is an internet-downloaded, unsigned `.bat` file.

That warning means Windows cannot verify a digital publisher signature for the downloaded file. It is not the same thing as an antivirus malware detection, a Defender quarantine, or the full SmartScreen message that says Windows protected your PC.

A stronger SmartScreen block or antivirus quarantine is separate. Only run the file if you trust this repo and the downloaded BAT.

## Packages It May Install

Installed through `winget` when it is available and a tool is missing:

```text
yt-dlp.yt-dlp
Gyan.FFmpeg
Python.Python.3.12
DenoLand.Deno
```

Installed through `pip`:

```text
mutagen
yt-dlp[default]
curl-cffi
ffmpeg-downloader
```

`mutagen` is used for metadata handling.

`yt-dlp[default]` and `curl-cffi` are used on the retry/repair path when the active `yt-dlp` appears to be a Python-installed version.

`ffmpeg-downloader` is used only when `winget` is unavailable and the script needs a Python-based FFmpeg setup path.

Deno is installed only on demand, either through `winget` or its official installer, the first time a download fails and the retry needs YouTube's JavaScript challenge solver.

## Network Access

The script may contact:

* YouTube / YouTube Music, through `yt-dlp`, to read video data and download audio.
* GitHub, when `yt-dlp` downloads its external JavaScript challenge-solving component.
* Microsoft `winget` package sources, when installing or upgrading dependencies.
* Python package indexes, when installing `mutagen`, repairing a Python-installed `yt-dlp`, or setting up yt-dlp and FFmpeg without `winget`.
* `deno.land`, only when Deno is set up on demand without `winget`.

The script does not upload your files anywhere. It downloads audio from the link you provide and writes the finished files locally.

## Where Files Are Written

Finished songs are written next to the `.bat` file:

```text
<folder containing the .bat>\YouTube Album Splitter Songs
```

Each album/upload gets its own subfolder:

```text
<folder containing the .bat>\YouTube Album Splitter Songs\<album folder>
```

Temporary tag helpers:

```text
%TEMP%\fix_opus_chapter_tags.<random>.py
%TEMP%\fix_m4a_tags.<random>.py
```

During processing, a temporary `cover.jpg` may be created inside the album folder. It is removed after album art is embedded.

## PATH Behavior

The script refreshes `PATH` only inside its own running PowerShell window so newly installed tools can be found immediately. It may also add the standard Windows app execution alias folder to that in-window `PATH` so it can reliably find `winget`.

It does not directly edit your permanent system or user `PATH`. Tools installed through `winget` may add themselves to PATH through their normal installers. The Python FFmpeg fallback uses `ffmpeg-downloader --add-path`, which may ask that helper to add FFmpeg to user PATH.

## How To Inspect Before Running

The `.bat` file is plain text.

To inspect it before running:

1. Right-click `YouTube Album Splitter.bat`.
2. Click **Show more options** if needed.
3. Click **Edit**, or open it with Notepad / VS Code.

The first few lines launch PowerShell. The main script is embedded later in the same file after the `POWERSHELL_PAYLOAD` marker.

## How To Uninstall Helper Tools

Only uninstall these if you installed them for this tool and do not use them for anything else.

```powershell
winget uninstall --id yt-dlp.yt-dlp
winget uninstall --id Gyan.FFmpeg
winget uninstall --id Python.Python.3.12
winget uninstall --id DenoLand.Deno
```

Python packages:

Use whichever Python command works on your system. For example:

```powershell
python -m pip uninstall mutagen
python -m pip uninstall yt-dlp curl-cffi
python -m pip uninstall ffmpeg-downloader
```

Or, if your system uses the Python launcher:

```powershell
py -3 -m pip uninstall mutagen
py -3 -m pip uninstall yt-dlp curl-cffi
py -3 -m pip uninstall ffmpeg-downloader
```

If Deno was set up without `winget`, it lives in `%USERPROFILE%\.deno`; remove that folder to uninstall it.

If FFmpeg was set up with `ffmpeg-downloader`, run this before uninstalling the package to delete its downloaded binaries:

```powershell
ffdl remove --all
```
