# Skitter — iOS Game Planning Document

> Kamu manusia kecil terjebak di landfill. Kecoa sebesar kamu mengejar dari semua arah.  
> Temukan Baygon sebelum semuanya terlambat.

---

## Ringkasan Konsep

| Atribut | Detail |
|---|---|
| **Nama** | Skitter |
| **Platform** | iOS (iPhone-first, landscape) |
| **Genre** | Survival horror arcade |
| **Perspektif** | First person (kamera di mata karakter manusia kecil) |
| **Kontrol** | Gyroscope (tilt) **atau** Virtual analog joystick — pilih di main menu |
| **Arena** | Landfill malam hari — terbuka, obstacles berserakan |
| **Tujuan** | Temukan kaleng Baygon di antara 5 mystery bag sebelum dikepung kecoa |
| **Target iOS** | iOS 18.0+ |
| **Language** | Swift 5.9+ |

### Konsep "Dunia Terbalik"

Player bukan bola — player adalah **manusia kecil** yang berlari di landfill. Kecoa-kecoa berukuran sebesar (atau lebih besar dari) manusia. Proporsi ini yang bikin disturbing: sesuatu yang normalnya kamu injak sekarang bisa mengejar dan membunuhmu. Di first person, kecoa yang charging terlihat mengisi seluruh layar — antena, cakar, semua detail terlalu dekat.

---

## Core Game Loop (Diperbarui)

Berbeda dari survival murni, Skitter sekarang punya **objective aktif**: temukan 1 kaleng Baygon yang tersembunyi di antara 5 kresek hitam tersebar di arena.

```
Start → Roaming arena (first person) → Dekati kresek hitam → Reveal isinya
       ↓                                                            ↓
   Roach makin banyak ←── Trigger bait object (tumpukan busuk) ←───┘
       ↓                                                            ↓
   Giant & Flying spawn                              Temukan Baygon → WIN
```

**Tension loop:** Setiap kresek yang salah = bait ter-trigger = kecoa bertambah dan evolve. Player dihadapkan pilihan antara eksplorasi cepat (risiko tinggi) atau hati-hati sambil menghindari kecoa yang makin banyak. Tidak ada cara membunuh kecoa — satu sentuhan = mati. Satu-satunya escape adalah Baygon.

---

## Mystery Bag System

### Bentuk Awal: Kresek Hitam

Semua 5 object di-spawn sebagai **kantong kresek hitam identik** — ukuran sama, warna sama, tidak ada visual hint apapun dari jauh. Player tidak bisa bedain mana yang baygon mana yang bait sampai benar-benar mendekat.

**Behavior:**

| Kondisi | Yang Terjadi |
|---|---|
| Jauh / dekat (belum collision) | Kresek terlihat hitam identik, tidak ada hint apapun |
| Player collision dengan kresek | HUD label muncul + efek langsung dieksekusi |

### Reveal via Collision

Kresek hitam **selalu terlihat hitam** — sejauh atau sedekat apapun player, tidak ada preview, tidak ada hint visual. Reveal hanya terjadi satu cara: player **menyentuh/melewati** kresek (collision trigger).

Begitu collision terjadi, dua hal sekaligus:
1. **HUD label muncul** sebentar di tengah layar — "BAYGON" atau "TUMPUKAN BUSUK"
2. **Efek langsung dieksekusi** — win jika baygon, escalation jika bait

Tidak ada jeda keputusan. Player baru tau isinya setelah sudah terlanjur trigger.

### Object Types

**✅ Counter (1 buah) — Baygon**
- Kaleng pestisida tua, label kuning-oranye pudar
- Begitu di-trigger: area burst chemical radius luas, semua roach aktif mati seketika
- **WIN condition** — game selesai, stats ditampilkan

**❌ Bait (4 buah) — Tumpukan Makanan Busuk**
- Tumpukan organik coklat gelap, plastik kresek setengah terbuka
- Begitu di-trigger: spawn burst 3–4 roach baru dari semua arah sekaligus
- Semua roach yang sudah ada naik tier (Chaser → Giant, Giant → Flying)
- Posisi kresek hitam lainnya **tidak berubah** — hanya escalation yang terjadi

