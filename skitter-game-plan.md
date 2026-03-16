# Skitter — iOS Game Planning Document

> Kamu di dalam bola plastik transparan. Kecoa mengejar dari semua arah.  
> Tilt HP untuk rolling. Bertahan selama mungkin.

---

## Ringkasan Konsep

| Atribut | Detail |
|---|---|
| **Nama** | Skitter |
| **Platform** | iOS (iPhone-first, landscape) |
| **Genre** | Survival arcade |
| **Perspektif** | Isometric 3D |
| **Kontrol** | Gyroscope (tilt) |
| **Arena** | Landfill malam hari — terbuka, obstacles berserakan |
| **Tujuan** | Bertahan selama mungkin, gilas kecoa, gunakan skill |
| **Target iOS** | iOS 18.0+ |
| **Language** | Swift 5.9+ |

---

## iOS Frameworks

### Rendering — RealityKit 4
`developer.apple.com/documentation/realitykit`

RealityKit 4 (iOS 18+) adalah pilihan rendering untuk Skitter. SceneKit resmi deprecated di WWDC 2025 — Apple merekomendasikan semua proyek baru pakai RealityKit. RealityKit menggunakan arsitektur **Entity Component System (ECS)**: behavior dibungkus dalam `Component` yang di-attach ke `Entity`, bukan lewat subclassing. Rendering masuk ke SwiftUI view `RealityView` langsung — tidak perlu `UIViewController` wrapper.

| Komponen RealityKit | Digunakan untuk |
|---|---|
| `RealityView` | SwiftUI view utama — host seluruh dunia 3D game |
| `Entity` | Setiap objek di dunia: bola, kecoa, blok, ramp |
| `ModelEntity` | Entity dengan mesh + material — bola, obstacle, kecoa |
| `ModelComponent` | Attach mesh (`MeshResource`) + material ke entity |
| `PhysicsBodyComponent` | Physics body untuk bola dan obstacles — mode `.dynamic` / `.static` |
| `PhysicsMotionComponent` | Set velocity langsung ke physics body bola dari gyro input |
| `CollisionComponent` | Collision shape — sphere untuk bola & kecoa, box untuk obstacles |
| `PointLightComponent` | Scattered point lights merah/hijau untuk mood landfill |
| `ParticleEmitterComponent` | Gas hijau, crush splat, speed trail bola |
| `PhysicsSimulationComponent` | Gravity = 0 (arena datar), physics world settings |
| `AnimationComponent` / `AnimationLibraryComponent` | Death animation kecoa, animasi sayap kecoa terbang |
| `ShaderGraphMaterial` | Material transparan bola via Reality Composer Pro, tekstur lantai kotor |
| `PostProcessEffect` (custom) | Vignette gas hijau + bloom lewat Metal Performance Shaders |

**ECS custom systems untuk game logic:**

RealityKit memiliki `System` protocol — logic game (AI kecoa, wave manager, skill) diimplementasi sebagai `System` yang di-tick setiap frame, bukan di-subclass entity.

```swift
// Contoh: RoachAISystem — dijalankan tiap frame oleh RealityKit
struct RoachAISystem: System {
    static let query = EntityQuery(where: .has(RoachComponent.self))

    func update(context: SceneUpdateContext) {
        let ball = context.scene.findEntity(named: "ball")!
        context.entities(matching: Self.query, updatingSystemWhen: .rendering).forEach { roach in
            var roachComp = roach.components[RoachComponent.self]!
            let dir = ball.position(relativeTo: nil) - roach.position(relativeTo: nil)
            let speed = roachComp.speed
            roach.components[PhysicsMotionComponent.self]?.linearVelocity =
                normalize(dir) * speed
        }
    }
}
```

**Assets:** Model 3D dibuat dalam format `.usdz` dan dikompilasi via **Reality Composer Pro** (tool gratis dari Apple, bundled dengan Xcode). Reality Composer Pro mendukung MaterialX shaders, animasi skeletal, dan particle emitter langsung di dalam `.usdz`.

