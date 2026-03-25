# Skitter Game — Project Documentation

A survival horror arcade game built with SwiftUI and RealityKit. Below is a detailed breakdown of every `.swift` file in the project, organized by folder.

---

## App Folder

### 1. `AppState.swift`
- **Contents**: Defines global application state using `@Observable` and the `Screen` enum.
- **Logic**:
  - Tracks the active screen: `.menu` or `.playing`.
  - Stores last-session stats: `lastSurvivedTime`, `lastBagsOpened`, and `lastIsWin`.
  - Persists `bestWinTime` (fastest win) and `bestBagsOpened` (fewest bags opened on a winning run) to `UserDefaults`.
  - Best time is only updated on a win — either the first win ever, or faster than the previous record.
  - Navigation functions: `startGame()`, `endGame(survivedTime:isWin:bagsOpened:)`, and `returnToMenu()`.

### 2. `SkitterApp.swift`
- **Contents**: Main SwiftUI app entry point.
- **Logic**:
  - `SkitterApp` initializes the root `AppState` and injects it into the environment.
  - `ContentView` acts as a screen router: shows `MainMenuView` when `currentScreen == .menu`, `GameView` when `.playing`.
  - Screen transitions use `.animation(.easeInOut(duration: 0.4))` with an opacity transition.
  - Status bar and system overlays are fully hidden.

---

## Controllers Folder

### 3. `HapticManager.swift`
- **Contents**: Manages haptic feedback using `CoreHaptics`.
- **Logic**:
  - Checks hardware support via `CHHapticEngine.capabilitiesForHardware().supportsHaptics` before initializing.
  - Maintains a persistent `proximityPlayer` (`CHHapticAdvancedPatternPlayer`) that runs continuously and is modulated every frame based on the distance to the nearest roach.
  - Key functions:
    - `playObstacleHit()`: Sharp transient haptic (intensity 0.8, sharpness 0.9) when hitting a wall or obstacle.
    - `playBaygonWin()`: Three rapid transient bursts (intensity 1.0) followed by a short continuous — signals victory.
    - `playBaitTrigger()`: Continuous 0.9s with intensity ramping from 0.1 to 1.0 — signals escalation start.
    - `playGameOver()`: Continuous 1.2s with intensity ramping down from 1.0 to 0.0 — conveys failure.
    - `updateRoachProximity(closestDistance:)`: Called every frame. Starts, stops, or modulates the continuous proximity haptic (active within 12 meters, full intensity at 2 meters).

### 4. `MotionController.swift`
- **Contents**: Handles player input from the virtual joystick and look-drag controls.
- **Logic**:
  - No longer uses `CMMotionManager` — input is entirely driven by `DualThumbControlView`.
  - `cameraYaw` (Float): Tracks the current camera look direction, modified by `applyLookDelta(screenDX:)`.
  - `applyJoystickInput(dx:dz:)`: Stores normalized (–1…+1) left joystick axes.
  - `tickMovement()`: Called every frame. Translates joystick axes into world-space velocity using `cameraYaw` (correct strafing), then applies it to the player's `PhysicsMotionComponent` with smoothing.
  - `freeze()` / `unfreeze()`: Stops all input and zeroes player velocity. Called on game over or win.
  - Tuning: `lookSensitivity = 0.005`, `moveSensitivity = 18.0`, `maxSpeed = 20.0`.

### 5. `AudioManager.swift`
- **Contents**: Manages all game audio using `AVAudioEngine`.
- **Logic**:
  - Audio graph: per-roach `AVAudioPlayerNode` → `AVAudioEnvironmentNode` (3D spatial) → `mainMixerNode` → output. One-shot SFX → `sfxMixer` → `mainMixerNode`.
  - `startMusic()`: Plays `background_music.wav` on a loop at volume 0.35.
  - `addRoach(_ entity:)` / `removeRoach(_ entity:)`: Registers/deregisters a spatial 3D audio node per roach entity.
  - `updatePositions(listenerPosition:listenerYaw:roachEntities:)`: Called every frame. Updates listener position and the spatial position of every active roach.
  - `playCorrect()`, `playWrong()`, `playGameOverLose()`, `playGameOverWin()`: One-shot SFX for game events.
  - `stopAllRoachAudio()`: Stops all roach audio playback without detaching nodes — they remain registered for clean removal via `removeRoach()`.