### Spawn Layout

5 kresek hitam di-spawn di posisi semi-random saat game start, dengan aturan:
- Tidak spawn terlalu dekat satu sama lain (minimum 15 unit jarak)
- Tidak spawn di dekat starting position bola (minimum 20 unit)
- Tidak spawn di dalam/overlap obstacle
- Distribusi menyebar ke seluruh penjuru arena — tidak mengelompok

---

## Perspektif: First Person

Kamera ditempatkan **di mata karakter manusia kecil**, menghadap arah gerakan karakter. Player melihat arena dari sudut pandang manusia mungil yang berlari di antara sampah — kecoa datang langsung ke muka, setinggi atau lebih tinggi dari eye level.

### Kenapa First Person Lebih Seram

- Roach yang charging terlihat mengisi seluruh layar saat mendekat — detail antena dan cakar jelas
- Tidak ada overhead view — ancaman dari belakang tidak terlihat, hanya bisa didengar
- Spatial audio jadi critical — suara skittering dari belakang adalah satu-satunya warning
- Mystery bag tidak bisa semua dilihat sekaligus — harus actively hunting sambil waspada
- Tidak ada crush mechanic — satu sentuhan = game over. Pure escape.
- Proporsi dunia yang "terbalik" lebih terasa: obstacle yang besar, kecoa setinggi badan

### Implementasi Kamera First Person

Kamera mengikuti posisi karakter dengan eye-level offset, menghadap ke arah gerakan. Saat diam, kamera menghadap arah input terakhir (gyro atau joystick).

```swift
// Di GameView update: closure
let charPos = playerEntity.position(relativeTo: nil)

// Eye level — sedikit di atas tengah karakter
let eyeOffset = SIMD3<Float>(0, 0.8, 0)
camera.position = charPos + eyeOffset

// Face direction of movement
let moveDir = SIMD2<Float>(velocity.x, velocity.z)
if length(moveDir) > 0.3 {
    let angle = atan2(velocity.x, velocity.z)
    // Smooth lerp untuk mengurangi motion sickness
    let targetOrientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
    camera.orientation = simd_slerp(camera.orientation, targetOrientation, 0.15)
}
```

**Field of view:** ~75° untuk feel claustrophobic tapi tetap playable.

### Kontrol: Gyro vs Analog Joystick

Dipilih di **main menu** sebelum masuk game. Setting disimpan ke `UserDefaults`.

**Gyro (Tilt):**
- Tilt HP maju/mundur/kiri/kanan = karakter bergerak ke arah tersebut
- Baseline di-capture saat game start — player bebas pegang HP di sudut nyaman
- Dead zone `0.03` untuk cegah drift
- Cocok untuk feel immersive, tapi butuh ruang gerak tangan

**Virtual Analog Joystick:**
- Fixed joystick di kiri bawah layar (SwiftUI overlay)
- Drag dari titik tengah joystick = arah + speed gerakan
- Speed = magnitude drag (push lebih jauh = lari lebih cepat)
- Cocok untuk main santai tanpa harus tilt HP

```swift
// MotionController — dua mode input
enum InputMode {
    case gyroscope
    case analogJoystick
}

// JoystickView output → MotionController
func applyJoystickInput(dx: Float, dz: Float) {
    let targetVx = dx * sensitivity
    let targetVz = dz * sensitivity
    // Sama persis dengan gyro path setelah ini
    applyVelocity(vx: targetVx, vz: targetVz)
}
```

---

## iOS Frameworks

### Rendering — RealityKit 4
`developer.apple.com/documentation/realitykit`

RealityKit 4 (iOS 18+) adalah pilihan rendering untuk Skitter. SceneKit resmi deprecated di WWDC 2025 — Apple merekomendasikan semua proyek baru pakai RealityKit. RealityKit menggunakan arsitektur **Entity Component System (ECS)**: behavior dibungkus dalam `Component` yang di-attach ke `Entity`, bukan lewat subclassing. Rendering masuk ke SwiftUI view `RealityView` langsung — tidak perlu `UIViewController` wrapper.

