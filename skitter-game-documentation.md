# Dokumentasi Proyek Skitter Game

Proyek ini adalah sebuah game yang dibangun menggunakan SwiftUI dan RealityKit. Berikut adalah penjelasan mendetail mengenai isi dan logika dari setiap file `.swift` yang ada di dalam proyek, disusun berdasarkan foldernya.

## Folder App

### 1. `AppState.swift`
- **Isi**: Mendefinisikan status global dari aplikasi menggunakan `@Observable` dan struct enumerasi `Screen`.
- **Logika**:
  - Menyimpan status layar aktif saat ini (`menu`, `playing`, `gameOver`).
  - Menyimpan statistik permainan terakhir (waktu bertahan dan jumlah kecoa yang dihancurkan).
  - Secara persisten menyimpan dan mengambil skor waktu terbaik (`bestTime`) ke/dari pengaturan lokal `UserDefaults`.
  - Memiliki fungsi perubahan state transisi layar, seperti: `startGame()` untuk mulai bermain, `endGame()` untuk mencatat metrik ke database dan membuka layar game over, serta `returnToMenu()`.

### 2. `SkitterApp.swift`
- **Isi**: Merupakan _entry point_ utama aplikasi SwiftUI.
- **Logika**:
  - `SkitterApp` menginisialisasi `AppState` root dan menyuntikkannya ke dalam environment aplikasi.
  - Memiliki `ContentView` yang bertindak sebagai _router_ layar berdasar properti `currentScreen`. Jika `appState.currentScreen` == `.menu` maka menampilkan `MainMenuView`, jika `.playing` maka memuat `GameView`, dsb.
  - Menerapkan _transition modifier_ sehingga pergantian layar memudar memunculkan layar (opacity di-animasi).

---

## Folder Controllers

### 3. `HapticManager.swift`
- **Isi**: Kelas independen untuk memicu getaran (_haptic feedback_) menggunakan framework bawaan `CoreHaptics`.
- **Logika**:
  - Mengecek apakan _hardware_ saat ini mendukung haptik secara penuh.
  - Menyiapkan `CHHapticEngine` untuk merender getaran.
  - Fungsi sentral:
    - `playObstacleHit()`: Menghasilkan haptic tunggal, tajam, dan cepat untuk sensasi bola mentok dinding/rintangan.
    - `playCrush()`: Digunakan saat melindas musuh. Memutar tumbukan keras ("transient") secara ganda diikuti efek lanjutan sedikit pelan ("continuous") demi rasa empuk namun garang.
    - `playGameOver()`: Menghadirkan getaran panjang secara terus menerus namun intensitasnya memudar bertahap (_ramp down_), menyampaikan kesan gagal secara fisik.

### 4. `MotionController.swift`
- **Isi**: Controller sensor device menggunakan `CMMotionManager`.
- **Logika**:
  - `startMotionUpdates()`: Rutin membaca data `pitch` (kemiringan maju-mundur) dan `roll` (kemiringan atas-bawah ke samping) dari sensor gyro.
  - Menetapkan baseline di posisi pembacaan frame awal, lalu melakukan penormalan bacaan kemiringan selanjutnya.
  - `applyForce()`: Menerjemahkan output gyro (sudut tilt dikalikan kepekaan gravitasi fiktif) menjadi arah dan gaya linear di parameter velositas 3D sumbu X dan Z bola yang ada di RealityKit. Kecepatan ditahan tidak boleh melewati batas `maxSpeed`.
  - `applySimulatedInput()`: Cadangan bila gyro / motion tidak ada (seperti dalam environment Simulator), di mana bola digerakkan mendeteksi usapan layar (drag).

---

## Folder Game

### 5. `ArenaBuilder.swift`
- **Isi**: Utility / Factory yang menyusun dunia panggung 3D dalam RealityKit.
- **Logika**:
  - Memasukkan parameter `CollisionGroups` untuk spesifikasi interaksi antara objek benda mati, rintangan tembok, bola, maupun musuh (kecoa).
  - `createFloor()`: Membuat _MeshPlane_ gelap agak bergelembur lengkap dengan `PhysicsBodyComponent` static.
  - `createBoundaryWalls()`: Menyusun empat kotak memanjang menjadi dinding maya di kanan-kiri-atas-bawah agar musuh tidak kabur dan bola selalu mantul di dalam arena.
  - `createObstacles()`: Membangun sekumpulan boks yang berhamburan dalam lapangan. Bentuk dan warna (tekstur PBR warna tanah kelam) di-loop untuk 10 titik semi-acak. Model ini diberi `PhysicsBodyComponent` stastis yang solid.

