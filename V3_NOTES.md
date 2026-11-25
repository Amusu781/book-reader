# The Reading Room — v3 notes (2026-11-25)

Source: JayCrypt's bug-report video (uploaded 25 Nov 2026 07:39 WAT). The
narration transcript is in `bugvideo-1125/transcript.txt`. All 5 requested
items are built; none were deferred.

Version: `pubspec.yaml` `0.3.0+3`, `lib/config.dart` `0.3.0-v3`.

## Verification summary
- `flutter analyze`: **No issues found** (Flutter 3.35.7 / Dart 3.9.2, the
  same as CI).
- `flutter test`: **27 tests, all passed**. The files are
  `test/v3_features_test.dart` (17 new), `test/render_preview_test.dart`
  (5 new), `test/library_crash_test.dart` (3) and `test/pagination_test.dart`
  (2).
- Headless renders, made with real fonts in the test engine, are in
  `docs/v3-previews/`: `library_modern.png`, `library_classic.png`,
  `library_ancient.png`, `leaf_fold_t035.png` (forward turn at 35%, folding
  left) and `pdf_restyled_ancient.png` (an imported PDF in the Ancient page
  style). To regenerate them, run
  `RR_PREVIEW_DIR=/tmp/rr flutter test test/render_preview_test.dart`.
- **APK not built here.** This VM blocks Gradle, so the debug APK has to come
  from GitHub Actions (`.github/workflows/build-apk.yml`) after the push.

## 1. Library room, 3D bookcases, series and genre
**What changed**
- The whole screen below the header is a painted room
  (`LibraryRoomPainter`). Modern has a plaster wall, oak wainscot,
  floorboards and a pendant glow. Classic has green damask, walnut
  wainscot, parquet with a rug and brass lamp glows. Ancient has stone
  blocks, an arched moonlit window, beams, flagstones and torch glow. A
  vignette sits over all three. The room stays fixed while the bookcases
  scroll over it, like walking along a library.
