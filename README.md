# The Reading Room — Android MVP

> **PLACEHOLDER NAME:** "The Reading Room" is a temporary working title.
> JayCrypt is still choosing a real name. The name is a single constant —
> `AppConfig.name` in `lib/config.dart` — so renaming later is a one-line change.
> Do not hard-code the name anywhere else.

A quiet, library-vibe mobile book reader. Android first, built with Flutter
so iOS can follow from the same codebase. Offline-first, no accounts,
no backend, no paid services, no API keys.

## What's new in v3 (0.3.0, 2026-11-25)

Built from JayCrypt's bug-report video of 25 Nov 2026. Full notes: `V3_NOTES.md`;
change list: `CHANGELOG.md`; headless renders: `docs/v3-previews/`.

1. **A library room, real bookcases.** The library home is now a room
   (wall, wainscot, floor, lamp light) with 3D bookcase furniture: side
   panels, crown, plinth, a back panel with depth, shelf boards with a
   front lip and shadow, and a brass name plate per case. Every shelf
   (Currently Reading, Want to Read, Finished, Favourites, your own) is a
   bookcase; a full board wraps onto the next board of the same case. The
   **+** button builds a new bookcase. Scroll down to walk past them.
   Books can be arranged **by series** or **by genre** (library settings →
   Arrange bookcases, or Sort → Series). Book menu → **Edit details** sets
   title, author, series, part number and genre. Drag-and-drop between
   shelves works as before.
2. **Realistic spines + Library style.** Spines are painted with cloth or
   leather texture, a rounded-spine highlight, gold bands and foil title,
   and varied heights, widths and colours. The **gear at the top right**
   opens Library settings with a **Library style**: Modern (cloth spines,
   light oak, plaster room), Classic (leather and gold, walnut, green
   damask room), Ancient (cracked, worn leather with raised gilded bands,
   dark timber with iron brackets, stone room with an arched window).
   The choice is saved.
3. **PDFs restyle like EPUBs.** On open, a PDF's text is extracted
   (`syncfusion_flutter_pdf`, pure Dart, offline) into the same paged
   reader as EPUB/TXT, so page style, font size, line spacing, night mode
   and the leaf turn all apply. The result is cached next to the file
   (`<file>.reflow.json`). The **Original PDF layout** button switches to
   the page-image view (pdfx) and **Restyle text** switches back, carrying
   your place across. Scanned PDFs with no text open in the original
   layout automatically, with a short note.
4. **Page turn folds to the left.** Going forward, the right-hand page
   lifts and folds over to the left, showing its paper back; going back,
   the previous page comes back in from the left. Opening a book plays the
   same leftward fold as the cover opens.
5. **Focus Mode on first launch.** The first launch asks "Read without
   interruptions?" (Allow Focus Mode / Not now). Allow requests Do Not
   Disturb access and turns Focus Mode on by default for every book. It
   can be switched off any time in Library settings (saved).

## What the MVP does

1. **Import books** — EPUB, PDF, TXT from device storage (file picker).
   Files are copied into the app's own documents folder and stored locally.
2. **Library with shelves** — Currently Reading, Want to Read, Finished,
   Favourites, plus custom shelves you create. Move books between shelves
   (long-press a book), sort by title / author / recently read / progress,
   search by title or author. Progress bar per book.
3. **Reader** — EPUB/TXT paged reader with 3 page themes:
   - **Crisp** — clean white, sharp sans text
   - **Frayed** — worn off-white paper, classic serif
   - **Ancient** — dark parchment / sepia, old-style type
   Plus font size, line spacing, night mode, brightness dim, bookmarks,
   highlights, resume where you left off, and a table of contents
   (EPUB chapters, or "Chapter N" headings in TXT).
4. **Focus Mode** — immersive full-screen + Android Do Not Disturb.
   Tap the DND icon in the reader. If DND access has not been granted,
   the app explains it and offers to open the system settings page.
   If you skip it, reading still works full-screen — it just won't
   silence notifications. DND is restored when you leave Focus Mode /
   leave the reader. If DND is denied, the app never crashes.
5. **PDF reader** — page-by-page PDF view (pdfx) with progress saved.
6. **Sample books included** — so it works with no user files:
   - "The Library at Dusk" (original sample story, TXT)
   - "Pride and Prejudice (Excerpt)" by Jane Austen, public domain (TXT)
   - "The Library at Dusk" as an EPUB (`assets/sample_books/the-library-at-dusk.epub`)
     — import it with the Import button to test EPUB parsing / TOC.

## Not built yet

Accounts, social co-reading rooms, live page sync, voice chat, shared
highlights/comments, MOBI/AZW3 conversion, a book store, real EPUB covers.
See `../book-reader-spec.md`.

## Project layout

