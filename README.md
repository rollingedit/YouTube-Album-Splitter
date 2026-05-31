# YouTube Album Splitter

One file. Double-click. Paste a YouTube link. Get separate song files.

YouTube Album Splitter is a beginner-friendly, no-setup, self-contained Windows tool for turning a chaptered YouTube album upload you own or have permission to use into separate song files automatically.

The tedious part before this was not just downloading audio. It was everything after that: splitting one long upload into tracks, rename track files, adding album art, setting track numbers, fixing artist/album metadata, avoiding playlist surprises, and making the output folder look like something you can actually drop into a music app.

This tool does all of that automatically. The automation behind it is custom-built, then packaged into one self-contained `.bat` file so it stays easy to use. No command-line setup, no manual installs, no copying commands, and no separate helper files to keep track of. Any helper scripts it needs are created temporarily by the tool itself.

It handles the download, splitting, album art, smart folder naming, metadata cleanup, temporary-file cleanup, and repeat prompts automatically.

It saves files like:

```text
1. Song Name.opus
2. Song Name.opus
3. Song Name.opus
```

It is designed for album-style YouTube uploads that show chapter markers on the YouTube progress bar. Many videos create those chapters from timestamps in the description, but timestamps alone are not always enough. If YouTube does not show chapter markers on the progress bar, the tool may keep the full audio file instead of splitting it.

## How To Use

1. Go to the [latest release](../../releases/latest).
2. Download `YouTube Album Splitter.bat`.
3. Double-click it.
4. Paste the YouTube video link when it asks.
5. Press Enter.
6. Paste another link to process another upload, or press Enter with no link to close.

Finished songs appear in a folder named:

```text
YouTube Album Splitter Songs
```

Each pasted link gets its own subfolder inside that folder, so uploads do not mix together.

## Features

- One-file Windows tool. No separate installer or setup script.
- Prompts for a YouTube link instead of making users edit commands.
- Lets you process multiple links in one session.
- Rejects obvious non-YouTube links immediately instead of wasting time updating tools.
- Accepts normal YouTube, mobile YouTube, YouTube Music, and `youtu.be` links.
- Treats each pasted link as one selected video, even if the URL includes a playlist.
- Downloads the best available Opus audio.
- Splits the video into separate song files using YouTube chapter markers.
- Creates numbered filenames like `1. Song Name.opus`.
- Creates an album folder from the YouTube title when it can, like `Artist - Album`.
- Removes common extra title text like `(Instrumental)`, `(Instrumental Only)`, `Full Album`, `Full EP`, years, and bracket tags from the folder/album name when possible.
- Falls back to a generic folder/name when the YouTube title cannot be parsed.
- Embeds album art into every split song file.
- Crops album art to a centered 1:1 square so there are no black bars.
- Sets each title tag to the proper song name, like `Song Name`.
- Sets album and artist metadata when the YouTube title follows a clear `Artist - Album` style.
- Sets each track number tag to the correct number, like `1`.
- Removes genre metadata so files are not mislabeled.
- Deletes temporary files after the final tracks are finished.
- Keeps the full audio file only if the video has no chapters, so the output folder is never empty.

## Automatic Setup

The tool checks for the helper programs it needs and installs missing ones automatically with `winget`:

- yt-dlp, for downloading from YouTube.
- FFmpeg, for audio conversion, thumbnail handling, and cover extraction.
- Deno, so yt-dlp can use its external JavaScript challenge-solving path when YouTube requires it.
- Python, for final Opus metadata and album-art tagging.

It also installs the Python metadata library `mutagen` only if it is missing. It does not reinstall it every run.

## How It Works

The released version is one `.bat` file on purpose. A contemporary version could be split into separate files, but that would make normal users download and keep multiple scripts together. This tool hides that complexity inside one double-click file.

Conceptually, the tool is still organized in layers:

```text
BAT launcher
-> embedded PowerShell controller
-> temporary Python tag fixer
-> yt-dlp / FFmpeg / mutagen / Deno backend
```

What each part does:

