# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Doodle Time

Flutter drawing + coloring app for kids 4-7. Test on web first (`flutter run -d chrome`), mobile later.
Owner: Joseph, senior .NET dev, new to Flutter. Keep replies short.

## STATUS: runs on web, not yet on a phone
Flutter SDK: `~/flutter/bin/flutter` (3.47.x stable). As of 2026-10-24 `flutter analyze` is clean, all 27
tests pass, and the app runs in the browser. All 12 coloring pages and 24 lessons were checked visually.

Still unverified at runtime: `lib/save_png_web.dart` (package:web API), `audioplayers`/`flutter_tts` web
behavior, Android/iOS.

Web build makes no Google requests only if: built with `--no-web-resources-cdn` (CI does; else CanvasKit comes
from www.gstatic.com), and every character in the UI is in Roboto or the bundled emoji font. Anything else (new
emoji, symbols like ▭ ⬡) makes Flutter fetch a Noto font from fonts.gstatic.com. Bundled font:
`assets/fonts/NotoColorEmoji.ttf` (noto-emoji v2026-09-24, 10.7 MB, OFL), web-only via `platforms: [web]` in
pubspec, loaded in `lib/emoji_font.dart`. Bare `TextStyle`s outside the theme (painters) need
`fontFamilyFallback: kEmojiFallback`.

## Commands
- Web preview without opening Chrome: `flutter run -d web-server --web-port 8765` (`.claude/launch.json`
  has it). After a restart the first page load is blank while DDC compiles; reload once.
- Single test by name: `flutter test --plain-name "stroke can be undone and redone"`
- Single group: `flutter test --plain-name "daily drawing"`
- CI runs `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build web --release`
- Platform folders (`android/ ios/ web/ ...`), `.metadata`, `analysis_options.yaml` and `pubspec.lock` are
  gitignored: they come from `flutter create .`. CI regenerates them each run, so don't put hand edits there.

## Rules of the project
- Audience is pre-readers: big touch targets, emoji, voice read-aloud, no text-only flows.
- No ads, accounts, analytics, network calls, IAP, links out. Keep it that way (kids store policies).
  Re-check `docs/KIDS_STORE_CHECKLIST.md` whenever a package is added.
- Any new SDK must work offline and send nothing off-device.
- Saves are best effort: storage/audio/voice failures must never crash drawing (try/catch, ignore).
- Drawings are stored as normalized points (0..1) so they survive resize/rotate.
- Coloring pages and lessons live in a 100x100 design space. Names must be unique (saves key by name).

## Architecture
- `main.dart` builds `KidsDrawApp(store, progressStore, now)`. All three are injectable; tests pass
  in-memory stores (`MemoryStore`, `MemoryProgress` in the test file) or null (= no persistence) and a fake
  clock `now` for daily/streak tests. Keep new storage/time dependencies injectable the same way.
- `DrawingController` (ChangeNotifier) owns the op list (`ops`), redo stack, live stroke and current page.
  Every user action is one `DrawOp` (stroke/stamp/fill) so undo/redo is just list pop/push. Autosave is a
  debounced timer writing `encode()` JSON (`{'v':1,'page':name,'ops':[...]}`); unknown/corrupt ops are skipped.
- `BoardPainter` repaints off the controller. Paint order: white paper, page region fills (last `FillOp` per
  region wins), strokes + stamps in their own `saveLayer` (so eraser only clears strokes, never the page),
  then page outlines on top. Each outline is clipped by the union of the regions above it, so hidden edges
  don't show through (union cached per page+size). Use an even-odd clip, not `PathOperation.difference`: the
  difference op left hidden lines visible on web.
- `draw_screen.dart` holds all UI state beyond drawing: lesson mode/step, daily banner, stickers, grown-ups
  menu. It owns `SoundService`/`SpeechService`; the single "Sounds and voice" switch gates both.
- Saving PNG uses a conditional import: `save_png_stub.dart if (dart.library.js_interop) save_png_web.dart`.
  Same pattern for any future web-only code.
- Progress (lesson ⭐ and daily `day:YYYY-MM-DD` entries) shares one string set in `ProgressStore`.

## Adding content
- Lesson: `_myGuide()` in `lib/guides.dart` returning `DrawingGuide(name, emoji, steps)`, append to
  `drawingGuides` as `_lv(level, _myGuide())` (1 easy, 2 medium, 3 harder). Use `_dot` for filled eyes/buttons.
  Each step's text must have speakable words (a test checks).
- Coloring page: `_myPage()` in `lib/pages.dart` returning `ColoringPage(name, emoji, regions)`, append to
  `coloringPages`. Later regions draw on top of earlier ones.

## Map
- `lib/models.dart` ops (stroke/stamp/fill) + JSON
- `lib/drawing_controller.dart` state, undo/redo, pointer logic, autosave; palette/stamps/brush constants
- `lib/drawing_store.dart` DrawingStore + ProgressStore (shared_preferences)
- `lib/pages.dart` 12 coloring pages (tap-to-fill regions)
- `lib/guides.dart`, `lib/guide_painter.dart` 24 step-by-step lessons (level 1-3) + reference painter
- `lib/daily.dart` today's lesson by date, `day:YYYY-MM-DD` keys, streak
- `lib/draw_screen.dart` all UI (large; consider splitting widgets into files)
- `lib/speech_service.dart` flutter_tts, `lib/sound_service.dart` audioplayers, `lib/parental_gate.dart` math gate
- `assets/sounds/` tiny generated wav files for stamp/fill
- `preview/index.html` throwaway HTML mock of the feel (not the real app)
- `.github/workflows/ci.yml` analyze + test + web build

## Not done yet / ideas
- Save picture on Android/iOS (stub returns false; web only now)
- Spoken parental gate for pre-readers (Apple suggests)
- "My stickers" page, brush picker (crayon/sparkle), compare-my-drawing finish screen
- App icon, screenshots, privacy policy contact details
