# Doodle Time

Simple drawing + coloring app for kids 4-7. Flutter, tested first on web.

## Run

```bash
cd doodle_time
flutter create . --platforms=web,android,ios   # generates platform folders, keeps lib/ and pubspec.yaml
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

No Mac? Push to GitHub: `.github/workflows/ci.yml` runs analyze, test, and `flutter build web` in the
cloud and uploads the web build as an artifact. Android builds work on Windows/Linux/Mac. iOS needs a Mac
(or a cloud Mac service).

## Features

- Draw with finger/mouse: 3 brush sizes, 10 colors, rainbow brush
- Eraser (erases strokes only, never the coloring page)
- Stamps (emoji) - tap to place
- 12 coloring pictures (House, Fish, Flower, Rocket, Car, Butterfly, Rainbow, Cat, Boat, Snowman, Ice cream, Turtle) - tap an area to fill it
- Learn to draw: 24 step-by-step lessons grouped Easy / Medium / Harder (Sun, Apple, Moon, House, Tree, Mushroom, Robot, Sailboat; Fish, Flower, Ice cream, Car, Train, Rocket, Octopus; Butterfly, Bird, Turtle, Cat, Bunny, Dog, Penguin, Giraffe, Snowman). A reference picture shows each step (new part in orange, earlier steps gray); the child draws on a blank canvas, no dots to trace
- Read-aloud: a speaker button reads each lesson step (flutter_tts; also auto-reads when Sounds and voice is on)
- Stickers: finishing a lesson shows a celebration, saves a ⭐ on that lesson, and counts toward "⭐ n/24" (shared_preferences)
- Daily drawing: on an empty canvas a card shows "Today's drawing" (one lesson per calendar day, same on every device, no internet). Finishing it shows ⭐ Done today and builds a "🔥 n days in a row" streak (shown from 2 days). Day entries are stored as `day:YYYY-MM-DD` in the same progress set as lesson stickers
- Undo, redo, clear (with "Start over?" confirm)
- Autosave: your drawing is still there next launch (shared_preferences)
- Sounds for stamp and fill (generated tiny wav files in `assets/sounds/`)
- Grown-ups menu behind a math question: Save picture (web only for now), Sounds and voice on/off

## Layout

- `lib/models.dart` - tools and undoable ops (stroke, stamp, fill) with JSON
- `lib/drawing_controller.dart` - state, history, pointer logic, save/restore
- `lib/drawing_store.dart` - storage interface + shared_preferences impl
- `lib/pages.dart` - coloring pages as vector regions (100x100 space)
- `lib/daily.dart` - pick today's lesson by date, day keys, streak
- `lib/guides.dart`, `lib/guide_painter.dart` - step-by-step lessons (shapes per step) and the reference-picture painter
- `lib/board_painter.dart` - CustomPainter (paper, fills, strokes layer, outlines)
- `lib/draw_screen.dart` - UI
- `lib/parental_gate.dart`, `lib/sound_service.dart`, `lib/speech_service.dart`, `lib/save_png_*.dart`
- `preview/index.html` - clickable HTML mock of the UI feel (not the real app)
- `docs/` - kids store checklist, privacy policy template

## Add a drawing lesson

Add a `_myGuide()` in `lib/guides.dart` returning `DrawingGuide(name, emoji, steps)`. Each `GuideStep` has a short
instruction and the shapes added in that step (100x100 space; use `_dot` for filled eyes/buttons). Append it to
`drawingGuides` wrapped as `_lv(level, _myGuide())` (1 easy, 2 medium, 3 harder). Keep steps simple: circle, square, triangle, line.

## Add a coloring page

Add a `_myPage()` in `lib/pages.dart` returning `ColoringPage(name, emoji, regions)`
and append it to `coloringPages`. Later regions draw on top of earlier ones. Names must be unique
(saved drawings find their page by name).

## Not done yet

- Save picture on Android/iOS (stub returns false; add a gallery/share package)
- Spoken prompt on the parental gate for pre-readers
- Never compiled by the author of this scaffold: first `flutter analyze` may show small errors, fix and move on
