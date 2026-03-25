# Skitter

> **Survive the swarm.** A first-person survival horror arcade game for iPhone.

Skitter is a first-person survival game built with **SwiftUI** and **RealityKit**. You're trapped in a dark arena, hunted by a growing swarm of cockroaches. Your only way out: find the one Baygon hidden among five mystery bags and use it to escape — before the roaches reach you.

---

## Gameplay

- Navigate a foggy 60m × 60m arena using dual-thumb virtual controls
- Find and trigger the 1 **Baygon** bag among 4 **Bait** bags
- Triggering a bait bag escalates the swarm — more roaches, faster roaches
- Any contact with a roach is instant death
- One run, no checkpoints

### Win Condition
Trigger the Baygon bag. Your best win time and fewest bags opened are saved.

### Lose Condition
Touch any roach.

---

## Roach Types

| Type | Speed | Behavior |
|------|-------|----------|
| **Chaser** | 4.0 m/s | Spawns at game start, navigates around obstacles |
| **Giant** | 2.0 m/s | Spawned on bait triggers, slow but large |
| **Flying** | 6.0 m/s | Spawned on bait triggers, hovers over obstacles, dive-bombs at close range |

### Escalation (per bait triggered)
| Bait | Wave |
|------|------|
| 1 | +3 Giants |
| 2 | +2 Giants, +3 Flying |
| 3 | +1 Giant, +4 Flying, +15% speed bump |
| 4+ | +5 Flying, +15% speed bump |

---

## Tech Stack

| Layer | Framework |
|-------|-----------|
| 3D Rendering | RealityKit 4 — `RealityView`, ECS Systems, `PhysicsBodyComponent` |
| UI + HUD | SwiftUI — ZStack overlay, `Canvas` minimap |
| Input | SwiftUI `DragGesture` — dual-thumb virtual joystick |
| Haptics | CoreHaptics — proximity, bait, win, game over patterns |
| Spatial Audio | AVFoundation — `AVAudioEngine`, `AVAudioEnvironmentNode` |

**Target**: iOS 18.0+, iPhone only, landscape orientation.

---

## Project Structure

```
Skitter/
├── App/
│   ├── SkitterApp.swift          # App entry + screen router
│   └── AppState.swift            # Global state, best score persistence
│
├── Game/
│   ├── GameView.swift            # RealityView + HUD + game loop
│   ├── GameState.swift           # Session state — timer, bait count, bags
│   ├── ArenaBuilder.swift        # Arena factory + obstacle configs
│   ├── PlayerEntity.swift        # Capsule player entity
│   ├── FogSphere.swift           # Layered visibility fog around player
│   ├── MysteryBagEntity.swift    # Bag entities + reveal logic
│   ├── RoachComponent.swift      # ECS component — type, speed
│   └── RoachEntity.swift         # Chaser / Giant / Flying factories
│
├── Systems/
│   ├── RoachAISystem.swift       # Chase + separation + potential-field avoidance
│   ├── ContactSystem.swift       # Roach contact → game over
│   ├── BagTriggerSystem.swift    # Bag contact → win or escalation
│   ├── EscalationSystem.swift    # Bait count → spawn waves + speed bumps
│   └── PuddleSystem.swift        # Oil puddle → player damping modifier
│
├── Controllers/
│   ├── MotionController.swift    # Joystick + look-drag → velocity + yaw
│   ├── HapticManager.swift       # CHHapticEngine patterns
│   └── AudioManager.swift        # BGM + spatial roach audio + SFX
│
├── HUD/
│   ├── HUDView.swift             # HUD container
│   ├── MiniMapView.swift         # Top-down Canvas minimap + radar cone
│   ├── DualThumbControlView.swift # Left joystick + right look-drag
│   ├── VignetteView.swift        # Green gas overlay (scales with bait count)
│   ├── TriggerLabelView.swift    # "BYEGONE" / "FOOD PILE" label
│   └── BagsRemainingView.swift   # 5-dot bag counter
│
└── UI/
    └── MainMenuView.swift        # Home screen + best run display
```

---

## Assets

### 3D Models (USDZ)
| Model | Role |
|-------|------|
| `black_plastic.usdz` | Mystery bag (initial) |
| `byegone.usdz` | Bag reveal — win |
| `food_pile.usdz` | Bag reveal — bait |
| `roach_1.usdz` | Chaser |
| `roach_2.usdz` | Giant |
| `roach_3.usdz` | Flying |
| `trash_pile.usdz`, `trash_barrel.usdz`, `oil_drum.usdz`, `fence.usdz` | Obstacles |
| `oil_puddle.usdz` | Trigger area (slow zone) |

### Audio (WAV)
| File | Role |
|------|------|
| `background_music.wav` | Looping BGM |
| `skittering_sound.wav` | Spatial roach loop |
| `correct.wav` / `wrong.wav` | Bag reveal SFX |
| `gameover_win.wav` / `gameover_lose.wav` | End state SFX |

---

## Development Phases

- **Phase 1 — MVP**: Ball entity, gyroscope input, chaser roach, isometric camera
- **Phase 2 — New Core**: First-person view, mystery bag system, escalation, full HUD, spatial audio, haptics *(current)*
- **Phase 3 — Full Horror**: Animated roach models, per-tier visual upgrades, audio polish

---

## Documentation

See [`skitter-game-documentation.md`](./skitter-game-documentation.md) for a full breakdown of every file's logic and implementation details.
