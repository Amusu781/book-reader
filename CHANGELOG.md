# Changelog — The Reading Room

## 0.3.0 (v3) — 2026-11-25

From JayCrypt's bug-report video of 25 Nov 2026.

### Added
- Library home is a painted library room (`LibraryBackground`) in three styles:
  plaster and oak (Modern), green damask and walnut (Classic), stone with an
  arched moonlit window (Ancient).
- Every shelf is drawn as a 3D bookcase: side panels, crown and cornice, plinth
  with feet, a back panel with inner walls, shelf boards with a front lip and
  shadow, and a brass name plate showing the book count. Full boards wrap onto
  more boards in the same case.
- **+** now builds a new bookcase ("New bookcase" → "Build it") and scrolls to it.
- Series, part number and genre fields on every book. They are saved, and old
  libraries still load. Book menu → **Edit details** edits title, author,
  series, part and genre, with suggestion chips.
- Arrange bookcases by Shelves, Series (in reading order) or Genre. Sort gains
  a "Series" option. Search also matches series and genre.
- Painted book spines (`BookSpine`): cloth weave (Modern), leather with gold
  bands and a label panel (Classic), cracked, scuffed leather with raised
  gilded hubs (Ancient). Each has a rounded-spine highlight, varied
  size and colour, and a progress ribbon.
- Top-right **Library settings** gear: Library style (Modern / Classic /
  Ancient), Arrange bookcases, and the Focus Mode switch. All three are saved.
- PDF text extraction (`syncfusion_flutter_pdf`, pure Dart, offline) into the
  reflowable reader, so page style, font, spacing, night mode and the leaf
  turn apply to PDFs. Results are cached as `<file>.reflow.json`. Chapters
  come from the PDF bookmarks, or from headings when there are no bookmarks.
- **Original PDF layout** / **Restyle text** switch between the two PDF views,
  keeping your place. Scanned PDFs with no text fall back to the original
  layout automatically, with a note.
- Book-opening animation (`BookOpenRoute`): the cover lifts, then folds open
  to the left.
- First-launch Focus Mode prompt ("Read without interruptions?" with
  Allow Focus Mode / Not now). Allow requests Do Not Disturb access and turns
  Focus Mode on by default.

### Changed
- Page turn (`LeafTurnView`): forward turns now fold the page over to the
  LEFT, showing the paper back, with curl shading. Back turns return from
  the left.
- The reader resumes from a saved character offset, so the place survives
  font and spacing changes, and the first pagination no longer resets to
  page 1.
- The reader body fills the screen, so a short page still shows a full
  sheet of paper.
- Deleting a book also deletes its PDF text cache.

### Version
- `pubspec.yaml` 0.3.0+3, `AppConfig.version` 0.3.0-v3.

## 0.2.x (v2) — 2026-11-20
- Library home shelves, drag-and-drop between shelves, page textures,
  leaf turn, sticky settings, Focus Mode, and a launch crash fix
  (commit `1a56514`).

## 0.1.0 (v1) — 2026-11-20
- First Android MVP: EPUB/PDF/TXT import, shelves, 3 page themes, Focus Mode.