---

## Game Folder

### 6. `ArenaBuilder.swift`
- **Contents**: Factory that assembles the 3D world in RealityKit, including `CollisionGroups` definitions.
- **Logic**:
  - `CollisionGroups`: Four groups — `.ball` (1<<0), `.obstacle` (1<<1), `.roach` (1<<2), `.boundary` (1<<3).
  - `arenaSize = 60.0` meters.
  - `obstacleConfigs`: A static array of 20 obstacle positions and sizes, shared across `ArenaBuilder` (for building), `MiniMapView` (for rendering the minimap), and `RoachAISystem` (for potential-field avoidance).
  - `slotModels`: Maps each obstacle index to a USDZ model name and a `solid` flag (oil puddles are triggers, not solid blockers).
  - `preload()`: Loads the floor texture from `floor.jpg` and all obstacle USDZ models into a cache.
  - `buildArena()`: Assembles the floor, four boundary walls, and all obstacles under a root "arena" entity.
  - The floor uses an `UnlitMaterial` with custom UV tiling (15×15 tiles) on a manually built mesh quad.
  - Obstacles: If a USDZ model is available, it is cloned and fitted to `config.size` via `fitModel()`. The collision shape is computed from actual visual bounds to prevent passthrough gaps.

### 7. `FogSphere.swift`
- **Contents**: A layered fog bubble around the player that limits visibility.
- **Logic**:
  - Built from 4 concentric inside-out spheres (scale.x = −1) so their inner faces render.
  - Layers from inside to outside: alpha 0.10, 0.35, 0.70, 1.00 — creating a haze → fog → solid wall gradient.
  - Uses `UnlitMaterial` with alpha baked into the tint color, avoiding RealityKit transparent blending quirks.
  - `follow(player:)`: Called every frame from `tickCamera()` to keep the fog sphere centered on the player.
  - `outerRadius = 28.0` meters, `bandWidth = 10.0` meters.

### 8. `GameState.swift`
- **Contents**: Stores per-session metrics using `@Observable`.
- **Logic**:
  - `gamePhase`: Enum — `.countdown`, `.playing`, `.gameOver`.
  - `elapsedTime`: Computed by a repeating `Timer` (0.1s interval) using `Date().timeIntervalSince(startDate)`.
  - `baitTriggeredCount`: Number of bait bags triggered — read by `EscalationSystem` and `VignetteView`.
  - `bagsRemaining`: Starts at 5, decremented each time a bag is triggered.
  - `isWin`: Set to `true` by `triggerWin()`.
  - `playerPosition` and `ballSpeed`: Updated every frame by `tickCamera()` in `GameView`.
  - `scene`: Weak reference to the `RealityKit.Scene` for system access.
  - `reset()`: Resets all metrics to their initial values for a restart.

### 9. `GameView.swift`
- **Contents**: The main view integrating RealityKit, the HUD, controls, and the game loop.
- **Logic**:
  - **Preloading**: `preloadThenStart()` loads all assets (`ArenaBuilder.preload()`, `MysteryBagEntity.preload()`, `RoachEntity.preload()`) before the scene renders, shown behind a loading overlay.
  - **Countdown**: A "3 / 2 / 1" overlay before gameplay begins.
  - **RealityView**: Creates a `physicsRoot` entity with `PhysicsSimulationComponent` (gravity −9.8), then adds the arena, player, fog sphere, camera, and lights.
  - **First-person camera**: A `PerspectiveCamera` (FOV 75°) placed at the player's eye level (`PlayerEntity.eyeHeight`). Orientation is `simd_quatf(angle: cameraYaw, axis: Y)`, updated every frame in `tickCamera()`.
  - **tickCamera()**: The per-frame loop — calls `motionController.tickMovement()`, updates camera position, copies state to `GameState`, updates spatial audio, proximity haptics, and the fog sphere.
  - **HUD throttling**: `hudCameraYaw` is only updated when the yaw delta exceeds 0.04 radians, limiting SwiftUI layout passes to ~20 fps.
  - **Roach spawning**: 2 chasers at game start, then 1 new chaser every 2 seconds via a repeating `Timer`.
  - **Game over overlay**: Shows result (WIN / LOSE), time survived, bags opened, and a MENU button.
  - **Lights**: 1 white fill light (600 lux), 1 directional (dark brown, 2000 lux), 1 red point light (5000 lux, left side), 1 green point light (3000 lux, right side).
  - **cleanup()**: Cancels all subscriptions, systems, and timers; stops audio.