### 6. `BallEntity.swift`
- **Isi**: Pembangun entitas `ModelEntity` dari bola pemain.
- **Logika**:
  - Membentuk Sphere 3D transparan kekuningan.
  - Membuat bodinya bertipe fisik `dynamic` yang secara konstan ikut terpengaruh oleh gaya (seperti _damping_ yang menyimulasikan gesekan udara dan tarikan controller).
  - Melengkapi filter kolisi supaya hanya tertahan jika terbentur item dalam arena atau kecoa musuh.

### 7. `GameState.swift`
- **Isi**: Menyimpan metrik spesifik _di dalam satu sesi_ yang nilainya direset saat restart game.
- **Logika**:
  - Menghitung waktu stopwatch dengan presisi Timer berkala.
  - `startGame()` mereset seluruh counter `elapsedTime` ke 0, jumlah kecoa yang dipecahkan, memulai perhitungan tanggal durasi.
  - `triggerGameOver()` menyalakan _state isGameOver_ dan menghentikan pengelola stopwatch.
  - Menyediakan nilai perhitungan string angka (`formattedTime` & `formattedCrushed`) untuk View secara otomatis.

### 8. `GameView.swift`
- **Isi**: Kanvas perantara antara View SwiftUI 2D dan komponen `RealityView` 3D RealityKit.
- **Logika**:
  - Merender struktur 3D secara penuh dengan pencahayaan warna warni (*directional light*, cahaya titik merah-mood).
  - Mengkalkulasikan pergeseran kamera (*isometric perspective*) agar otomatis mengarahkan fokus ke titik poros tempat bola diletakkan (*smooth follow*).
  - Menampilkan CountDown Overlay ("3", "2", "1") di awal frame render.
  - Mewadahi event-loop musuh: Setiap 8 detik Timer jalan dan memanggil `startRoachSpawning()` agar satu musuh ditambahkan dari tepi arena, sekaligus mengisi bibit-bibit 2 musuh di peluncuran.
  - Menjembatani komponen interaksi fisika: mendelegasikan gesekan layar dari SwiftUI ke dalam aksi `motionController` jika mode simulasi berlaku.

### 9. `RoachComponent.swift`
- **Isi**: Komponen entiti kustom (ECS - *Entity Component System*).
- **Logika**:
  - Mengidentifikasi identitas kecoa sebagai bagian dari suatu kelas perilaku `RoachType` (seperti pengejar/Chaser).
  - Menyimpan nilai mutlak dari `speed` pergerakannya.
  - Menyimpan `crushThreshold`, mengatur syarat minimum kelajuan (*ball speed*) yang mesti ditabrak demi memberangus kecoa dengan tuntas dan aman.

### 10. `RoachEntity.swift`
- **Isi**: Factory / pembangun entitas musuh pengejar pemain.
- **Logika**:
  - Menggunakan properti PBR _(Physically Based Material)_ merancang warna gelap kecokelatan untuk kecoa dari prisma segiempat lonjong.
  - `physics` berlevel `kinematic`: yang berarti physics pada umumnya dilemahkan, dan gaya mekanik dikendalikan spesifik secara program di ECS loop setiap pembaruan frame.
  - `Collision` diset bertipe _trigger_, ia mendeteksi silangan bodi dengan bola, tapi tak serta merta terhempas ala sistem rigid.

---

## Folder HUD