**Kamera isometric:** RealityKit tidak punya built-in "camera entity" yang bisa diposisikan bebas seperti SceneKit. Kamera di-kontrol lewat `RealityView` `cameraMode` — untuk Skitter gunakan `.custom` dengan `PerspectiveCamera` entity yang di-posisikan di atas-belakang arena dengan fixed pitch ~45°, mengikuti bola via `update:` closure di RealityView.

**HUD overlay:** SwiftUI `ZStack` — `RealityView` di bawah, `Canvas` / SwiftUI views di atas sebagai HUD (timer, wave, skill bar, threat indicator). Lebih clean dari SpriteKit overlay karena sudah satu ekosistem SwiftUI.

---

### Motion / Gyroscope — CoreMotion
`developer.apple.com/documentation/coremotion`

| Class / API | Digunakan untuk |
|---|---|
| `CMMotionManager` | Entry point untuk semua motion data |
| `CMDeviceMotion` | Fused data dari accelerometer + gyro + magnetometer — lebih stabil dari raw gyro |
| `attitude.pitch` | Tilt maju/mundur → dorong bola ke depan/belakang di arena |
| `attitude.roll` | Tilt kiri/kanan → dorong bola ke kiri/kanan |
| `startDeviceMotionUpdates(to:withHandler:)` | Polling 60 Hz ke main queue |
| `CMAttitudeReferenceFrame` | `.xArbitraryZVertical` — zero point saat game mulai, relatif terhadap posisi HP saat itu |

**Implementasi rolling:**

```swift
// Setup di GameScene
motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
    guard let motion = motion else { return }
    let pitch = motion.attitude.pitch  // -π/2 ... π/2
    let roll  = motion.attitude.roll   // -π/2 ... π/2
    self?.applyForce(pitch: pitch, roll: roll)
}

// Apply ke PhysicsMotionComponent bola
func applyForce(pitch: Double, roll: Double) {
    let sensitivity: Float = 12.0
    let fx = Float(sin(roll))  * sensitivity
    let fz = Float(sin(pitch)) * sensitivity
    ball.components[PhysicsMotionComponent.self]?.linearVelocity += SIMD3<Float>(fx, 0, fz)
}
```

**Kalibrasi:** Saat game start, simpan attitude baseline. Semua input relatif dari baseline itu sehingga player bebas pegang HP di sudut nyaman.

---

### Haptic Feedback — CoreHaptics
`developer.apple.com/documentation/corehaptics`

| Class / API | Digunakan untuk |
|---|---|
| `CHHapticEngine` | Engine utama — satu instance, dikelola sepanjang lifecycle game |
| `CHHapticEvent` | Satu haptic event (transient atau continuous) |
| `CHHapticEventParameter` | `.hapticIntensity`, `.hapticSharpness` — kontrol feel tiap event |
| `CHHapticDynamicParameter` | Update intensity/sharpness real-time (proximity kecoa) |
| `CHHapticPatternPlayer` | Player untuk pattern yang bisa di-modulate saat berjalan |
| `CHHapticEngine.capabilitiesForHardware()` | Check apakah device support haptics sebelum init |

**Pola haptic per situasi:**

| Situasi | Type | Intensity | Sharpness | Duration |
|---|---|---|---|---|
| Rolling normal | `.hapticContinuous` | 0.05–0.15 | 0.3 | Loop |
| Nabrak obstacle | `.hapticTransient` | 0.8 | 0.9 | — |
| Kecoa mendekat (normal) | `.hapticContinuous` | 0.1→0.6 (scale jarak) | 0.4 | Loop, modulated |
| Kecoa mendekat (giant) | `.hapticContinuous` | 0.2→0.9 | 0.2 (dull thud) | Loop |
| Kecoa mendekat (terbang) | `.hapticContinuous` | 0.15→0.7 | 0.8 (sharp buzz) | Loop |
| Crush kecoa normal | `.hapticTransient` x2 + continuous | 1.0 → 0.3 | 0.9 → 0.2 | 0.4s |
| Crush kecoa giant | `.hapticContinuous` | 1.0 | 0.1 (heavy) | 0.6s |
| Skill activated | `.hapticTransient` x3 | 0.7 | 0.8 | rapid sequence |
| Wave baru | `.hapticTransient` | 0.5 | 0.5 | — |
| Game over | `.hapticContinuous` ramp down | 1.0→0 | 0.3 | 1.2s |

