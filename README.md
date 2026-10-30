# Pages of Us — Sanctuary for Two 🌿✨

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com)
[![Firebase](https://img.shields.io/badge/Backend-Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Supabase](https://img.shields.io/badge/Realtime-Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com)
[![Release](https://img.shields.io/github/v/release/asmon31148-spec/PAGES-OF-US-?color=E07A5F&label=Latest%20APK)](https://github.com/asmon31148-spec/PAGES-OF-US-/releases/latest)

> **A private, beautifully crafted digital sanctuary for two.**  
> Built with Flutter for seamless real-time intimacy, mutual presence, living memories, and shared atmospheres.

---

## 📲 Download the App

You can download the latest production Android release APK directly:

👉 **[Download Latest APK (GitHub Releases)](https://github.com/asmon31148-spec/PAGES-OF-US-/releases/latest)**

---

## ✨ Features

### 1. 🏡 Stage (Home Sanctuary)
* **Live Partner Presence & Mood Auras:** See each other's live emotional aura and tap to exchange haptic pulse hellos.
* **Dedicated Partner Atmosphere:** Live weather tracking at your partner’s exact location with temperature, sky condition, "feels like", humidity %, and wind speed.
* **Highlight Memory Reel:** Interactive living card reel celebrating couple milestones and shared goals.
* **Milestones & Dreams:** Automatic days-together counter and custom goal tracking.
* **Daily Care & Checkup:** Mutual daily health, hydration, and emotional checkups.
* **Pinned Notes for Today:** Corkboard notes for daily love letters and reminders.
* **Daily Sync (Blind Envelope):** A new deep prompt every day that unseals only when both partners have answered.

### 2. 🌍 Our World (GPS & Real-Time Tether)
* **Real-Time Live Distance:** Precise real-time mutual GPS tethering calculating live driving distance and walking estimates.
* **Dual World Clocks:** Synchronized dual local time and current city presence.
* **Solo Mode Support:** Works smoothly as a personal presence map when unpaired, dynamically transforming into mutual tether upon connecting.
* **Multiple Basemaps:** Seamless switching between ArcGIS Dark Canvas, Esri Satellite Imagery, and OpenStreetMap Standard.

### 3. 📸 Memories & Vault
* **Living Memories Feed:** High-resolution shared photo library organized by milestones, tags, and dates.
* **Voice Whispers:** Audio player with instant local disk caching (<20ms start time) and non-blocking ducking.
* **The Vault:** Secure biometric & PIN-protected private vault for shared confidential notes, codes, and intimate memories.

### 4. 🎵 Music Sanctuary
* **Multi-Stem Atmosphere Mixer:** Layer individual volume levels for rain, ocean waves, fireplace crackle, songbirds, and wind.
* **Custom Couple Playlists:** Create, organize, and curate intimate couple soundscapes.
* **Background Audio:** Full support for continuous background listening outside the app.

---

## 🛠️ Architecture & Tech Stack

* **Framework:** [Flutter 3.x](https://flutter.dev) (Dart 3.x)
* **State Management:** [Provider](https://pub.dev/packages/provider)
* **Realtime Sync & WebSockets:** [Supabase Realtime](https://supabase.com)
* **Data Storage & Rules:** [Cloud Firestore](https://firebase.google.com/docs/firestore)
* **Weather Intelligence:** [Open-Meteo API](https://open-meteo.com) (zero-key worldwide weather forecast)
* **Mapping Engine:** [FlutterMap](https://pub.dev/packages/flutter_map) + [LatLong2](https://pub.dev/packages/latlong2)
* **Audio Engine:** [AudioPlayers](https://pub.dev/packages/audioplayers) + Custom local disk cache service
* **CI/CD:** Automated GitHub Actions build pipeline generating signed release APKs on every release tag/push

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK `>= 3.3.0`
* Android Studio / Android SDK (API 34)
* Java JDK 17

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/asmon31148-spec/PAGES-OF-US-.git
   cd PAGES-OF-US-
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run on connected Android device:**
   ```bash
   flutter run
   ```

4. **Build release APK:**
   ```bash
   flutter build apk --release
   ```

---

## 🔒 Privacy & Security

Pages of Us is built from the ground up to protect couple intimacy:
* Direct encrypted peer-to-peer WebSocket signals.
* Scoped Firestore security rules ensuring only authorized space members can read or write shared data.
* Solo presence privacy toggle for personal location control.

---

<p align="center">
  Made with ❤️ for two souls under the same sky.
</p>
