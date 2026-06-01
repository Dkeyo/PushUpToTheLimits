# 💪 PushUpToTheLimits

A Garmin Connect IQ app for Garmin Epix Pro Gen 2 (51mm) built in Monkey C — a daily push-up counter with streak tracking, weekly progress chart, customizable reminders, and a tactical UI inspired by Fenix camouflage watch faces.

Self-learning project — first contact with Connect IQ SDK and the Garmin ecosystem. Monkey C learned from scratch during the project (background in C# and Python).

---

## What the app does

- Daily push-up counter with persistent storage (Application.Storage)
- Weekly bar chart with daily goal line
- Streak tracking (consecutive days with goal achieved)
- Customizable settings via Menu2: daily goal, reminder time
- Background reminders (TemporalEvent) — watch vibrates to remind you about push-ups
- Celebration screen + vibration on daily goal completion
- Tactical UI with circular tick ring (100 ticks positioned trigonometrically around the screen)
- Four-corner layout: STREAK · day of week · yesterday's score · personal record

---

## Tech Stack

| Category | Technology |
|----------|-----------|
| Language | Monkey C |
| SDK | Connect IQ SDK 9.1.0 |
| Target device | Garmin Epix Pro Gen 2 (51mm) |
| IDE | Visual Studio Code + Monkey C extension |
| Runtime | Java JDK (required by SDK) |
| Deployment | USB → GARMIN/APPS/ |

---

## Key skills used

- **Persistent storage** — state saved between app launches (Application.Storage, JSON-like keys)
- **Trigonometry in UI** — drawTickRing() uses Math.cos / Math.sin to calculate positions of 100 ticks around a circle based on angle and radius
- **Event-driven UI** — BehaviorDelegate handling (Up/Down/Select/Back buttons)
- **Menu2 settings screens** — native Garmin UI for app configuration
- **TemporalEvent (Background)** — periodic wake-up of the app at configured times
- **Custom drawing in View.onUpdate(dc)** — full pixel control: bitmaps, text, shapes, circles
- **Resource management** — fonts, colors, strings in resources/

---

## Project structure
PushUpToTheLimits/
├── manifest.xml                          # app config, permissions, target devices
├── monkey.jungle                         # build configuration
├── source/
│   ├── PushUpToTheLimitsApp.mc           # app lifecycle + background service
│   ├── PushUpToTheLimitsView.mc          # main view + circular tick ring drawing
│   ├── PushUpToTheLimitsDelegate.mc      # button handling
│   ├── PushUpHistoryView.mc              # weekly chart view
│   ├── PushUpHistoryDelegate.mc          # chart navigation
│   └── SettingsMenu.mc                   # settings screens (Menu2)
├── resources/
│   ├── drawables/                        # icons, bitmaps
│   ├── fonts/                            # custom fonts (after BMFont conversion)
│   ├── strings/                          # UI strings
│   └── settings/                         # settings definitions
└── bin/                                  # compiler output (.prg) — gitignored

---

## How to run locally

**1. Install required tools:**
- [Visual Studio Code](https://code.visualstudio.com/)
- [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/) — download SDK 9.1.0+ and device files for Epix Pro Gen 2 (51mm)
- [Java Runtime](https://adoptium.net/) (required by SDK)
- Monkey C extension in VS Code (official Garmin extension)

**2. Generate developer key:**
Ctrl+Shift+P → Monkey C: Generate a Developer Key

**3. Clone the repo:**
```bash
git clone https://github.com/Dkeyo/PushUpToTheLimits.git
cd PushUpToTheLimits
```

**4. Run in simulator:**
Ctrl+Shift+P → Monkey C: Run No Debug

**5. Deploy to physical watch (optional):**
- Build .prg: `Ctrl+Shift+P → Monkey C: Build for Device`
- Connect watch via USB
- Copy `PushUpToTheLimits.prg` to `GARMIN/APPS/`
- Disconnect — app appears in Activities & Apps menu

---

## Design decisions

**Why Garmin Epix Pro Gen 2?**
It's my own watch. The project came from a real need (daily push-up goal + desire to learn Monkey C). Embedded/wearable dev was new territory — I wanted to see what working with constrained resources looks like (limited memory, limited CPU, custom UI without frameworks).

**Why Monkey C instead of another platform?**
Connect IQ is Garmin's official ecosystem and the only path to native apps on these devices. Monkey C syntax is close to Java / C#, so the entry barrier from my background (C#, Python, SQL) turned out to be low.

---

## What's next

- Science Gothic font integration via BMFont
- Weekly chart improvements (scaling, overflow handling)
- Multi-reminder testing on physical device
- Companion project FitTracker DB — SQL database for aggregating stats from various activities (planned)

---

## What I learned

- **Working with embedded constraints** — thinking about memory and battery consumption differently than in desktop apps
- **Custom 2D rendering without UI components** — everything drawn pixel by pixel
- **Persistent storage patterns** — designing key schema in Application.Storage to survive app updates
- **Cross-environment debugging** — differences between simulator and physical device (timing, accelerometer accuracy, battery saver behavior)

---

## Project status

🟢 **Running on physical device** — app deployed and used in daily training since May 2026. Active UI development and polishing in progress.

---

## Contact

Dawid Kowal · [GitHub](https://github.com/Dkeyo) · dawidkowal777@gmail.com