| Komponen RealityKit | Digunakan untuk |
|---|---|
| `RealityView` | SwiftUI view utama — host seluruh dunia 3D game |
| `Entity` | Setiap objek di dunia: bola, kecoa, blok, kresek, baygon |
| `ModelEntity` | Entity dengan mesh + material — bola, obstacle, kecoa, mystery bag |
| `ModelComponent` | Attach mesh (`MeshResource`) + material ke entity |
| `PhysicsBodyComponent` | Physics body untuk bola dan obstacles — mode `.dynamic` / `.static` |
| `PhysicsMotionComponent` | Set velocity langsung ke physics body bola dari gyro input |
| `CollisionComponent` | Collision shape — sphere untuk bola & kecoa, box untuk obstacles |
| `PointLightComponent` | Scattered point lights merah/hijau untuk mood landfill |
| `ParticleEmitterComponent` | Gas hijau, crush splat, speed trail bola |
| `PhysicsSimulationComponent` | Gravity settings, physics world |
| `AnimationComponent` / `AnimationLibraryComponent` | Death animation kecoa, animasi sayap kecoa terbang |
| `ShaderGraphMaterial` | Material transparan bola via Reality Composer Pro, tekstur lantai kotor |
| `PostProcessEffect` (custom) | Vignette gas hijau + bloom lewat Metal Performance Shaders |

**ECS custom systems untuk game logic:**

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

**Kamera first person:** Kamera entity (`PerspectiveCamera`) di-posisikan di dalam bola, menghadap arah velocity bola. Di-update tiap frame di `update:` closure `RealityView`.

**HUD overlay:** SwiftUI `ZStack` — `RealityView` di bawah, SwiftUI views di atas sebagai HUD (timer, crushed counter, proximity label, threat indicator).

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
| Masuk proximity kresek | `.hapticTransient` | 0.3 | 0.5 | — |
| Trigger bait (tumpukan busuk) | `.hapticContinuous` ramp up | 0.2→1.0 | 0.6 | 0.8s |
| Trigger baygon (WIN) | `.hapticTransient` x3 burst | 1.0 | 0.8 | rapid sequence |
| Game over | `.hapticContinuous` ramp down | 1.0→0 | 0.3 | 1.2s |

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

Di first person, spatial audio jadi critical — suara skittering dari belakang adalah satu-satunya warning system untuk kecoa yang tidak terlihat.

---

### UI — SwiftUI
`developer.apple.com/documentation/swiftui`

**HUD in-game (First Person):**

```
┌─────────────────────────────────────────────────────────┐
│ [MINIMAP]   ●●●●●                          [01:24]      │  ← top bar
│                                                         │
│                   (first person view)                   │
│                                                         │
│                  ┌───────────────┐                      │
│                  │    BAYGON     │  ← proximity reveal  │
│                  └───────────────┘                      │
│ [◉ JOYSTICK]                          [↗ THREAT]       │  ← bottom
└─────────────────────────────────────────────────────────┘
```

| Elemen HUD | Posisi | Isi |
|---|---|---|
| **Mini map** | Kiri atas | Top-down view arena: dinding, obstacles, posisi player (titik putih). **5 mystery bag TIDAK tampil** — harus cari manual |
| **Bags remaining** | Tengah atas (dekat minimap) | "●●●●●" — dot solid menghilang tiap bag di-trigger |
| **Timer** | Kanan atas | Format `MM:SS` — waktu bertahan |
| **Proximity label** | Tengah bawah | Nama object saat dalam radius 8u. Fade in/out |
| **Virtual joystick** | Kiri bawah | Hanya muncul jika mode = `.analogJoystick`. Transparan saat idle, sedikit opaque saat aktif |
| **Threat indicator** | Pojok kanan bawah | Panah ke arah kecoa terdekat. Makin merah makin dekat |