### 11. `HUDView.swift`
- **Isi**: Menampilkan metrik teks game yang mengambang di atas arena 3D.
- **Logika**:
  - *Top Bar*: Mengikat dua buah Text di pojok atas (Jumlah Kecoa dimangsa) dan ditengah (Timer).
  - *Crush Speed / Indikator Daya*: Mendengarkan live-data dari `gameState.ballSpeed`. Jika laju lintasan bola cukup untuk mencapai kecepatan bunuh (`threshold` kecoa: > 6.0), akan memunculkan tulisan "CRUSH" dengan warna nyala hijau dan ikon kilat terisi; jika kecepatan turun (kurang momentum), maka bertuliskan peringatan bahaya warna redup merah "SLOW".
  - *Speed Meter*: Menampilkan elemen balok kecil-kecil (10 grid) horizontal yang menyala dari kiri ke kanan proporsional terhadap prosentasi kecepatan dan kelajuan bola. Berguna sebagai referensi gauge visual. 

---

## Folder Systems

### 12. `CrushSystem.swift`
- **Isi**: Layanan sistem yang meregulasi hukum peristiwa kolisi yang diaktifkan Engine ketika "Benda 1 menyentuh Benda 2".
- **Logika**:
  - Saat ada sinyal _Began event_, dicek spesifik: siapa pemain, dan siapa korbannya.
  - Apabila Bola dan Musuh beririsan: ia memeriksa parameter laju bola saat ini.
    - Jika momentum/kecepatan bola **Melebihi Threshold**: musuh `removeFromParent()` lenyap, angka korban ditambahkan ke dashboard, dan trigger Haptik kemenangan (`playCrush()`).
    - Jika momentum **Lebih kecil**: berarti pemain diserbu dengan kekuatan gembos, langsung mendispatch komando `triggerGameOver()` pada State yang mengakhiri game dan mengunci layer layar kekalahan.
  - Jika yang ditubruk batas tembok, cuma mengeluarkan sound/getaran mentok tanpa sanksi hukuman `playObstacleHit()`.

### 13. `RoachAISystem.swift`
- **Isi**: Arsitektur Artificial Intelligence (Sistem ECS) yang mengatur kepintaran kawan musuh sekelompok mengepung.
- **Logika**:
  - Bekerja secara periodik tiada henti di loop `.rendering`.
  - Mecari Entri dengan Tag kustom `RoachComponent`. Seluruh kecoa yang memilikinya, diperintahkan untuk melihat posisi di mana Entri `ball` berada di peta spasial 3D masa kini.
  - Menghitung secara linear panjang jarak vektor.
  - Me-rotasi arah badan menuju titik ordinat posisi pemain menggunakan Quaternions matematika Euler (_simd_quatf(angle, axis)_).
  - Mengkalkulasikan pergeseran per-frame yang dialirkan paksa ke entitas kecoak dengan daya dan nilai statis dari komponen miliknya (_kinematik bergerak menuju bola secara otonom_). 

---

## Folder UI

### 14. `GameOverView.swift`
- **Isi**: Layar penghujung maut saat kekalahan terjadi.
- **Logika**:
  - Melakukan _freeze_ interaksi sistem selama beberapa saat kemudian merender grid berformat 2x2.
  - Membaca memori riwayat pencapaian permainan di memori AppState: Mengonversi waktu tempuh sesion ini (Survived) dan menampilkan jejeran rekor waktu Terbaik terdahulu menggunakan format _00:00_ layaknya format time display yang baik.
  - Berperan sebagai _controller_ dengan 2 tombol besar navigasi: merestart kembali arena tanpa jeda via _PLAY AGAIN_, atau kembali aman ke base awal main menu via _MENU_.

### 15. `MainMenuView.swift`
- **Isi**: Halaman beranda _entry_ UI game bergaya kelam dan premium.
- **Logika**:
  - Terdiri dari efek animasi memutar membesar-mengecil (_scaling breathing pulsation loops_) pada maskot Logo Bola transparan dan _ZStack_ latar efek partikel abu hijau gelap secara sporadis meluas-lebat untuk memberikan pengalaman "survive" imersif sejak awal app diluncurkan di device.
  - Mengecek apabila ada rekor skor disimpan (_bila ada history > 0_), maka memunculkan widget *BEST SCORE* persis di tengah layer agar menantang pemainnya mengalahkan dirinya di putaran ini.
  - Tombol tunggal PLAY yang ketika ditekankan memutar perintah inisiasi fase Countdown internal di GameView.