- Each shelf is a bookcase. It has side panels, a crown with dentils, a
  plinth with feet (plus iron brackets in Ancient), a recessed back panel
  with inner walls and a top shadow, and boards with a top face and a front
  lip that casts a shadow. A brass name plate shows the shelf name and the
  book count. When a board is full, books wrap onto the next board of the
  same case. The free end of a board is the drop target ("Empty shelf —
  drag a book here").
- **+** (and the "Add a bookcase" tile at the bottom) builds a new bookcase
  and scrolls down to it.
- Book fields `series`, `seriesIndex` (part), `genre`, `lastCharOffset` and
  `pdfOriginalLayout` are saved, and v1/v2 JSON still loads. Book menu →
  **Edit details** has fields for Title, Author, Series, Part and Genre, with
  suggestion chips from your library.
- Library settings → **Arrange bookcases**: Shelves, By series (one case per
  series, in part order, plus "Not in a series") or By genre (plus "No genre
  yet"). Sort gains "Series", and search matches series and genre.
- Drag-and-drop between shelf bookcases works the same as before. While the
  library is arranged by series or genre, the cases are views, so dropping is
  off there.

**Files**: `lib/widgets/library_background.dart`, `lib/widgets/bookshelf.dart`,
`lib/screens/library_screen.dart`, `lib/models/book.dart`,
`lib/services/library_service.dart`, `lib/services/app_prefs.dart`.

**Tests**: bookcase render with name plates, board wrapping, series order,
genre grouping, JSON round-trip including old JSON, series arrangement in
the UI, and the edit-details flow.

## 2. Realistic spines and the Library style setting
**What changed**
- `BookSpine` paints every spine with a stable per-book look: varied height
  (138–180), width (30–55) and colour from the style's palette, and a
  rounded-spine highlight and shadow.
  - Modern: cloth weave with light bands and a white title.
  - Classic: leather grain, gold double bands, a label panel and a gold-foil
    title.
  - Ancient: dark, worn leather with cracks and scuffs, raised gilded hubs
    and a slightly larger size.
  
  Reading progress shows as a ribbon at the foot of the spine.
- Gear at the top right → **Library settings** has three parts:
  - Library style chips (Modern / Classic / Ancient), which change the
    spines, the bookcase wood, the room and the app-bar colour.
  - Arrange bookcases.
  - The Focus Mode switch.
  
  These are saved in SharedPreferences (`library_style_v3`,
  `library_grouping_v3` and `focus_mode_default_v3`). The default style is
  Classic.

**Files**: `lib/widgets/book_spine.dart`, `lib/services/app_prefs.dart`,
`lib/screens/library_screen.dart` (`LibrarySettingsSheet`),
`lib/widgets/bookshelf.dart`, `lib/widgets/library_background.dart`,
`lib/main.dart`.

**Tests**: spines render in every style, and the gear changes the style and
focus switch and they persist.

## 3. PDFs convert to restyleable text
**What changed**
- When a PDF opens, `PdfTextService` extracts its text page by page with
  `syncfusion_flutter_pdf` (pure Dart, works offline on Android) in a
  background isolate.
  - Wrapped lines are joined, broken hyphens mended, paragraphs kept and
    lone page numbers dropped.
  - Chapters come from the PDF's bookmarks, or from headings when there are
    no bookmarks.
  - The result is cached next to the file as `<pdf>.reflow.json`, so it is
    extracted only once. The cache is deleted with the book.
- The text goes into the same paged reader as EPUB/TXT, so page style
  (Crisp/Frayed/Ancient), font size, line spacing, night mode, brightness
  and the leaf turn all apply.
- The app-bar **Original PDF layout** button opens the pdfx page view. Its
  **Restyle text** button switches back. Each book remembers which view it
  was last read in.
- Progress mapping: the reader saves a character offset and the original
  PDF page. A page map converts between the two, so switching views lands
  on the matching page.
- Scanned PDFs (fewer than about 40 letters overall, or under 15 per page)
  and failed conversions open in the original layout automatically, with a
  note.

**Files**: `lib/services/pdf_text.dart` (new), `lib/services/book_parser.dart`,
`lib/screens/reader_screen.dart`, `lib/screens/pdf_reader_screen.dart`,
`lib/services/library_service.dart`, `pubspec.yaml`
(`syncfusion_flutter_pdf: ^31.2.18`).

**Tests**: a real generated PDF is extracted with a page map, a no-text PDF
is detected, reflow rules are checked, the cache round-trips, and the reader
test opens an imported PDF file from disk. That test confirms the Ancient
page style is applied, the text shows, the Original layout button is there
and the cache file is written (see `pdf_restyled_ancient.png`).

## 4. Page turn folds to the LEFT (and on opening a book)
**What changed**
- `LeafTurnView` was rewritten around `LeafFold`.
  - On a forward turn, the fold line travels from the right edge to the
    left. The right part of the current page lifts and lies mirrored over
    the left part, showing a paper-coloured back with curl shading. The next
    page shows on the right with a shadow along the fold.
  - A back turn plays the same fold in reverse, so the previous page comes
    back in from the left.
  - A turn lasts 480 ms. Swipe and tap directions are unchanged: tap or swipe
    right to go forward.
- Opening a book uses `BookOpenRoute` (900 ms). The cover rises, then folds
  open to the left over the first page, in the library style.

**Files**: `lib/widgets/leaf_turn_view.dart`, `lib/widgets/book_open_route.dart`
(new), `lib/screens/library_screen.dart`, `lib/screens/reader_screen.dart`.

**Tests**: the fold geometry test confirms the fold line moves right to left
as the turn goes on. A widget test taps the right edge, confirms a forward
turn with a leftward fold that ends on page 2, then confirms the back turn.
The preview is `leaf_fold_t035.png`.

## 5. Focus Mode offered on first launch
**What changed**
- On first launch the library shows "Read without interruptions?" with
  **Not now** and **Allow Focus Mode**.
  - **Allow** requests Do Not Disturb access through the existing
    `com.jaycrypt.readingroom/dnd` channel and turns Focus Mode on by
    default. When you come back from the system settings, a note confirms
    whether access was granted.
  - **Not now** leaves it off.
  
  The prompt appears once (`focus_onboarding_done_v3`).
- When the default is on, every book opens in Focus Mode (immersive, plus
  DND if granted). It can be switched off in Library settings, and the
  in-reader Focus button still works as before.

**Files**: `lib/screens/library_screen.dart`, `lib/services/app_prefs.dart`,
`lib/screens/reader_screen.dart`, `lib/screens/pdf_reader_screen.dart`,
`lib/main.dart`. The Android side (`MainActivity.kt`, manifest permission) is
unchanged.

**Tests**: first launch with Not now, first launch with Allow, and the
settings switch persisting.

## Other changes
- The reader resumes from the saved character offset. This also fixes a v2
  bug where the first pagination used anchor 0.
- The reader body now fills the screen, so a short last page is still a full
  sheet.
- README updated, `CHANGELOG.md` added, and a Syncfusion licence note added.

## Not verified here
- Runtime on JayCrypt's Galaxy A17: performance, animation smoothness,
  touch feel and the real DND permission screen.
- The APK build, which will happen in GitHub Actions.
- Extraction quality on his real PDFs, e.g. "Basic5 Mathematics".
  Maths-heavy, multi-column or table layouts may reflow imperfectly; the
  Original layout button is the fallback for those.
- Time to extract very large PDFs on the phone on first open. After that
  the cache is used.
- Renders came from Flutter's test engine with DejaVu fonts. On the phone
  the system serif/sans fonts will be used.