### 10. `MysteryBagEntity.swift`
- **Contents**: Factory for mystery bag entities and their spawn logic.
- **Logic**:
  - `BagType`: Enum — `.baygon` (win) and `.bait` (escalation).
  - `MysteryBagComponent`: ECS component storing `bagType` and `hasTriggered`.
  - `preload()`: Loads three USDZ models — `black_plastic` (initial look), `byegone` (win reveal), `food_pile` (bait reveal).
  - `create(at:type:)`: Builds a bag entity with a visual child (model or dark fallback box), a trigger collision sphere (radius 1.4 m), and a `MysteryBagComponent`. No physics body — trigger only.
  - `createRevealEntity(for:)`: Returns a clone of the appropriate reveal model, fitted to the bag's dimensions.
  - `spawnAll(in:)`: Places 5 bags (1 baygon + 4 bait, shuffled) with placement rules: minimum 15 m between bags, minimum 20 m from the player's start position, no overlap with obstacles.

### 11. `PlayerEntity.swift`
- **Contents**: Factory for the player entity (the small human character).
- **Logic**:
  - Uses a `ModelEntity` with `PhysicsBodyComponent(.dynamic)`.
  - Collision shape: a capsule (halfHeight 0.2 m, radius 0.1 m) — total standing height ~1.2 m.
  - `eyeHeight = standingHeight × 0.85 ≈ 1.02 m`: camera position relative to the floor.
  - Physics: `linearDamping = 4.0`, `angularDamping = 100.0` (prevents the capsule from tipping over), `restitution = 0.0` (no bouncing).
  - A child entity named "playerEye" is positioned at `eyeHeight − totalHalfExtent` — the camera anchor.
  - Collision filter: group `.ball`, mask `.obstacle | .roach | .boundary`.

### 12. `RoachComponent.swift`
- **Contents**: ECS component storing roach behavior data.
- **Logic**:
  - `RoachType`: Enum — `.chaser`, `.giant`, `.flying`.
  - `speed`: Movement speed in m/s.
  - `crushThreshold`: Legacy field from Phase 1 — unused in Phase 2+ (no crush mechanic exists).
  - Factory presets: `chaser()` speed 4.0, `giant()` speed 2.0, `flying()` speed 6.0.

### 13. `RoachEntity.swift`
- **Contents**: Factory for all three roach types.
- **Logic**:
  - `preload()`: Loads USDZ models `roach_1`, `roach_2`, `roach_3` into a cache. Each model is given a corrective scale and `facingYaw` rotation.
  - `createChaser(at:)`, `createGiant(at:)`, `createFlying(at:)`: Builds a container `ModelEntity` with a model child (or colored fallback mesh), `PhysicsBodyComponent(.kinematic)`, a trigger capsule `CollisionComponent`, `PhysicsMotionComponent`, and the appropriate `RoachComponent`.
  - Flying roaches spawn at `flyingHoverHeight = 2.5` meters above the floor.
  - Collision: mode `.trigger`, group `.roach`, mask `.ball` — detects contact without physics reaction.
  - `randomEdgePosition()`: Returns a random position along one of the four arena edges.

---

## HUD Folder

### 14. `HUDView.swift`
- **Contents**: ZStack container for all in-game HUD elements.
- **Logic**:
  - **Top-left**: `MiniMapView` stacked above `BagsRemainingView`.
  - **Top-right**: Timer (`gameState.formattedTime`) in `MM:SS.ms` format.
  - **Center**: `TriggerLabelView` — briefly appears after a bag collision.
  - Receives `cameraYaw: Float` from `GameView` (~20 fps updates) and passes it to `MiniMapView` for the radar cone.

