# YouTube Album Splitter

Split a YouTube album video into separate song files automatically.

Paste a YouTube link, and this tool downloads the audio, splits it by the video's chapter timestamps, adds album art, fixes track numbers, and saves clean individual Opus files like:

```text
1. Song Name.opus
2. Song Name.opus
3. Song Name.opus
```

It is designed for album-style YouTube uploads that show chapter markers on the YouTube progress bar.

Many videos create those chapters from timestamps in the description, but timestamps alone are not always enough. If YouTube does not show chapter markers on the progress bar, the tool may keep the full audio file instead of splitting it.

No command-line knowledge is needed. After you double-click the file and paste the link, the tool handles the rest.

## How To Use

1. Click the green **Code** button near the top of this GitHub page.
2. Click **Download ZIP**.
3. Open the downloaded ZIP/folder.
4. Double-click `YouTube Album Splitter.bat`.
5. Paste the YouTube video link when it asks.
6. Press Enter.

Finished songs appear in a folder named:

```text
downloaded chapters
```

## Features

- One-file Windows tool. No separate installer or setup script.
- Prompts for a YouTube link instead of making users edit commands.
- Downloads the best available Opus audio.
- Splits the video into separate song files using YouTube chapter markers.
- Creates clean numbered filenames like `1. Song Name.opus`.
- Embeds album art into every split song file.
- Crops album art to a centered 1:1 square so music apps display it cleanly.
- Sets each title tag to match the filename, like `1. Song Name`.
- Sets each track number tag to the correct number, like `1`.
- Removes genre metadata so files are not mislabeled.
- Deletes temporary files after the final tracks are finished.
- Keeps the full audio file only if the video has no chapters, so the output folder is never empty.

## Automatic Setup

The tool checks for the helper programs it needs and installs missing ones automatically with `winget`:

- yt-dlp, for downloading from YouTube.
- FFmpeg, for audio conversion, thumbnail handling, and cover extraction.
- Deno, for modern YouTube JavaScript challenge solving used by yt-dlp.
- Python, for final Opus metadata and album-art tagging.

It also installs the Python metadata library `mutagen` only if it is missing. It does not reinstall it every run.

## Reliability Features

YouTube changes often, so the script includes a recovery path.

If the first download attempt fails, it automatically updates the main download tools and retries once:

- yt-dlp
- FFmpeg
- Deno

If the active `yt-dlp` appears to be a Python-installed version, it also repairs that setup with the correct optional extras.

This update step is not guaranteed to fix every failure. It is there because outdated download tools are one of the most common reasons YouTube downloads suddenly stop working. If the problem is an invalid link, private video, age restriction, region lock, or internet issue, updating will not fix that, but the tool will still give a readable message instead of silently failing.

If the retry still fails, the tool shows a plain-language message with common causes, such as:

- Private, deleted, age-restricted, or region-locked video.
- Playlist or channel link instead of a single video.
- Blocked or unstable internet connection.
- A new YouTube change that needs a future yt-dlp update.

## Output Details

Each successful chapter track is cleaned up like this:

```text
Filename:      1. Song Name.opus
Title tag:     1. Song Name
Track number:  1
Album art:     Embedded
Genre:         Removed
```

The final output folder is kept simple for nontechnical users. After a successful split, it contains only the finished song files.

Album art is forced to a square thumbnail. If the original thumbnail is already square, the crop does not change it. If it is wide or tall, the tool crops the center so the final cover art is 1:1.

## Why It Uses Opus

YouTube's best audio is often already Opus. When the source audio is already Opus, keeping the output as Opus avoids unnecessary re-encoding and keeps file sizes small.

## Requirements

Windows is required.

Most Windows 10 and Windows 11 computers already include `winget`. If yours does not, install **App Installer** from the Microsoft Store and run the script again.

## Important

This works best with YouTube videos that show chapter markers on the progress bar. If a video has no chapters, the tool keeps the full audio file instead of leaving an empty folder.

Use this only for content you own or have permission to download.

Windows may show a SmartScreen or antivirus warning because this is an unsigned helper script that installs/uses download tools. That warning is a normal Windows security limitation for small unsigned projects, not proof that something is wrong. If you trust the file, click **More info** then **Run anyway**.

## License

This project is licensed under the GNU General Public License v3.0.

That means people can use, share, and modify it, but if they distribute modified versions, they must keep the same license and share the source code too.
