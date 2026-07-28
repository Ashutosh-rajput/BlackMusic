# 🎵 blackmusic

> A premium, privacy-first offline audio player and high-performance YouTube downloader built with Flutter & BLoC.

---

## ✨ Features

### 🎧 Core Audio Experience
- **Offline Music Library**: Fast local storage scanning with metadata extraction (title, artist, album, duration).
- **Active Playing Equalizer Indicator**: Real-time 4-bar animated equalizer indicator in song lists to easily spot the currently playing track.
- **Dynamic 24-Bar Wave Visualizer**: Animated audio wave visualizer on the player screen with a setting toggle to turn it ON/OFF.
- **Lockscreen & Notification Controls**: Native Android media controls and status bar notifications via `just_audio_background`.

### 📥 YouTube Audio Downloader
- **Queue Architecture**: Dedicated background download queue supporting pause, resume, and cancellation.
- **Stream Selection Priority**: High-bitrate M4A audio-only streams with pre-muxed MP4 & WebM fallback for 100% download reliability.
- **Real-Time Progress Notifications**: Android status bar download progress notifications with live percentage indicators.
- **Metadata Tagging**: Automatically saves high-res thumbnail album art and song details.

### 🎨 Personalization & Settings
- **Custom Accent Colors & Amoled Dark Mode**: Tailored HSL color schemes with deep AMOLED black styling.
- **Auto-Scan Control**: Auto music folder scan default set to OFF for instant app launch and complete folder privacy.
- **Sleep Timer & Speed Control**: Built-in sleep timer and variable playback rate control (0.5x - 2.0x).

---

## 🛠️ Architecture & Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: BLoC (`flutter_bloc`)
- **Audio Engine**: `just_audio` & `just_audio_background`
- **YouTube Engine**: `youtube_explode_dart` & `dio`
- **Database**: `drift` (SQLite) & `shared_preferences`
- **UI & Icons**: `flutter_svg`, `cached_network_image`, `google_fonts`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (v3.19.0 or higher)
- Android Studio / VS Code with Flutter extension
- Android Device / Emulator (API Level 21+)

### Installation & Run

1. **Clone Repository**:
   ```bash
   git clone https://github.com/Ashutosh-rajput/flutter_application_1.git
   cd blackmusic
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Application**:
   ```bash
   flutter run
   ```

4. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```

---

## 📄 License
This project is open-source and available under the MIT License.