### 15. `BagsRemainingView.swift`
- **Contents**: Five dot indicators that disappear as bags are triggered.
- **Logic**:
  - Renders 5 `Circle` shapes: bright white if index < `bagsRemaining`, dim white (opacity 0.15) if consumed.
  - Changes animate with `.easeOut(duration: 0.2)`.
  - Shows only quantity remaining — no position or content hints.

### 16. `MiniMapView.swift`
- **Contents**: Top-down 2D minimap rendered with SwiftUI `Canvas`.
- **Logic**:
  - Shows: arena border, obstacles (dark grey rectangles), player position (white dot), a direction tick, and a **radar FOV cone**.
  - Intentionally does **not** show mystery bag positions or roach positions.
  - **Radar cone**: A 75° pie-slice in the direction of `cameraYaw`. Maximum range = 18 meters.
  - Widget size: 90×90 pt. Scale: 1 map point = `arenaSize / 90` meters.
  - Obstacles are drawn from `ArenaBuilder.obstacleConfigs` (shared static data).

### 17. `TriggerLabelView.swift`
- **Contents**: Brief center-screen label shown after a bag collision.
- **Logic**:
  - Displays an item image (`byegone_image.png` or `food_pile_image.png`) and a text message.
  - Accent color: green for win, red for bait.
  - Visibility controlled by `BagTriggerLabelState.isVisible` — auto-hides after 1.8 seconds.

### 18. `VignetteView.swift`
- **Contents**: Progressive green gas overlay that grows denser as bait bags are triggered.
- **Logic**:
  - Four `LinearGradient` layers (top, bottom, left, right) form a vignette from each screen edge.
  - Opacity and reach increase per bait level — opacity steps [0.30, 0.55, 0.75, 0.90], reach steps [0.12, 0.25, 0.40, 0.55].
  - No vignette at `baitCount == 0`.
  - Transitions animate with `.easeInOut(duration: 0.8)`.

### 19. `DualThumbControlView.swift`
- **Contents**: Full-screen two-thumb overlay — left joystick + right look-drag.
- **Logic**:
  - **Left zone** (`DragGesture`): A floating joystick appears at the first touch point. The knob is clamped within a 58 pt radius. Output: normalized axes (–1…+1) with a 0.06 dead zone → `onMovement(dx:dz:)`.
  - **Right zone** (`DragGesture`): Tracks horizontal delta only (vertical ignored — the arena is flat, vertical look causes motion sickness). Output: screen-X delta per frame → `onLook(screenDX:)`.
  - Idle hints: a faint ring in the bottom-left corner (joystick), a minimal crosshair in the right zone (look).

---

## Systems Folder

### 20. `BagTriggerSystem.swift`
- **Contents**: Handles player–bag collisions and executes their effects.
- **Logic**:
  - Subscribes to `CollisionEvents.Began`. Checks: player involved + other entity is a bag + not yet triggered.
  - `hasTriggered` is set immediately to prevent double-triggering.
  - `executeTrigger(for:bagEntity:)`:
    - Swaps the visual: removes the bag's child entities, adds the reveal entity (byegone or food_pile).
    - `.baygon`: Shows "BYEGONE" label, plays win haptic and audio, freezes player and roaches, then after 1.2 seconds calls `gameState.triggerWin()`.
    - `.bait`: Increments `baitTriggeredCount`, shows "FOOD PILE" label, plays bait haptic and audio, removes the bag entity after 1.5 seconds.
  - `BagTriggerLabelState`: An `@Observable` class with `show(message:isWin:)` that auto-hides after 1.8 seconds.
  - `freezePlayer`: A closure that freezes the `MotionController` and all roaches via `RoachAISystem.isGameOver = true`.

### 21. `ContactSystem.swift`
- **Contents**: Handles collisions between the player and roaches or walls.
- **Logic**:
  - Subscribes to `CollisionEvents.Began`.
  - If the player touches a roach (entity has `RoachComponent`): calls `gameState.triggerGameOver()`, plays game-over haptic and audio, freezes player and all roaches. **No crush mechanic** — any contact is instant death.
  - If the player touches an obstacle or wall: plays `playObstacleHit()` only.