**Mini Map — Detail:**
- Rendered sebagai SwiftUI `Canvas` top-down 2D
- Update setiap 0.5 detik (bukan per-frame, hemat CPU)
- Tampil: shape arena, posisi obstacles (kotak abu gelap), posisi player (titik putih bergerak)
- **Tidak tampil:** posisi 5 mystery bags, posisi kecoa
- Ukuran: ~80×80pt, semi-transparent background hitam, pojok kiri atas

---

## Halaman (3 Layar)

### Halaman 1 — Main Menu

**Tone:** Gelap, sparse, sedikit mencekam.

| Elemen | Detail |
|---|---|
| **Logo** | Ikon siluet manusia kecil + teks "SKITTER" spasi lebar. Subtitle "FIND IT BEFORE THEY FIND YOU" |
| **Best score** | Format "BEST: MM:SS" — waktu tercepat temukan baygon. Kosong jika belum pernah menang |
| **Control mode selector** | Toggle 2 opsi: "TILT" (gyro) / "JOYSTICK" (analog). Disimpan ke UserDefaults, jadi pilihan default next session |
| **Tombol Play** | Full-width, prominent, warna aksen hijau kotor |
| **Tombol Settings** | Half-width, muted |

---

### Halaman 2 — Game Screen

Portrait tidak didukung — game berjalan landscape saja. Seluruh layar adalah first person view RealityKit. HUD duduk di atas arena sebagai SwiftUI overlay transparan.

---

### Halaman 3 — Game Over / Win Screen

**Game Over** (ditangkap kecoa):
Muncul saat bola tertangkap kecoa. Transisi: view fade ke gelap merah.

**Win** (temukan baygon):
Transisi berbeda — flash putih bright, lalu stats muncul dengan nuansa berbeda (bukan merah, tapi hijau pudar).

| Elemen | Detail |
|---|---|
| **Header** | "GAME OVER" (merah) atau "SURVIVED" (hijau) |
| **4 stat cards** | Grid 2×2: Survived (waktu), Crushed (jumlah kecoa), Bags Triggered (berapa bait ke-trigger), Best Time |
| **Tombol Play Again** | Full-width. Restart dengan bag placement baru |
| **Tombol Menu** | Half-width, muted |

---

## Dunia Game: Landfill Malam Hari

### Visual Theme

