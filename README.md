# Nong9 Live 🏀

Scorekeeper, stat tracker and highlight finder for a weekly pickup run or a
community league with a fixed crew. Teams change every week; the stats follow
each player.

## Features

| Area | What it does |
|---|---|
| **Runs** | One "run" per game day: date, gym, who showed up (whole crew pre-checked), any number of games. History of every run with scores and Day MVP. |
| **Team builder** | Players-per-team stepper, ⚖️ **Balance** (uses player ratings + spreads guards/bigs), 🎲 **Random**, "Same as last game". Whoever has played the fewest games today gets in first. 🔒 Lock a team for **winner stays**. Shirt-color team names. |
| **Live scorer** | Jumbotron scoreboard, tap a player → action pad (+1/+2/+3, misses, REB, AST, STL, BLK, TO, FOUL, AIRBALL). Asks "Assisted by?" after makes and "Rebound?" after misses (both optional). Undo, full play-by-play with delete, team fouls, optional game clock, "first to N" (+ win by 2) with game-over prompt, subs mid-game, team-only scoring. Supports **2s & 3s** and streetball **1s & 2s**. Screen stays on. |
| **Game summary** | Final score with confetti, auto MVP (Game Score, override-able), box score per team, play-by-play, share as text, **Next game** → winner stays / run it back / new teams. |
| **Players** | Trading-card profiles: photo, nickname, jersey #, positions (G/F/C), height/weight (cm/kg or ft/lb), shooting hand, 6 ratings → OVR, strengths & weaknesses, bio. Career splits, streaks, career highs, points-per-game chart, attribute radar, best teammates (win % together), game log. |
| **Stats** | Leaderboards (PPG, RPG, APG, SPG, BPG, Win %, Wins, Impact, FG%, 3P%, FT%, GP) with podium, plus a hall of shame 🤡 (airballs, fouls, turnovers) and single-game records. All time / this year / last 30 days. |
| **YouTube** | Attach the recording(s) to a run, watch inside the app. **Sync** once (pause on a tip-off, tap Sync) and every logged play becomes a tap-to-jump moment. Filter by game or player ("all of Jay's buckets"). Open in the YouTube app any time. |
| **Ref mode** | Soundboard: whistle, swish/+1/+2/+3, airball (sad trombone), brick, block, steal, travel, timeout horn, crowd, air horn, tip-off, game-over buzzer. 24/14 shot clock with countdown beeps. Text-to-speech announcer ("Jay for three!", "Rejected!", "Game point, Black!") + say-anything box. The same sounds fire automatically while scoring (toggle in Settings). |
| **Data** | Everything stays on the phone (offline at the gym). Export/restore a backup file (photos included) to move phones or hand scoring to someone else. Demo data to try it out. |

## Run it

```bash
flutter pub get
flutter run                      # phone plugged in with USB debugging, or an emulator
flutter test                     # 35 unit + widget tests
```

### Install on your Android phone without a cable

```bash
flutter build apk --release --split-per-abi
```

Copy `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` to the phone
(Drive, email, chat to yourself), open it, and allow "install unknown apps"
when Android asks. Release builds are currently signed with the debug key,
which is fine for personal sideloading. Set up a proper signing key before
publishing to the Play Store.

## Project layout

```
lib/
  main.dart, app.dart          app start, providers, bottom tabs
  models/                      Player, GameDay (+VideoLink), Game (+rules/teams), GameEvent, AppSettings
  data/                        AppStore (Hive, in-memory + write-through), backup, photos, demo data
  logic/                       stats engine, scoring rules, team balancer, YouTube parsing, formatting
  services/                    SoundService (SFX + TTS), Announcer (which sound/line for a play)
  screens/                     runs, game (team builder, live, summary), players, stats, ref, video, settings
  widgets/                     shared UI (avatars, badges, game cards, box score table)
assets/
  sounds/                      synthesized WAVs (see tool/generate_sounds.py)
  fonts/                       Barlow + Barlow Condensed (SIL OFL, see OFL.txt)
  icon/                        app icon (see tool/generate_icon.py)
tool/                          asset generators (pure Python, no dependencies)
test/                          unit + widget tests
```

**How stats work:** a game stores only its play-by-play (`GameEvent`s). Scores,
box scores, careers, leaderboards and records are all derived from those events,
so **undo** is just deleting an event, and fixing an old game recalculates
everything.

## Customizing

- **Sounds:** edit the recipes in `tool/generate_sounds.py`, then
  `python3 tool/generate_sounds.py`. Or drop in your own WAV with the same file name.
- **Icon:** `python3 tool/generate_icon.py && dart run flutter_launcher_icons`.
- **Colors / fonts:** `lib/theme/app_theme.dart`.
- **Announcer lines:** `lib/services/announcer.dart` and the pads in `lib/screens/ref/ref_screen.dart`.

## Notes & limitations

- Built against Flutter 3.38 / Dart 3.10. Some dependencies are pinned below
  their latest versions because the newest ones need a newer Flutter.
  `flutter upgrade` and then `flutter pub upgrade` will lift them.
- Verified on Android (emulator, API 36). The iOS project is configured
  (photo/camera permissions, icon), but it hasn't been built because Xcode
  isn't installed on this machine.
- Data lives on one phone. If several people need to score or view live,
  the next step is cloud sync (e.g. Firebase). Every model is already plain
  JSON, so that's a contained change in `AppStore`.
- Video sync assumes one continuous recording per video. If the camera was
  stopped between games, upload or add the parts as separate videos and sync each one.
