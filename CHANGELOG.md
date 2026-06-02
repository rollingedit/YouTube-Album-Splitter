# Changelog

## v1.2.1

### Added

- Added blue-highlighted `aac` and `yes` prompts so typed commands stand out in the console.
- Added an animated table flip completion sequence, ending with a green success message.
- Added color to the status faces so outcomes read at a glance: red for failures and yellow for warnings.
- Added green checkmark lines as each stage finishes (tracks found, audio downloaded, tracks split, songs tagged), so a run shows a clear record of what completed.
- Added automatic console color setup at startup, with a plain-text fallback for consoles that do not support color or when output is redirected, so nothing breaks on older terminals.
- Added clearer guidance when winget (Windows' App Installer) cannot be found, and the tool now opens the App Installer page automatically: the Microsoft Store when it is available, otherwise the App Installer page in the browser.

### Changed

- Changed the download progress to an accurate percentage bar based on yt-dlp's real download percentage, instead of the previous approximate `~(n/total)` track estimate.
- Changed the split and AAC progress counter to stay anchored in a fixed position with width-stable numbering, so it no longer shifts left and right as track and file names change length.

### Fixed

- Fixed first-run setup failing on some machines where winget was installed but not visible on PATH. The tool now locates winget by path, checking PATH, the Windows app execution alias, and the installed App Installer package, and also makes sure the app execution alias folder is on PATH.
- Fixed the dependency update and retry step so that when winget is unavailable it skips the update, says so instead of claiming it was updating tools, and still retries.