| Elemen | Detail |
|---|---|
| **Lantai** | Tile kotor coklat-hijau, textur tanah basah dan sampah, sesekali reflektif (oli) |
| **Lighting** | Ambient sangat gelap (#080810). Scattered point lights: merah dari tumpukan sampah membara, hijau dari gas bocor |
| **Karakter** | Manusia kecil — proporsi mungil vs lingkungan landfill normal. Di first person tidak terlihat body-nya sendiri |
| **Kecoa** | Low-poly tapi berdetail: antena, cakar. Normal = coklat, Giant = hitam mengkilap, Terbang = coklat-merah dengan sayap translucent |
| **Mystery bags (kresek)** | Kantong hitam matte, sedikit berkilap basah. Subtle inflate/deflate animation — semua sama |
| **Obstacles** | Tong sampah berkarat, tumpukan sampah padat, puddle oli hitam, pagar kawat jaring |
| **Background/sky** | Hitam pekat, kabut hijau di horizon |
| **Particles** | Gas hijau mengepul dari lantai secara periodik, debu saat bola rolling cepat |

### Layout Arena

Arena berbentuk persegi panjang luas. Obstacle layout semi-random dengan seed per session:
- 8–12 **blok solid** (tumpukan sampah, tong besar) — tidak bisa dilewati
- 4 **ramp** — kecoa melambat 65% saat naik ramp
- 2–3 **puddle oli** — bola sangat licin (friction ~0), kecoa slip juga
- 2 **kawat jaring** — passable, bola dan kecoa melambat 40%
- 2 **gas vent** — semburan periodik tiap ~8 detik, push semua objek di radius
- **5 mystery bags (kresek hitam)** — tersebar random, 1 berisi baygon, 4 berisi tumpukan busuk

---

## Tipe Kecoa

> **Aturan universal:** Tidak ada crush mechanic. Kontak kecoa dengan player = **instant game over**, apapun kecepatan atau kondisinya. Satu-satunya survival option adalah menghindar.

### 1. Kecoa Normal (Chaser)
Muncul sejak awal game. Langsung mengejar posisi player. Di first person, terlihat langsung charging ke kamera.

| Stat | Value |
|---|---|
| Speed | 4.0 m/s |
| Ukuran | Setinggi/sebesar karakter player |
| Collision | Trigger — menyentuh player = game over |

### 2. Kecoa Giant
Spawn saat bait ke-1 ter-trigger. Bergerak lambat tapi besar — memblok jalur di koridor sempit.

| Stat | Value |
|---|---|
| Speed | 2.5 m/s |
| Ukuran | 2–3x lebih besar dari karakter player |
| Collision | Trigger — menyentuh player = game over |

### 3. Kecoa Terbang
Spawn saat bait ke-2 ter-trigger. Hover di atas lantai — tidak terhalang obstacle apapun. Di first person: datang dari atas, shadow-nya terlihat di lantai sebelum body-nya terlihat.

| Stat | Value |
|---|---|
| Speed | 5.5 m/s |
| Hover height | Sedikit di atas kepala karakter |
| Visual | Sayap bergetar, shadow di lantai, buzz sound |
| Collision | Trigger — menyentuh player = game over |

---

## Eskalasi Berdasarkan Bait

Berbeda dari wave system berbasis timer, eskalasi sekarang **dipicu oleh player sendiri** saat salah memilih kresek.

| Bait ke- | Efek Langsung | Efek Ongoing |
|---|---|---|
| Bait 1 | Spawn 3 Chaser baru. Semua Chaser aktif upgrade → Giant | Speed semua kecoa +10% |
| Bait 2 | Spawn 2 Giant baru. Spawn 1 Flying pertama | Speed semua kecoa +15% |
| Bait 3 | Spawn 2 Flying. Semua kecoa aktif speed +20% lagi | Vignette gas mulai muncul |
| Bait 4 | Spawn swarm 5 Chaser sekaligus | Vignette makin pekat, kecoa makin agresif |

**Jika player beruntung dan temukan baygon di kresek pertama:** Game selesai cepat dengan 0 bait ter-trigger. Score bonus untuk "first try".

---

## Vignette Progresif: Gas Hijau Toxic

Berbeda dari sebelumnya, vignette sekarang dipicu oleh bait triggers (bukan pure timer). Tiap bait ter-trigger = gas makin pekat.

| Bait Triggered | Vignette | Visibility |
|---|---|---|
| 0 | Tidak ada | 100% |
| 1 | Gas tipis di sudut | ~85% |
| 2 | Awan hijau ~20% pinggir | ~70% |
| 3 | Pekat, mulai sembunyikan kecoa di pinggir | ~50% |
| 4 | Hampir setengah layar tertutup | ~35% |

---

## Obstacles & Traps

| Obstacle | Type | Efek ke Bola | Efek ke Kecoa |
|---|---|---|---|
| **Tumpukan sampah** | Solid blocker | Tidak bisa lewat, bounce | Tidak bisa lewat |
| **Ramp** | Passable | Speed normal | Speed -65% saat naik |
| **Puddle oli** | Passable trap | Friction ~0, sangat licin | Kecoa juga slip, speed -30% |
| **Kawat jaring** | Passable slow | Speed -40% saat dalam area | Speed -40%, Kecoa Terbang tidak masuk |
| **Gas vent** | Hazard periodik | Push kuat jika di atas vent saat blow | Push kecoa juga — bisa dimanfaatkan |

---

## Arsitektur Kode (Updated)

```
Skitter/
├── App/
│   ├── SkitterApp.swift          // SwiftUI App entry
│   └── AppState.swift            // @Observable global state (score, controlMode, settings)
│
├── Game/
│   ├── GameView.swift            // SwiftUI view: RealityView + HUD ZStack
│   ├── GameState.swift           // @Observable — timer, bait count, bags remaining, isWin
│   ├── PlayerEntity.swift        // ModelEntity karakter manusia kecil — PhysicsBodyComponent
│   ├── RoachEntity.swift         // Base ModelEntity kecoa — CollisionComponent trigger
│   ├── ChaserRoach.swift         // RoachComponent data untuk Chaser
│   ├── GiantRoach.swift          // RoachComponent data untuk Giant
│   ├── FlyingRoach.swift         // RoachComponent data untuk Flying
│   ├── MysteryBagEntity.swift    // Kresek hitam entity — BagType, reveal radius, USDZ swap
│   ├── ObstacleEntity.swift      // ModelEntity obstacle — PhysicsBodyComponent static
│   └── ArenaBuilder.swift        // Generate arena + spawn 5 mystery bags random
│
├── Systems/
│   ├── RoachAISystem.swift       // EntityQuery kecoa → update PhysicsMotionComponent
│   ├── ContactSystem.swift       // Deteksi kontak player-roach → instant game over
│   ├── BagTriggerSystem.swift    // Player collision dengan kresek → reveal label + eksekusi efek
│   ├── EscalationSystem.swift    // Spawn + escalate kecoa saat bait count naik
│   └── VignetteSystem.swift      // Update gas overlay intensity (Phase 3)
│
├── Controllers/
│   ├── MotionController.swift    // Dual-mode: gyro (CMMotionManager) atau joystick input
│   ├── HapticManager.swift       // CHHapticEngine singleton, semua pola haptic
│   └── AudioManager.swift        // AVAudioEngine, spatial audio per kecoa
│
├── HUD/
│   ├── HUDView.swift             // ZStack container semua HUD elements
│   ├── MiniMapView.swift         // Canvas top-down: arena shape + player dot (NO bags/roaches)
│   ├── JoystickView.swift        // Virtual analog joystick — hanya tampil jika mode .analogJoystick
│   ├── TriggerLabelView.swift    // Label singkat muncul sesaat setelah collision dengan kresek
│   ├── ThreatIndicatorView.swift // Canvas arrow ke kecoa terdekat
│   └── BagsRemainingView.swift   // Dot indicator 5 bags
│
├── UI/
│   ├── MainMenuView.swift        // Termasuk control mode selector (Tilt / Joystick)
│   ├── GameOverView.swift        // Handles lose dan win state
│   └── SettingsView.swift
│
└── Assets/
    ├── Models/                   // .usdz: roach types, kresek hitam, baygon reveal, tumpukan busuk reveal
    ├── Textures/                 // Lantai, material kecoa, env map
    ├── Sounds/                   // Skitter loops, bait trigger sfx, ambient
    └── Haptics/                  // .ahap files untuk CoreHaptics patterns
```

### File Baru vs Lama

| File | Status | Keterangan |
|---|---|---|
| `PlayerEntity.swift` | 🆕 Baru | Karakter manusia kecil, gantiin BallEntity |
| `MysteryBagEntity.swift` | 🆕 Baru | Kresek hitam + BagType + USDZ swap on reveal |
| `ContactSystem.swift` | 🆕 Baru | Gantikan CrushSystem — kontak = game over, no threshold |
| `BagTriggerSystem.swift` | 🆕 Baru | Collision player-kresek → tampilkan label + eksekusi efek |
| `EscalationSystem.swift` | 🆕 Baru | Spawn + upgrade kecoa per bait count |
| `MiniMapView.swift` | 🆕 Baru | Canvas 2D top-down — arena + player dot only |
| `JoystickView.swift` | 🆕 Baru | Virtual joystick SwiftUI — conditional render |
| `TriggerLabelView.swift` | 🆕 Baru | Label "BAYGON" / "TUMPUKAN BUSUK" muncul sesaat setelah trigger |
| `BagsRemainingView.swift` | 🆕 Baru | Dot indicator 5 bags |
| `GameView.swift` | ✏️ Update | First person camera, dual input mode |
| `GameState.swift` | ✏️ Update | Tambah `baitTriggeredCount`, `bagsRemaining`, `isWin`, `controlMode` |
| `ArenaBuilder.swift` | ✏️ Update | Tambah `spawnMysteryBags()` |
| `MotionController.swift` | ✏️ Update | Tambah `InputMode` enum + `applyJoystickInput()` |
| `AppState.swift` | ✏️ Update | Simpan `controlMode` ke UserDefaults |
| `MainMenuView.swift` | ✏️ Update | Tambah control mode toggle |
| `GameOverView.swift` | ✏️ Update | Handle win + lose state |
| `HUDView.swift` | ✏️ Update | Layout baru: minimap, joystick conditional, proximity label |
| `HapticManager.swift` | ✏️ Update | Tambah pola bait trigger, baygon win, hapus crush |
| `BallEntity.swift` | ❌ Hapus | Diganti PlayerEntity |
| `CrushSystem.swift` | ❌ Hapus | Diganti ContactSystem |
| `RoachAISystem.swift` | — Sama | Tidak perlu major change |

---

## Development Phases

### ✅ Phase 1 — MVP (DONE)

- [x] RealityKit scene: `RealityView` + arena datar dengan tile floor, obstacle blok solid
- [x] Bola: `ModelEntity` + `PhysicsBodyComponent(.dynamic)` + `CollisionComponent`
- [x] CoreMotion gyro input → `PhysicsMotionComponent.linearVelocity`
- [x] 1 tipe kecoa (Chaser): `RoachAISystem` dengan separation steering via ECS
- [x] Collision detection: bola vs kecoa via `CollisionEvents.Began` → game over
- [x] Crush mechanic (Phase 1 only — dihapus di Phase 2)
- [x] Basic HUD: timer + crushed counter + crush speed meter
- [x] Kamera isometric fixed-angle (diganti first person di Phase 2)
- [x] CoreHaptics: obstacle hit + crush kecoa
- [x] Game loop: start → countdown → play → game over → restart

---

### 🔄 Phase 2 — New Core (Target: 3–4 minggu)

**Goal:** Gameplay loop baru berjalan end-to-end dan terasa di device nyata. Fokus pada mechanic utama — bukan polish. **1 tipe kecoa dulu**, vignette dan escalation full masuk Phase 3.

**Deliverable:**

- [ ] **PlayerEntity**: ganti BallEntity — karakter manusia kecil dengan PhysicsBodyComponent
- [ ] **First person camera**: kamera di eye-level karakter, smooth orientation lerp
- [ ] **Dual control mode**: gyro tetap jalan + `JoystickView` virtual analog, toggle di main menu, simpan ke UserDefaults
- [ ] **ContactSystem**: gantikan CrushSystem — kontak player-roach = instant game over, no threshold
- [ ] **MysteryBagEntity**: kresek hitam entity, BagType enum (.baygon / .bait), placement rules
- [ ] **BagTriggerSystem**: collision player-kresek → tampilkan HUD label + eksekusi efek (win atau escalation)
- [ ] **EscalationSystem**: saat bait trigger — spawn 3–4 Chaser baru (Phase 2: Chaser saja, Giant & Flying Phase 3)
- [ ] **Win condition**: trigger baygon → game over screen dengan state `.win`
- [ ] **MiniMapView**: Canvas top-down — arena walls + obstacles + player dot. Bags dan roach **tidak tampil**
- [ ] **BagsRemainingView**: 5 dot indicator di HUD, berkurang tiap bag di-trigger
- [ ] **ArenaBuilder update**: tambah `spawnMysteryBags()` dengan placement rules
- [ ] **Main menu update**: control mode toggle (TILT / JOYSTICK)
- [ ] **GameOverView update**: handle state `.win` vs `.lose`, stat baru (bait triggered count)
- [ ] **HapticManager update**: hapus crush haptic, tambah bait trigger + baygon win pattern

**Tidak perlu di Phase 2:**
- Giant & Flying roach type
- Vignette gas hijau
- Spatial audio
- Kresek subtle animation
- Escalation tier upgrade (hanya spawn Chaser baru)

---

### Phase 3 — Full Horror (Target: 3–4 minggu)

**Goal:** Semua tipe kecoa aktif, eskalasi penuh, vignette, dan game terasa genuinely scary.

**Deliverable:**

- [ ] **Giant roach**: ModelEntity besar, speed lambat, visual mengisi FOV, spawn saat bait ke-1
- [ ] **Flying roach**: hover entity, tidak terhalang obstacle, shadow di lantai, spawn saat bait ke-2
- [ ] **Eskalasi tier upgrade**: per bait trigger — Chaser→Giant, Giant→Flying pada kecoa aktif
- [ ] **Vignette gas hijau**: overlay progresif berdasarkan bait count (0→4 bait = 0%→65% coverage)
- [ ] **Spatial audio**: skitter sound per kecoa, `AVAudioEnvironmentNode`, suara datang dari arahnya
- [ ] **Kresek subtle animation**: inflate/deflate halus pada semua bags — semua identik, no hint
- [ ] **Roach behavior variety**: hesitation + lunge, tidak semua langsung charge
- [ ] **Camera effects**: screen crack/vignette saat roach sangat dekat, screen shake saat bait trigger
- [ ] **Bait trigger effect**: suara buzz lalat + roach spawn dari dalam kresek
- [ ] **Baygon win effect**: flash chemical dari kamera, roach mati satu per satu
- [ ] **Landfill visual theme**: lighting, material, tekstur — mood malam hari penuh
- [ ] **Audio polish**: reverb landfill, ambient crickets/wind, suara kresek saat didekati
- [ ] **Gyro calibration**: manual recalibrate tombol
- [ ] **Performance pass**: 60fps di iPhone 12+, 30fps fallback iPhone X

---

### Phase 4 — Full Release (Target: 3–4 minggu)

**Goal:** App Store ready.

**Deliverable:**

- [ ] **Main menu + onboarding**: tutorial singkat 30 detik first run — explain mystery bag mechanic
- [ ] **Game Center integration**: leaderboard fastest baygon find + most bait triggered without dying
- [ ] **Dynamic arena seed**: bag placement berbeda tiap session
- [ ] **Settings screen**: gyro sensitivity, haptic on/off, audio volume
- [ ] **Haptic .ahap files**: semua pola haptic sebagai file `.ahap`
- [ ] **App Store assets**: screenshots, preview video, metadata
- [ ] **TestFlight beta**: 2 minggu external testing
- [ ] **Crash reporting**: MetricKit
- [ ] **Accessibility**: gyro sensitivity range lebar, opsi visual high-contrast

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
| First person + gyro = motion sickness | Tinggi | Smooth camera lerp (slerp 0.15), dead zone lebar, FOV setting di options |
| Joystick feel kurang responsive di first person | Medium | Velocity langsung (bukan force) — input → posisi lebih predictable dari physics-based |

| Model USDZ swap saat proximity terasa glitchy | Medium | Pre-load semua model di `beginGame()`, swap hanya toggle visibility bukan load baru |
| Player stuck tidak nemu baygon (semua bait sudah trigger) | Medium | Setelah 4 bait trigger, baygon kresek kasih subtle glow samar — last resort hint |
| Kresek terlalu mirip, player frustrasi | Low | Intentional — pure gambling adalah core tension. Tutorial menjelaskan ini |
| Instant death terlalu harsh, player drop | Medium | Death screen cepat + "PLAY AGAIN" prominent — minimize friction untuk retry |
| ECS System debugging lebih complex dari OOP | Medium | Xcode 3D scene inspector untuk RealityKit — pakai itu |
| Gyro drift / latency di device lama | Medium | Kalibrasi ulang otomatis tiap 30 detik |
| Haptic tidak tersedia | Tinggi | Guard dengan `CHHapticEngine.capabilitiesForHardware().supportsHaptics` |
| Frame drop saat banyak kecoa + particles | Medium | `ParticleEmitterComponent` count cap, LOD untuk kecoa jauh |

---

*Dibuat untuk Skitter iOS — Revisi terakhir: Maret 2026*