- **BAT**: Windows double-click entrypoint. Starts everything without requiring the user to open a terminal.
- **PowerShell**: Main controller. Handles prompts, dependency checks, automatic installs, PATH refresh, URL validation, yt-dlp calls, folder cleanup, retry/update behavior, and the loop for another link.
- **yt-dlp**: Downloads the YouTube audio, reads YouTube chapter markers, and splits the upload into separate song files.
- **FFmpeg**: Media backend for audio extraction, thumbnail conversion, square cover cropping, and stream processing.
- **Python**: Runs only after Python exists. It is used for final metadata cleanup.
- **mutagen**: Python metadata library used to edit Opus/Ogg tags and embed cover art correctly.
- **Deno**: JavaScript runtime used by yt-dlp for modern YouTube extraction support.
- **winget**: Windows package installer used to install missing helper tools automatically.

So the internal design is modular, but the released user experience stays simple:

```text
Download one file
Double-click
Paste link
Get song files
```

## Reliability Features

YouTube changes often, so the script includes a recovery path.

If the first download attempt fails, it automatically updates the main download tools and retries once:

- yt-dlp
- FFmpeg
- Deno

If the active `yt-dlp` appears to be a Python-installed version, it also repairs that setup with the correct optional extras.

This update step is not guaranteed to fix every failure. It is there because outdated download tools are one of the most common reasons YouTube downloads suddenly stop working. If the pasted text is obviously not a YouTube link, the tool skips the update step and asks for a real link. If the problem is a private video, age restriction, region lock, or internet issue, updating will not fix that, but the tool will still give a readable message instead of silently failing.

If the retry still fails, the tool shows a plain-language message with common causes, such as:

- Private, deleted, age-restricted, or region-locked video.
- Playlist or channel link without a specific video selected.
- Blocked or unstable internet connection.
- A new YouTube change that needs a future yt-dlp update.

## Output Details

Each successful song file is cleaned up like this:

```text
Main folder:   YouTube Album Splitter Songs
Album folder:  Artist - Album
Filename:      1. Song Name.opus
Title tag:     Song Name
Artist tag:    Artist
Album tag:     Album
Track number:  1
Album art:     Embedded
Genre:         Removed
```

The final output folder is kept simple for nontechnical users:

```text
YouTube Album Splitter Songs
└─ Artist - Album
   ├─ 1. Song Name.opus
   ├─ 2. Song Name.opus
   └─ 3. Song Name.opus
```

After a successful split, each album folder contains only the finished song files.

Artist and album naming is based on the YouTube title. It works best when titles look like:

```text
Artist - Album
```

It also tolerates common extra upload text like:

```text
Artist - Album (Instrumental) - Full Album 2024
Artist - Album (Instrumental Only) - Full EP 2024
```

For example, `Example Artist - Example Album (Instrumental) - Full Album 2024` becomes:

```text
Artist: Example Artist
Album:  Example Album
Folder: Example Artist - Example Album
```

If the title cannot be parsed, the tool still downloads and tags the songs, but the album folder/name may be more generic. If title cleanup would produce an empty name, it falls back to the original video title.

If the folder name already exists, the tool adds a date/time suffix so a second run does not overwrite the first one.

Album art is forced to a square thumbnail. If the original thumbnail is already square, the crop does not change it. If it is wide or tall, the tool crops the center so the final cover art is 1:1.

## Why It Uses Opus

YouTube's best audio is often already Opus. When the source audio is already Opus, keeping the output as Opus avoids unnecessary re-encoding and keeps file sizes small.

## Requirements

Windows is required.

Most Windows 10 and Windows 11 computers already include `winget`. If yours does not, install **App Installer** from the Microsoft Store and run the script again.

## Important

This works best with YouTube videos that show chapter markers on the progress bar. If a video has no chapters, the tool keeps the full audio file instead of leaving an empty folder.

Use this only for content you own, created, or have permission to download and process.

Windows may show a SmartScreen or antivirus warning because this is an unsigned helper script that installs/uses download tools. That warning is a normal Windows security limitation for small unsigned projects, not proof that something is wrong. If you trust the file, click **More info** then **Run anyway**.

## License

This project is licensed under the GNU General Public License v3.0.

That means people can use, share, and modify it, but if they distribute modified versions, they must keep the same license and share the source code too.