**Directional proximity:** Karena iOS tidak support directional haptics (vibration yang terasa dari sisi tertentu), directional cue diberikan lewat kombinasi haptic pattern + visual indicator di sudut layar. Intensity haptic scale berdasarkan jarak kecoa terdekat.

---

### Audio — AVFoundation + AVAudioEngine
`developer.apple.com/documentation/avfaudio`

| API | Digunakan untuk |
|---|---|
| `AVAudioEngine` | Graph audio utama game |
| `AVAudioPlayerNode` | Per-roach audio source (skitter sound tiap kecoa) |
| `AVAudioEnvironmentNode` | 3D spatial audio — suara kecoa datang dari arahnya di dunia |
| `AVAudioMixerNode` | Mix semua source ke output |
| `AVAudioUnitReverb` | Reverb malam + landfill ambiance |
| `AVAudioSession` | Category `.ambient` agar tidak interrupt musik user |

**Spatial skitter sound:**
Setiap kecoa memiliki `AVAudioPlayerNode` sendiri yang terhubung ke `AVAudioEnvironmentNode`. Position node di-update setiap frame berdasarkan posisi kecoa di dunia → suara secara alami datang dari arah kecoa. Volume node di-scale berdasarkan jarak ke bola.

```swift
// Update posisi audio kecoa setiap frame
func updateRoachAudio(_ roach: RoachNode) {
    roach.audioPlayerNode.position = AVAudio3DPoint(
        x: Float(roach.position.x),
        y: Float(roach.position.y),
        z: Float(roach.position.z)
    )
    // Volume berdasarkan jarak
    let dist = roach.position.distance(to: ball.position)
    roach.audioPlayerNode.volume = max(0, 1.0 - Float(dist) / 400.0)
}
```

---

### UI — SwiftUI
`developer.apple.com/documentation/swiftui`

SwiftUI digunakan untuk semua layar game, termasuk HUD in-game. Karena `RealityView` adalah SwiftUI view, seluruh stack UI cukup satu ekosistem — tidak perlu SpriteKit overlay seperti di SceneKit.

**Layar non-game:**
- **Main menu** — title Skitter, Play, Settings
- **Game over screen** — stats, replay prompt
- **Settings** — sensitivity gyro, volume, toggle haptics

**HUD in-game:** SwiftUI `ZStack` — `RealityView` di layer bawah, overlay SwiftUI views di atas: timer (`Text`), wave badge, skill slots (`HStack`), threat indicator (`Canvas`), crush meter (`ProgressView` custom). Skill pick muncul sebagai overlay di atas game screen — bukan halaman terpisah. Semua di-update via `@Observable` game state — SwiftUI auto-refresh saat state berubah.

---

## Halaman (3 Layar)

Skitter memiliki 3 halaman utama. Skill pick bukan halaman terpisah — ia muncul sebagai overlay ringan di atas game screen agar momentum tidak terputus.

---

### Halaman 1 — Main Menu

**Tone:** Gelap, sparse, sedikit mencekam. Tidak ada animasi berlebihan — cukup subtle pulse pada logo.

**Elemen:**

| Elemen | Detail |
|---|---|
| **Logo** | Ikon bola transparan kecil + teks "SKITTER" spasi lebar. Subtitle "SURVIVE THE SWARM" di bawahnya, muted |
| **Best score** | Satu angka waktu terbaik player, ditampilkan singkat di bawah logo. Kosong jika belum pernah main |
| **Tombol Play** | Full-width, prominent, warna aksen hijau kotor. Satu-satunya CTA utama |
| **Tombol Leaderboard** | Half-width, muted. Buka Game Center leaderboard |
| **Tombol Settings** | Half-width, muted. Buka settings overlay (sensitivity gyro, volume, haptics on/off) |

**Tidak ada:** Tutorial di main menu. Onboarding hanya muncul sekali saat first launch, sebelum game pertama dimulai.