### 22. `EscalationSystem.swift`
- **Contents**: Responds to each new bait trigger by spawning roaches and applying speed bumps.
- **Logic**:
  - Polls `gameState.baitTriggeredCount` every 0.2 seconds via a `Timer`.
  - Per new bait level:
    - Bait 1: +3 Giants.
    - Bait 2: +2 Giants, +3 Flying.
    - Bait 3: +1 Giant, +4 Flying, speed bump all active roaches.
    - Bait 4+: +5 Flying, speed bump all active roaches.
  - `bumpAllSpeeds(in:)`: Multiplies the `speed` of every active roach by `1.0 + 0.15`.

### 23. `PuddleSystem.swift`
- **Contents**: Increases the player's `linearDamping` while inside an oil puddle trigger area.
- **Logic**:
  - Subscribes to `CollisionEvents.Began` and `CollisionEvents.Ended`.
  - On entering a puddle (entity name starts with "puddle"): sets `linearDamping = 30.0` (sluggish, like pushing through oil).
  - On exit: restores `linearDamping = 4.0` (normal).

### 24. `RoachAISystem.swift`
- **Contents**: ECS System that steers all roaches toward the player every frame.
- **Logic**:
  - Queries all entities with `RoachComponent`, runs on the `.rendering` loop.
  - `isGameOver`: Static flag that instantly halts all AI when the game ends.
  - Per roach, computes four steering components:
    1. **Chase**: Unit direction toward the player (XZ only) × `roachComp.speed`.
    2. **Separation**: Pushes away from nearby roaches that are too close (radius and strength vary by roach type).
    3. **Obstacle repulsion** (Chasers and Giants only — Flying skips this): Potential field from all solid obstacles. The closer the roach to an obstacle surface, the stronger the repulsion force.
    4. **Wall repulsion**: Potential field from all four arena boundary walls.
  - The final steering vector is normalized and re-scaled to `roachComp.speed` so avoidance doesn't change overall movement speed.
  - Flying roaches: wall repulsion only (they hover over floor obstacles). A Y-velocity component handles hover/dive-bombing — they begin diving at 12 meters from the player, reaching player height at 3 meters.
  - Each roach rotates to face its movement direction using `simd_quatf(angle:axis:)`.
  - The obstacle cache is built once from `ArenaBuilder.obstacleConfigs`, skipping oil puddles (height ≤ 0.15).

---

## UI Folder

### 25. `MainMenuView.swift`
- **Contents**: Dark-themed home screen.
- **Logic**:
  - Background: A dark `LinearGradient` (near-black with subtle blue and brown tones).
  - Title "SKITTER" + subtitle "SURVIVE THE SWARM".
  - **Best Run widget**: Only visible when `appState.bestWinTime > 0`. Displays the fastest win time and how many bags were opened during that run.
  - PLAY button: Calls `appState.startGame()`, navigating to `GameView`.
  - No control mode selector — dual-thumb joystick is the only input mode.

---

## Project Structure

```
Skitter/
├── App/
│   ├── SkitterApp.swift          // SwiftUI App entry + ContentView router
│   └── AppState.swift            // @Observable global state (screen, best scores)
│
├── Game/
│   ├── GameView.swift            // RealityView + HUD ZStack + full game loop
│   ├── GameState.swift           // @Observable — timer, bait count, bags remaining, isWin
│   ├── FogSphere.swift           // Layered inside-out sphere fog around the player
│   ├── ArenaBuilder.swift        // Arena factory + CollisionGroups + obstacle configs
│   ├── PlayerEntity.swift        // Dynamic capsule ModelEntity + eye-level anchor child
│   ├── MysteryBagEntity.swift    // Black bag entity — BagType enum + reveal model swap
│   ├── RoachComponent.swift      // ECS component — RoachType, speed, crushThreshold
│   └── RoachEntity.swift         // Chaser / Giant / Flying factory + USDZ template cache
│
├── Systems/
│   ├── RoachAISystem.swift       // ECS System — chase + separation + potential-field avoidance
│   ├── ContactSystem.swift       // Player–roach collision → instant game over
│   ├── BagTriggerSystem.swift    // Player–bag collision → reveal visual + win or escalation
│   ├── EscalationSystem.swift    // Poll baitCount → spawn waves + speed bump per bait level
│   └── PuddleSystem.swift        // Puddle collision → modify player linearDamping
│
├── Controllers/
│   ├── MotionController.swift    // Joystick + look-drag input → player velocity + cameraYaw
│   ├── HapticManager.swift       // CHHapticEngine — obstacle, win, bait, game over, proximity
│   └── AudioManager.swift        // AVAudioEngine — BGM, spatial roach audio, one-shot SFX
│
├── HUD/
│   ├── HUDView.swift             // ZStack container — minimap, timer, trigger label
│   ├── MiniMapView.swift         // Canvas top-down — arena + obstacles + player + radar cone
│   ├── DualThumbControlView.swift // Full-screen: left joystick + right look-drag
│   ├── VignetteView.swift        // Progressive green gas overlay based on baitCount
│   ├── TriggerLabelView.swift    // "BYEGONE" / "FOOD PILE" label after bag collision
│   └── BagsRemainingView.swift   // 5-dot indicator of remaining bags
│
└── UI/
    └── MainMenuView.swift        // Home screen — title, best run display, PLAY button
```