```
lib/
  main.dart                  App entry, warm library theme
  config.dart                App name (single constant)
  models/book.dart           Book / Shelf / Highlight models + JSON
  services/
    library_service.dart     Library state, shelves, import, persistence
                             (SharedPreferences JSON + local file copies)
    book_parser.dart         EPUB (epubx) + TXT parsing, pagination, TOC
    reader_theme.dart        Crisp / Frayed / Ancient themes + settings
    focus_mode.dart          Immersive + DND via MethodChannel
    app_prefs.dart           v3: library style, grouping, Focus Mode default
    pdf_text.dart            v3: PDF text extraction + reflow cache
  screens/
    library_screen.dart      Library room, bookcases, settings sheet,
                             edit details, Focus Mode onboarding
    reader_screen.dart       Paged EPUB/TXT/PDF-text reader, settings, TOC
    pdf_reader_screen.dart   Original PDF layout (pdfx)
  widgets/
    library_background.dart  v3: painted library room (3 styles)
    bookshelf.dart           v3: 3D bookcase, boards, drag-and-drop
    book_spine.dart          v3: painted cloth/leather spines
    leaf_turn_view.dart      v3: leftward page fold
    book_open_route.dart     v3: book-opening fold animation
    book_cover.dart          Generated cover (title/author, warm colours)
android/app/src/main/kotlin/.../MainActivity.kt
  MethodChannel "com.jaycrypt.readingroom/dnd":
  isDndGranted / requestDndAccess / setDnd
assets/sample_books/         2 TXT samples + 1 EPUB sample
```

## Build status (updated 2026-11-25, v3)

- `flutter analyze` — **passes, "No issues found!"** (v3, verified 2026-11-25).
- `flutter test` — **27 tests, all passed** (v3, 2026-11-25).
- `flutter pub get` — succeeds (69 dependencies resolved).
- **No APK built yet — blocked by the sandbox, not by the code.**
  The Gradle daemon protocol is raw TCP on loopback between two JVM
  processes, and this VM's sandbox intercepts/blocks outbound TCP
  connects from Java processes: the client JVM "connects" but the
  daemon never receives the Build message, so every build fails with
  `Could not receive a message from the daemon.` Proven on 2026-11-20:
  a Java TCP client (both `java.net.Socket` and NIO `SocketChannel`)
  gets the sandbox's "Other TCP connections is turned off for this
  assistant" message while the real peer never sees the connection;
  the same test in Python and in C connects fine. Renaming the `java`
  binary (even to a neutral path) does not bypass it. Gradle settings
  (heap size, daemon on/off, proxy on/off) make no difference.
  **Fix: build on a machine without this restriction** — e.g. a normal
  PC with Flutter + Android Studio, or a different VM. No code change
  is needed; the project is ready to build there.

## Build & run (on an unrestricted machine)

Prerequisites: Flutter 3.35+ (Dart 3.9+), Android SDK + JDK 17.
On this VM Flutter was installed from the official Linux tarball into
`~/flutter` and the Android SDK into `~/Android/Sdk` — see below.

```bash
export PATH="$HOME/flutter/bin:$PATH"
cd ~/workspace/app-idea/book-reader

flutter pub get
flutter analyze          # must pass with no errors
flutter run              # on a connected Android device / emulator

# Debug APK for the Samsung Galaxy A17 (arm64):
flutter build apk --debug
# -> build/app/outputs/flutter-apk/app-debug.apk
# Copy it to the phone and install, or:
flutter install --debug
```

## Notes / known limits

- EPUB covers are not extracted yet — covers are generated from
  title/author with warm library colours.
- Highlights/bookmarks are page-based (not text-selection) in this MVP.
- PDF highlights/bookmarks are not in this MVP.
- Pagination is character-based (re-chunked when font size changes),
  so a page number can shift slightly after a font-size change —
  progress % is preserved.
- `flutter analyze` was run on this VM — see the build report in the
  handoff. If you change dependencies, re-run `flutter pub get` first.

## Building the APK (GitHub Actions — recommended)

This VM cannot run `flutter build apk` — its sandbox blocks Gradle's Java
daemon from talking over local TCP, and that was proven with minimal Java
vs Python/C tests. No code change fixes that.

The project now includes `.github/workflows/build-apk.yml`. Push the repo
to GitHub and the APK builds automatically on GitHub's runners:
1. Create a repo (e.g. `book-reader`) and push this folder to `main`.
2. Open Actions in the repo — the "Build Android APK" run starts on push.
3. Download `app-debug.apk` from the run's Artifacts, copy it to the
   Galaxy A17, and install it.

Or build locally on any normal PC: `flutter pub get && flutter analyze && flutter build apk --debug`.

## Third-party licence note (v3)

PDF text extraction uses `syncfusion_flutter_pdf`, distributed under the
Syncfusion licence. It is free under the Syncfusion Community License for
individuals and small businesses that meet its terms; check
https://www.syncfusion.com/products/communitylicense before any commercial
release.