---

### Halaman 2 — Game Screen

Portrait tidak didukung — game berjalan landscape saja. Seluruh layar adalah arena RealityKit. HUD duduk di atas arena sebagai SwiftUI overlay transparan.

**HUD layout:**

```
┌─────────────────────────────────────────────────────────┐
│ [CRUSHED 003]        [01:24 · WAVE 2]      [NEXT: ▓▒░ 18s] │  ← top bar
│                                                         │
│                   (arena 3D isometric)                  │
│                                                         │
│ [CRUSH SPEED ▓▓▒░░]     [S][C][·]          [↗ THREAT]  │  ← bottom bar
└─────────────────────────────────────────────────────────┘
```

| Elemen HUD | Posisi | Isi |
|---|---|---|
| **Crushed counter** | Kiri atas | Jumlah kecoa digilas sesi ini. Warna merah |
| **Timer + wave badge** | Tengah atas | Format `MM:SS`. Badge wave di bawahnya, warna berubah per wave (biru→oranye→pink→merah) |
| **Next wave bar** | Kanan atas | Progress bar + countdown detik. Warna sesuai wave berikutnya |
| **Crush speed meter** | Kiri bawah | Bar horizontal. Merah jika belum cukup cepat, hijau jika crush-ready |
| **Skill slots** | Kanan bawah tengah | 3 slot. Slot aktif: ikon + cooldown arc. Slot kosong: tanda `+` muted |
| **Threat indicator** | Pojok kanan bawah | Lingkaran kecil dengan panah — menunjuk ke kecoa terdekat. Makin merah makin dekat |

**Skill Pick Overlay** — muncul di atas game screen saat wave baru dimulai, bukan halaman terpisah:

- Seluruh arena di-dim sedikit (background tetap kelihatan, tidak full-black)
- Dua kartu skill ditampilkan di tengah layar secara landscape
- Kartu kiri dan kanan bisa di-tap untuk memilih
- Timer 5 detik — jika tidak dipilih, wave mulai tanpa skill baru (auto-skip)
- Teks kecil "WAVE X" di atas dua kartu sebagai konteks

---

### Halaman 3 — Game Over

Muncul saat bola tertangkap kecoa. Transisi: arena fade ke gelap, stats muncul dari bawah.

**Elemen:**

| Elemen | Detail |
|---|---|
| **Header** | Teks "GAME OVER" merah, kecil, letter-spacing lebar — bukan besar-besar |
| **4 stat cards** | Grid 2×2: Survived (waktu), Crushed (jumlah), Top Wave, Best (rekor terbaik all-time) |
| **Global rank** | Satu baris kecil "#XX GLOBAL" dari Game Center. Muncul setelah fetch, skeleton jika loading |
| **Tombol Play Again** | Full-width, prominent. Langsung restart dengan arena seed baru |
| **Tombol Menu** | Half-width, muted. Kembali ke main menu |

**Tidak ada:** replay video, share button, rating prompt di game over. Jaga layar tetap bersih dan cepat — player maunya langsung retry.

---

## Dunia Game: Landfill Malam Hari

### Visual Theme