---

## Assets

### Models (USDZ)
| File | Used For |
|---|---|
| `black_plastic.usdz` | Mystery bag — initial appearance (all identical) |
| `byegone.usdz` | Reveal model when bag contains baygon (WIN) |
| `food_pile.usdz` | Reveal model when bag contains rotten food (bait) |
| `roach_1.usdz` | Chaser roach |
| `roach_1_animated.usdz` | Chaser roach — animated variant (prepared for Phase 3) |
| `roach_2.usdz` | Giant roach |
| `roach_2_animated.usdz` | Giant roach — animated variant (prepared for Phase 3) |
| `roach_3.usdz` | Flying roach |
| `trash_pile.usdz` | Obstacle — trash heap |
| `trash_barrel.usdz` | Obstacle — trash barrel |
| `oil_drum.usdz` | Obstacle — oil drum |
| `oil_puddle.usdz` | Trigger area — oil puddle (not a solid blocker) |
| `fence.usdz` | Obstacle — wire fence |

### Sounds (WAV)
| File | Used For |
|---|---|
| `background_music.wav` | Looping background music |
| `skittering_sound.wav` | Roach skitter loop (played spatially per roach) |
| `correct.wav` | SFX when baygon is found |
| `wrong.wav` | SFX when a bait bag is triggered |
| `gameover_lose.wav` | SFX on loss |
| `gameover_win.wav` | SFX on win |

### Textures / Images
| File | Used For |
|---|---|
| `floor.jpg` | Arena floor texture (tiled 15×15) |
| `byegone_image.png` | Image in `TriggerLabelView` on WIN |
| `food_pile_image.png` | Image in `TriggerLabelView` on bait trigger |

---

## Tech Stack

| Layer | Framework |
|---|---|
| **3D Rendering** | RealityKit 4 — `RealityView`, `ModelEntity`, `PhysicsBodyComponent`, ECS Systems |
| **UI + HUD** | SwiftUI — `RealityView` + ZStack overlay, `Canvas` for minimap |
| **Input** | SwiftUI `DragGesture` — dual-thumb virtual controls |
| **Haptics** | CoreHaptics — `CHHapticEngine`, `CHHapticAdvancedPatternPlayer` |
| **Spatial Audio** | AVFoundation — `AVAudioEngine`, `AVAudioEnvironmentNode` |

**Target**: iOS 18.0+, iPhone-only, landscape.

---

## Development Status

### Phase 1 — MVP
Ball entity, gyroscope input, chaser roach, crush mechanic, isometric camera, basic HUD, CoreHaptics.

### Phase 2 — New Core
- `PlayerEntity` capsule, first-person camera, dual-thumb joystick controls
- Mystery bag system (5 identical black bags: 1 baygon + 4 bait)
- `BagTriggerSystem`, `ContactSystem` (instant death), `EscalationSystem`
- `MiniMapView` with radar cone, `BagsRemainingView`, `VignetteView`
- `FogSphere`, `PuddleSystem`
- `AudioManager` — spatial roach audio, BGM, one-shot SFX
- `HapticManager` — proximity, bait trigger, baygon win, game over
- `AppState` persisting best win time and bags opened

### Phase 3 — Full Horror
Giant and Flying roach full visuals, per-bait tier upgrades on existing roaches, audio polish

---

*Last updated: March 2026*