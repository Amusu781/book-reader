# Book Reader App — Spec Draft (2026-11-20)

Owner: JayCrypt
Platform: Mobile-first, Android first (his Samsung Galaxy A17), Flutter so iOS can follow from same codebase
Built with: Google AI Pro — Gemini app for spec, Antigravity for building, Jules for background tasks

## The idea in one line
A mobile book reader that feels like a quiet library, with real bookshelves, beautiful old-paper page styles, and a way to read the same book live with a friend.

## Core experience — Library vibe
- Warm, quiet home screen that looks like a library / reading room, not a file list
- Immersive reading view: full screen, no clutter
- Focus Mode: when a reading session starts, the app asks for Do Not Disturb access on Android, silences notifications, and restores them when you exit. Also blocks in-app distractions.
- Ambient option (v2): soft library sounds — page turns, rain, fireplace — toggleable, off by default

## Books & formats
MVP: EPUB, PDF, TXT — import from device storage / Files / Downloads
v2: MOBI / AZW3 via on-device conversion, DOCX, CBZ/CBR for comics
- Import keeps original file, shows cover, title, author, progress %
- Offline-first: books and progress stored on device

## Bookshelves
- Default shelves: Currently Reading, Want to Read, Finished, Favourites
- Custom shelves: user creates any shelf, drag / move books between shelves
- Sort by title, author, recently read, progress
- Search across library

## Page styles / layouts — the look of the book
Themes the reader can switch per book or globally:
1. Crisp — clean white, sharp black text, modern serif/sans, clean margins
2. Frayed — worn / aged paper, off-white, slightly rough edges, classic serif
3. Ancient — dark parchment / sepia, old-style font, ornamental chapter headings
Controls: font, font size, line spacing, margins, brightness, day / sepia / night
Page turn: swipe, tap edge, or volume keys (optional); subtle page-curl animation on Frayed/Ancient

Reader features (MVP): bookmarks, highlights, notes, dictionary lookup, reading progress, resume where you left off, table of contents for EPUB

## Social co-reading — the big differentiator (v2, after MVP)
- Create a Co-Read Room: pick a book you both have, invite a friend by link / code
- Live sync: when either person turns a page, both move together; either can take control, hand control back
- Voice chat in the room (WebRTC / LiveKit), push-to-talk optional, mute anytime
- Shared thoughts: live highlights, margin comments, reactions (❤️, 😮, etc.) tied to a page / paragraph
- Room is private by default, ends when both leave, chat/highlights saved to the book if both agree
- Needs: accounts (Google sign-in), Firebase Auth + Firestore for sync, Storage for covers

## Tech — proposed
- Flutter (Dart) — one codebase, Android first, iOS later
- Local storage: SQLite / Hive for library + progress
- EPUB: epubx / folio-style parser; PDF: pdf rendering package
- Backend (for co-read only): Firebase — Auth, Firestore, Storage. Free tier to start, fits Google Cloud credits from AI Pro.
- Voice (for co-read only): LiveKit / WebRTC
- Build tool: Antigravity (Google AI Pro), Gemini app for planning, Jules for background fixes

## MVP scope — what to build first
1. Import EPUB / PDF / TXT
2. Library with shelves
3. Reader with 3 page themes + font/brightness controls
4. Focus Mode (DND + immersive)
5. Bookmarks, highlights, progress, resume
6. Android APK to test on his A17

Explicitly out of MVP: accounts, co-read rooms, voice chat, MOBI conversion, store / buying books

## Open decisions
- App name: TBD — suggestions: The Reading Room, Lantern Library, Quiet Shelf, CoRead
- Android-only for MVP, or Flutter from day one so iOS is easy later? (Recommended: Flutter from day one)
- Co-read backend: Firebase (recommended) vs Supabase
