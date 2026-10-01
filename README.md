# 🎵 Vinyl

> A modern, privacy-first offline & online music streaming app with an on-device recommendation engine (**PulseIQ**), high-fidelity 320 kbps streaming, background downloads, synchronized lyrics, and Material 3 design — built with Flutter & BLoC.

## 📱 Download

[![Download APK](https://img.shields.io/badge/Download%20APK-Latest%20Release-brightgreen?style=for-the-badge&logo=android)](https://github.com/Ashutosh-rajput/Vinyl/releases/latest/download/app-release.apk)

Scan, import, and play all the songs stored on your device. Search or explore Top Downloads from YouTube and JioSaavn to download 320kbps tracks permanently into your offline library. Stream millions of songs on demand. Since live stream providers can occasionally experience downtime, downloading favorites is always recommended. But even while streaming, Vinyl automatically caches up to 50 songs so you can play them offline without internet!




<p align="center">
    <a href="https://github.com/Ashutosh-rajput/Vinyl/releases/latest">
        <img src="https://img.shields.io/github/v/release/Ashutosh-rajput/Vinyl?include_prereleases&logo=github&style=for-the-badge&label=Latest%20Release" alt="Latest Release">
    </a>
    <a href="https://github.com/Ashutosh-rajput/Vinyl/releases">
        <img src="https://img.shields.io/github/downloads/Ashutosh-rajput/Vinyl/total?logo=github&style=for-the-badge" alt="Total Downloads">
    </a>
    <img src="https://img.shields.io/badge/Android-11%2B-green?style=for-the-badge&logo=android" alt="Android 11+">
    <img src="https://img.shields.io/badge/Flutter-100%25-blue?style=for-the-badge&logo=flutter" alt="Flutter">
</p>


### ☕ Support the Developer
Maintaining **Vinyl**, implementing new features (like PulseIQ and high-fidelity streaming), and keeping up with API updates takes continuous effort. Your support helps keep this project independent, ad-free, and privacy-focused!


### International

[![Ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/D3B527VH3X)


### India

[![Pay via UPI](https://img.shields.io/badge/🇮🇳%20Pay%20via%20UPI-sliceashutoshrajput%40ybl-FFB000?style=for-the-badge)](https://tinyurl.com/Vinyl-support-upi)


<p align="left">
  <img src=".github/assets/UPI_QR.png" alt="UPI QR Code" width="250">
</p>

---

### ⭐ Other Ways to Support

Financial support isn't the only way to help! You can also support the project for free:

- **Star the Repo**: Give this project a ⭐ on [GitHub](https://github.com/Ashutosh-rajput/flutter_application_1) — it helps more people discover Vinyl.
- **Report Bugs & Suggest Features**: Open an [Issue](https://github.com/Ashutosh-rajput/flutter_application_1/issues) if you spot any bugs or have ideas for new features.
- **Spread the Word**: Share Vinyl with friends and on social media!
- **Contribute Code**: Pull requests are always welcome! Check out our contribution guidelines to get started.

## ✨ Features Overview


### ⚡ 320 kbps Streaming & Discover Feed
- **High-Bitrate Streaming**: Stream millions of tracks in 320 kbps audio quality.
- **Curated Discover Modules**: Explore Trending Songs, New Releases, Editorial Charts, Recommended Albums, and Artist Spotlights.
- **Universal In-Stream Search**: Look up songs, albums, and artists with instant debounced search.
- **Offline Stream Cache**: Automatically caches the last 50 streamed tracks in local storage for instant offline replay with zero buffering and zero data usage.
- **Multi-Language Streaming Support**: Browse and stream music in Hindi, Punjabi, English, Tamil, Telugu, Bhojpuri, and more.


### 📥 Download Manager & Offline Library
- **Dual-Source Audio Downloader**: Download high-quality tracks directly from streaming and YouTube.
- **Tag Preservation & High-Res Artwork**: Automatic embedding of metadata, album covers, and source indicators.
- **Local Storage Library**: Fast folder scanning, custom folder inclusion/exclusion, and playlist management.

### 🎤 Synchronized & Plain Lyrics Support
- **Multi-Source Engine**: Automated lyrics resolution with fallbacks across LRCLIB, online providers, and local audio file tags.
- **Time-Synced Auto-Scroll**: Real-time scrolling that follows the playback position.
- **Interactive Lyrics Controls**: Tap any lyric line to jump directly to that timestamp, adjust time synchronization offsets (± ms), and adjust font sizes.
- **Local SQLite Lyrics Caching**: Lyrics are cached offline after the first lookup for instant loading without an internet connection.


### 🧠 PulseIQ On-Device Recommendation Engine
- **100% Privacy-First**: All taste profiling, playback habits, and recommendation scoring occur strictly on-device with zero cloud telemetry.
- **High-Intent Search Play Signal**: Songs actively searched for and played are boosted to the top of suggestion seeds.
- **Continuous 30-Day Half-Life Decay**: Distinguishes authentic completions from rapid skips, ensuring preferences evolve naturally.
- **MMR (Maximal Marginal Relevance) Diversity Filtering**: Balances relevance and variety to prevent artist saturation while reserving discovery slots for new artists.


### 🎧 Core Audio & Playback Experience
- **Infinite Playback Queue**: Music never stops. As you near the end of your queue, PulseIQ automatically fetches and enqueues matching recommendations without interruptions.
- **Smart Song Radio**: Instant one-tap radio mode to generate continuous personalized queues based on any track.
- **Unified 3-Dot Options Sheet**: Clean, uncluttered song tiles with quick access to Start Radio, Add to Queue, Add to Playlist, Toggle Favorites, and Download.
- **Dynamic 24-Bar Audio Wave Visualizer**: Smooth animated visualizer on the full player screen with an ON/OFF toggle in Settings.
- **Playing Equalizer Bars**: Real-time 4-bar equalizer indicator in song lists to highlight the actively playing track.
- **Lockscreen & Notification Controls**: Native Android media controls, artwork display, and status bar actions powered by `just_audio_background`.






### 🎨 Personalization & System
- **AMOLED Dark Mode & Accent Colors**: Custom color themes, including the signature **Teal (#2BC5B4)** accent.
- **Smart Sleep Timer**: Gracefully stop playback when the timer expires or at the end of the currently playing song.
- **Variable Playback Speed**: Control tempo from 0.5x to 2.0x.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (Dart 3.x)
- **State Management**: BLoC & Cubit (`flutter_bloc`)
- **Audio Engine**: `just_audio`, `audio_service`, `just_audio_background`
- **Database & Persistence**: `drift` (SQLite ORM) & `shared_preferences`
- **Networking**: `dio`, `http`, `youtube_explode_dart`
- **Recommendation Engine**: Custom PulseIQ Engine (MMR Diversity, Collaborative Graph, Time Decay)
- **UI & Typography**: `google_fonts` (Outfit), `cached_network_image`, `flutter_svg`

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19.0 or higher)
- Android Studio / VS Code with Flutter extension
- Android SDK (API Level 21+ supported; target API Level 34+)

### Build & Run

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Ashutosh-rajput/Vinyl.git
   cd vinyl
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run on connected device / emulator**:
   ```bash
   flutter run
   ```

4. **Build Release APK**:
   ```bash
   flutter build apk --release
   ```

---

> *"Thank you for being part of the Vinyl journey and supporting open-source software!"* ❤️



## 📄 License

This project is licensed under the [MIT License](LICENSE).
