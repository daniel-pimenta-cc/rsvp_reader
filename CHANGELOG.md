# Changelog

All notable changes to Ledor are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Release notes on GitHub are taken verbatim from the section matching the tag,
so each version heading below must stay in the `## [x.y.z]` shape.

## [0.3.0]

### Added

- Floating mode switcher in the reader. The reading mode used to live behind an
  unlabelled glyph in the top bar; it is now a pill in the bottom-left corner
  that expands into named options, hides during playback, and steps aside as
  you scroll down.
- The chapter title in the top bar opens the chapter list, in every reading
  mode. Before, the only way in was a 14px glyph inside the playback dock —
  which e-reader mode hides entirely, leaving that mode with no chapter
  navigation at all. Closes #39.

### Changed

- The reader's settings sheet now carries only the settings that affect the
  mode you are reading in (3 rows in e-reader, 7 in RSVP, down from 22), with
  "All settings" opening the full page for everything else.
- The chapter list opens scrolled to the chapter you are in, and skips EPUB
  plumbing entries — split fragments and empty anchors under five words.
- The chapter title is no longer printed twice; the dock's status line now
  reads progress, time remaining and chapter counter on a single row.

### Fixed

- Text showed through the reader's floating pills when the background colour
  carried opacity, which the colour picker allows.
- The chapter list and side panel headings were hardcoded in English.

## [0.2.2]

### Fixed

- Reading progress synced between devices could land in the wrong place. The
  sync payload carried a `(chapterIndex, wordIndex)` pair, which only means
  something inside the tokenization that produced it — the same EPUB imported
  under a newer parser build splits into a different number of chapters, so
  chapter 8 on one device was chapter 11 on the other. Progress now travels as
  a book-global word cursor and is re-anchored onto the local chapter split on
  arrival. Books whose caches were built by different app versions can still
  land a few words off (same sentence); identical caches are exact.
- The reading percentage on library cards did not refresh when progress arrived
  from sync. The library derives it from the progress table but only recomputed
  when the books table changed, which sync does not always touch.

## [0.2.1]

### Fixed

- Folder-creation race in Drive sync that could produce duplicate `library/`
  folders.
- Linux desktop entry.

## [0.2.0]

### Added

- Google Drive sync in release builds, with a dedicated desktop OAuth loopback
  flow and its own landing page.

### Changed

- Repository audit: ~2k lines and 6 dependencies removed, plus sync and TTS
  fixes and the project website.
- CI test gate; coverage raised from 63% to 78%.

## [0.1.0]

### Added

- First tagged release: signed Android APK and Linux x64 bundle built on tag
  push.
- Bookmarks — named save points inside books and articles.
- Settings panel reorganised into categorised sections that reorder by the
  active reader mode.

### Changed

- Renamed from RSVP Reader to Ledor.
- Faster Android startup and book opening.