| Elemen | Detail |
|---|---|
| **Lantai** | Tile kotor coklat-hijau, textur tanah basah dan sampah, sesekali reflektif (oli) |
| **Lighting** | Ambient sangat gelap (#080810). Scattered point lights: merah dari tumpukan sampah membara, hijau dari gas bocor |
| **Bola** | Transparan double-sided, reflektif, sedikit tinted kuning-kotor dari lingkungan |
| **Kecoa** | Low-poly tapi berdetail: antena, cakar. Normal = coklat, Giant = hitam mengkilap, Terbang = coklat-merah dengan sayap translucent |
| **Obstacles** | Tong sampah berkarat, tumpukan sampah padat, puddle oli hitam, pagar kawat jaring |
| **Background/sky** | Hitam pekat, kabut hijau di horizon, bulan tipis tersembunyi awan |
| **Particles** | Gas hijau mengepul dari lantai secara periodik, debu saat bola rolling cepat |

### Layout Arena

Arena berbentuk persegi panjang luas (~1100x1100 unit dunia). Obstacle layout semi-random dengan seed per session:
- 8–12 **blok solid** (tumpukan sampah, tong besar) — tidak bisa dilewati
- 4 **ramp** — kecoa melambat 65% saat naik ramp
- 2–3 **puddle oli** — bola sangat licin (friction ~0), kecoa slip juga
- 2 **kawat jaring** — passable, bola dan kecoa melambat 40%
- 2 **gas vent** — semburan periodik tiap ~8 detik, push semua objek di radius 80u

---

## Tipe Kecoa

### 1. Kecoa Normal (Chaser)
Muncul sejak Wave 1. Langsung mengejar posisi bola saat ini. Predictable, bisa digilas dengan momentum sedang.

| Stat | Value |
|---|---|
| Speed | 195 u/s |
| HP | 1 hit |
| Crush threshold | 300 u/s (ball speed) |
| Ukuran | Kecil (radius 15u) |

### 2. Kecoa Giant
Muncul mulai Wave 2. Bergerak lambat tapi besar dan sulit dihindari di area sempit. Membutuhkan momentum penuh untuk digilas. Jika gagal crush, bola terpental keras (knockback besar).

| Stat | Value |
|---|---|
| Speed | 110 u/s |
| HP | 1 hit (tapi crush threshold tinggi) |
| Crush threshold | 900 u/s — butuh run-up panjang |
| Knockback ke bola saat gagal crush | Sangat kuat (velocity reversal 60%) |
| Ukuran | Besar (radius 38u) |
| Visual | Hitam mengkilap, slow heavy movement, suara dragging |

**Behavior:** Bergerak lurus ke arah bola. Tidak bisa diblok skill Repulse biasa — butuh Shockwave atau lari menghindari.

### 3. Kecoa Terbang
Muncul mulai Wave 3. Hover di atas lantai — tidak terpengaruh puddle oli, tidak terlambat di kawat jaring, tidak melambat di ramp. Path-nya langsung tanpa hambatan apapun. Harus dihancurkan dari arah atas (bola harus datang dari sisi yang lebih tinggi di isometric view, atau rolling sangat cepat).

| Stat | Value |
|---|---|
| Speed | 230 u/s (lebih cepat dari normal) |
| HP | 1 hit |
| Crush threshold | 450 u/s |
| Ukuran | Sedang (radius 18u), hover 20u di atas lantai |
| Visual | Sayap bergetar, shadow di lantai di bawahnya, buzz sound |
| Kelemahan | Tidak bisa enter kawat jaring area, sayap bisa distun sebentar oleh gas vent |

**Behavior:** Path bersih tanpa obstacle apapun. Paling mengancam karena tidak bisa digunakan trik ramp/puddle.

---

## Sistem Skill

Skill dibuka dengan **skill point** yang didapat setiap wave baru. Setiap wave player memilih 1 dari 2 skill yang ditawarkan secara random. Maximum 3 skill slot aktif sekaligus (slot ke-4 menggantikan skill paling lama jika sudah 3).

### Skill yang Tersedia

#### ⚡ Slam (Aktif, Cooldown 8s)
Tahan tombol → charge indicator muncul di layar → lepas → burst kecepatan sangat tinggi ke arah tilt saat ini selama 0.8 detik. Satu kali burst ini cukup untuk gilas Giant sekalipun.

Berguna: Keluar dari situasi terkepung, one-shot Giant, escape dari Swarm.

#### 🔗 Chain Crush (Pasif)
Setelah crush kecoa pertama, dalam 1.5 detik berikutnya bola tidak kehilangan momentum saat crush kecoa lagi. Bisa combo crush 3–4 kecoa berturut-turut tanpa perlu build speed ulang.

Berguna: Saat Swarm muncul dan ada cluster kecoa berdekatan. Momen paling satisfying di game.

#### 💥 Shockwave (Aktif, Cooldown 12s)
Pulse area kecil (radius ~180u) dari posisi bola. Stun semua kecoa dalam radius selama 1.2 detik. Tidak membunuh, tapi memberi jeda untuk kabur atau build speed.

Berguna: Saat dikepung dari semua arah, atau untuk membeli waktu mengaktifkan Slam.

---

## Vignette Progresif: Gas Hijau Toxic

Gas mulai transparent di detik 0 dan semakin tebal seiring waktu. Diimplementasi sebagai radial gradient SCNParticleSystem + SpriteKit overlay radial vignette.

| Waktu | Vignette | Visibility Radius |
|---|---|---|
| 0–30 detik | Tidak ada | 100% |
| 30–60 detik | Gas mulai muncul di sudut, tipis | ~90% |
| 60–90 detik | Awan hijau gelap di ~30% pinggir layar | ~70% |
| 90–120 detik | Makin pekat, mulai menyembunyikan kecoa di pinggir | ~55% |
| 120 detik+ | Hampir setengah layar tertutup — hanya area tengah yang jelas | ~40% |

Kecoa di luar vignette radius tidak visible tapi tetap bergerak. Tiba-tiba muncul dari kabut = efek horror paling intens.

---

## Obstacles & Traps (Set Terbatas)

| Obstacle | Type | Efek ke Bola | Efek ke Kecoa |
|---|---|---|---|
| **Tumpukan sampah** | Solid blocker | Tidak bisa lewat, bounce | Tidak bisa lewat |
| **Ramp** | Passable | Speed normal, bisa kabur naik | Speed -65% saat naik |
| **Puddle oli** | Passable trap | Friction ~0, sangat licin | Kecoa juga slip, speed -30% |
| **Kawat jaring** | Passable slow | Speed -40% saat dalam area | Speed -40%, Kecoa Terbang tidak masuk |
| **Gas vent** | Hazard periodik | Push kuat jika di atas vent saat blow | Push kecoa juga — bisa dimanfaatkan |

---

## Wave System

| Wave | Waktu | Kecoa yang spawn | Kondisi tambahan |
|---|---|---|---|
| Wave 1 | 0–30s | 2 Chaser | Normal |
| Wave 2 | 30–60s | +2 Giant | 1 ramp tambahan di arena |
| Wave 3 | 60–90s | +1 Flying | Speed semua +15% |
| Wave 4 | 90s+ | Semua tipe, +3 Chaser tiap 15s | Speed +30%, vignette accelerates |

**Skill offer:** Muncul di layar sebelum wave baru dimulai, pause 3 detik untuk pilih skill atau skip.

---

## Arsitektur Kode

```
Skitter/
├── App/
│   ├── SkitterApp.swift          // SwiftUI App entry
│   └── AppState.swift            // @Observable global state (score, settings)
│
├── Game/
│   ├── GameView.swift            // SwiftUI view: RealityView + HUD ZStack
│   ├── GameState.swift           // @Observable — wave, timer, skills, game phase
│   ├── BallEntity.swift          // ModelEntity bola — PhysicsBodyComponent, ShaderGraphMaterial
│   ├── RoachEntity.swift         // Base ModelEntity kecoa — CollisionComponent
│   ├── ChaserRoach.swift         // RoachComponent data untuk Chaser
│   ├── GiantRoach.swift          // RoachComponent data untuk Giant
│   ├── FlyingRoach.swift         // RoachComponent data untuk Flying — hover offset
│   ├── ObstacleEntity.swift      // ModelEntity obstacle — PhysicsBodyComponent static
│   └── ArenaBuilder.swift        // Generate arena dari seed, tambah ke RealityView content
│
├── Systems/                      // RealityKit ECS Systems — dipanggil otomatis tiap frame
│   ├── RoachAISystem.swift       // EntityQuery kecoa → update PhysicsMotionComponent
│   ├── CrushSystem.swift         // Deteksi speed threshold → trigger crush
│   ├── WaveSystem.swift          // Timer wave, spawn logic
│   ├── VignetteSystem.swift      // Update PostProcessEffect intensity per detik
│   └── SkillSystem.swift         // Cooldown tracking, skill activation effects
│
├── Controllers/
│   ├── MotionController.swift    // CMMotionManager wrapper → update ball velocity
│   ├── HapticManager.swift       // CHHapticEngine singleton, semua pola haptic
│   └── AudioManager.swift        // AVAudioEngine, spatial audio per kecoa
│
├── HUD/                          // SwiftUI views overlay di atas RealityView
│   ├── HUDView.swift             // ZStack container semua HUD elements
│   ├── ThreatIndicatorView.swift // Canvas arrow ke kecoa terdekat
│   ├── CrushMeterView.swift      // Speed bar
│   └── SkillBarView.swift        // 3 skill slots + cooldown indicator
│
├── UI/ (SwiftUI — layar non-game)
│   ├── MainMenuView.swift
│   ├── SkillPickView.swift       // Pilih skill antar wave
│   ├── GameOverView.swift
│   └── SettingsView.swift
│
└── Assets/
    ├── Models/                   // .usdz dikompilasi via Reality Composer Pro
    ├── Textures/                 // Lantai, material kecoa, env map (AVIF format)
    ├── Sounds/                   // Skitter loops, crush sfx, ambient
    └── Haptics/                  // .ahap files untuk CoreHaptics patterns
```

---

## Development Phases

---

### Phase 1 — MVP (Target: 4–6 minggu)

**Goal:** Game bisa dimainkan end-to-end di device nyata dengan core loop berfungsi.

**Deliverable:**

- [x] RealityKit scene: `RealityView` + arena datar dengan tile floor, 1 tipe obstacle (blok solid sebagai static `PhysicsBodyComponent`)
- [x] Bola: `ModelEntity` + `PhysicsBodyComponent(.dynamic)` + `CollisionComponent`
- [x] CoreMotion gyro input → `PhysicsMotionComponent.linearVelocity` bola
- [x] 1 tipe kecoa (Chaser): `RoachAISystem` sederhana via ECS query
- [x] Collision detection: bola vs kecoa via `CollisionEvents.Began` → game over
- [x] Crush mechanic: speed threshold check di `CrushSystem`
- [x] Basic HUD (SwiftUI overlay): timer + "game over" text via `@Observable` GameState
- [x] Kamera isometric fixed-angle, mengikuti bola via RealityView `update:` closure
- [x] CoreHaptics: 2 pola saja — nabrak obstacle + crush kecoa
- [x] Game loop: start → play → game over → restart

**Tidak perlu di Phase 1:**
- Skills, vignette, spatial audio, multiple roach types, wave system, theming

---

### Phase 2 — Core Features (Target: 4–5 minggu)

**Goal:** Semua mechanic utama berjalan, game terasa seperti Skitter.

**Deliverable:**

- [ ] **3 tipe kecoa** lengkap: Chaser, Giant, Flying (dengan visual distinct)
- [ ] **Wave system**: spawn logic, timer, escalation Wave 1–4
- [ ] **Skill system**: 3 skill (Slam, Chain Crush, Shockwave), skill offer UI
- [ ] **CoreHaptics lengkap**: semua pola dari tabel haptic, proximity scaling
- [ ] **AVAudioEngine spatial audio**: skitter sound per kecoa, 3D positioned
- [ ] **Obstacles lengkap**: ramp, puddle oli, kawat jaring, gas vent
- [ ] **Vignette gas hijau**: overlay progresif, scale dengan waktu
- [ ] **HUD lengkap**: skill bar, threat indicator, crush meter, wave notif
- [ ] **Landfill visual theme**: lighting, material, tekstur — mood malam hari

---

### Phase 3 — Polish & Feel (Target: 3–4 minggu)

**Goal:** Game terasa juicy, polished, dan enak dimainkan.

**Deliverable:**

- [ ] **Juice bola**: speed trail via `ParticleEmitterComponent`, motion blur via `PostProcessEffect`, spin visual di `ShaderGraphMaterial`
- [ ] **Crush effects**: splat particle, screen flash singkat, screen shake kecil
- [ ] **Kecoa death animation**: squash → fade (Normal), burst (Flying), slow collapse (Giant)
- [ ] **Camera zoom dinamis**: pull back saat speed tinggi, closer saat lambat
- [ ] **Gyro calibration**: auto-kalibrasi saat mulai + manual recalibrate tombol
- [ ] **Audio polish**: reverb landfill, ambient crickets/wind, crush SFX distinct per tipe
- [ ] **Skill visual feedback**: Slam charge indicator, Shockwave pulse visual, Chain Crush glow
- [ ] **Settings screen**: gyro sensitivity, haptic on/off, audio volume
- [ ] **Performance pass**: target 60fps di iPhone 12+, 30fps fallback iPhone X

---

### Phase 4 — Full Release (Target: 3–4 minggu)

**Goal:** App Store ready.

**Deliverable:**

- [ ] **Main menu + onboarding**: tutorial singkat 30 detik (tidak bisa di-skip di first run)
- [ ] **Game Center integration**: leaderboard waktu bertahan per wave tertinggi
- [ ] **Haptic .ahap files**: semua pola haptic disimpan sebagai file `.ahap` untuk konsistensi
- [ ] **Dynamic arena seed**: layout berbeda tiap session, tapi fair (no impossible spawns)
- [ ] **App Store assets**: screenshots, preview video, metadata
- [ ] **TestFlight beta**: 2 minggu external testing
- [ ] **Crash reporting**: integrasikan Firebase Crashlytics atau native MetricKit
- [ ] **Accessibility**: gyro sensitivity range lebar, opsi visual high-contrast mode

---

## Tech Stack Summary

| Layer | Framework | Referensi |
|---|---|---|
| **3D Rendering** | RealityKit 4 — `RealityView`, `ModelEntity`, `PhysicsBodyComponent`, ECS Systems | `developer.apple.com/documentation/realitykit` |
| **Asset authoring** | Reality Composer Pro — MaterialX shaders, particle emitter, animasi .usdz | Bundled dengan Xcode |
| **UI + HUD** | SwiftUI — `RealityView` + ZStack overlay | `developer.apple.com/documentation/swiftui` |
| **Gyro input** | CoreMotion — `CMMotionManager`, `CMDeviceMotion` | `developer.apple.com/documentation/coremotion` |
| **Haptic** | CoreHaptics — `CHHapticEngine`, `CHHapticEvent`, `.ahap` files | `developer.apple.com/documentation/corehaptics` |
| **Spatial audio** | AVFoundation — `AVAudioEngine`, `AVAudioEnvironmentNode` | `developer.apple.com/documentation/avfaudio` |
| **Post-processing** | Metal Performance Shaders via `PostProcessEffect` (bloom, vignette) | `developer.apple.com/documentation/metalperformanceshaders` |
| **Leaderboard** | GameKit — `GKLeaderboard` | `developer.apple.com/documentation/gamekit` |
| **Crash/metrics** | MetricKit | `developer.apple.com/documentation/metrickit` |

---

## Risiko & Mitigasi

| Risiko | Kemungkinan | Mitigasi |
|---|---|---|
| RealityKit kamera isometric butuh setup manual | Medium | Pakai `.custom` camera mode + manual entity positioning di `update:` closure |
| ECS System debugging lebih complex dari OOP | Medium | Xcode kini support 3D scene inspector untuk RealityKit (WWDC24) — pakai itu |
| `PhysicsMotionComponent` velocity cap tidak terduga | Low | Clamp velocity eksplisit di `MotionController` sebelum assign |
| Gyro drift / latency di device lama | Medium | Kalibrasi ulang otomatis tiap 30 detik, sensitivity adjustable di settings |
| Haptic tidak tersedia (iPhone lama / simulator) | Tinggi | Semua haptic wrapped dengan `CHHapticEngine.capabilitiesForHardware().supportsHaptics` guard |
| Spatial audio terlalu CPU-intensive | Low | Limit max concurrent audio sources ke 8 (kecoa aktif di audio radius) |
| Frame drop saat banyak kecoa + particles | Medium | `ParticleEmitterComponent` count cap, LOD via `ModelComponent` swap untuk kecoa jauh |

---

*Dibuat untuk Skitter iOS — Revisi terakhir: Maret 2026*
