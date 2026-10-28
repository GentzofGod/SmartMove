# SmartMove 🛒⏱️

> **A local market intelligence, errand planning, and decision simulation app for smart everyday spending and time-management.**  
> *Built for the Meta AI Hackathon with Flutter, Riverpod, Cloud Supabase, and Meta Muse Models.*

[![Build Split Android APKs](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml/badge.svg)](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Database-3ECF8E?logo=supabase)](https://supabase.com)
[![Meta AI](https://img.shields.io/badge/Meta%20AI-Muse%20Spark%20%26%20Voice-0668E1?logo=meta)](https://about.meta.com)

---

## 📖 Overview

In emerging markets and fast-paced urban hubs like Lagos, Nigeria, daily shopping and errands involve complex, non-obvious trade-offs. The cheapest individual grocery price at a distant market may actually result in a more expensive trip once transit fares and travel times are factored in.

**SmartMove** solves this by unifying three core capabilities into a single seamless mobile application:
1. **Community Market Intelligence**: Tracks crowdsourced product prices across local vendors with transparent source labels (simulated demo, community-reported, or trader-confirmed).
2. **Intelligent Errand Planner**: Combines shopping items with time-sensitive non-shopping errands (such as collecting a package before 2:00 PM).
3. **Decision Rehearsal Engine (Decision Lab)**: Simulates alternative travel itineraries side by side under different budgets, transport fares, time limits, and stop constraints—explaining the trade-offs so users can make confident decisions before leaving home.

---

## 🚀 Key Features

### 1. 🏠 Home — "Your Next Decision"
- **1-Tap Trip Rehearsal**: Pre-loaded with the primary hackathon demo scenario:  
  *“I have ₦15,000. I need rice, eggs, tomatoes, and cooking oil. I also need to collect a package before 2 PM. Help me plan everything.”*
- **Spoken Request Button**: Instant microphone input powered by Meta Muse Voice Transcribe.
- **Errand & Schedule Overview**: Visualizes today's itinerary, progress, and upcoming deadlines.
- **Budget Bar**: Displays remaining planned cash and allocated transit expenses.

### 2. 🏪 Market — Product & Price Discovery
- Browse local food staples, unit prices, and seller locations across Lagos markets (Mile 12, Oyingbo, Tejuosho, Mushin).
- **Explicit Data Source Disclosure**: Every observation is clearly labelled as:
  - `Demo Data (Simulated)`
  - `Community Reported`
  - `Trader Provided`
  - `Trader Confirmed`
- Add crowdsourced community price observations with vendor name, location, and optional notes.
- Flag stale or suspicious reports to protect community data integrity.

### 3. 📋 Errands — Practical Itinerary Builder
- Group shopping lists with service errands (package pickups, bank visits, dry cleaning).
- Assign priority levels (`High`, `Medium`, `Low`) and strict completion deadlines.
- Quantity adjusters (`+` / `-`) for instant recalculation.
- Step-by-step progress tracking (mark stops complete as you go).

### 4. 🔬 Decision Lab — Signature Scenario Rehearsal
Compare 4 distinct candidate plans side by side:

| Plan | Objective | Estimated Cost | Est. Duration | Stops | Key Trade-Off |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Plan A** | **Lowest Estimated Total Cost** | ₦13,400 | 2.5 hrs | 3 stops | Lowest grocery outlay (₦11,600). Splits purchases across 2 markets to get best unit prices, trading higher travel time. |
| **Plan B** | **Lowest Transport & Fewest Stops** | ₦13,800 | 1.8 hrs | 2 stops | Consolidates errands into single commercial hub. Cuts transit fare to ₦1,200 and saves 42 mins. |
| **Plan C** | **Shortest Estimated Duration** | ₦14,200 | 1.2 hrs | 2 stops | Express commercial run. Maximizes speed to complete pickup errand before deadline. |
| **Plan D** | **Delay Non-Urgent Purchases (Budget Safety)** | ₦7,360 | 1.0 hr | 2 stops | Delays oil & tomatoes to protect immediate cashflow. **Makes zero unsupported claims that prices will fall.** |

#### Interactive "What If?" Simulation Controls:
- **Total Budget Slider**: ₦8,000 to ₦30,000.
- **Transport Fares Slider**: ₦500 to ₦4,000.
- **Available Time Slider**: 1.0 hr to 6.0 hrs.
- **Max Stops Limit Slider**: 2 to 5 stops.
- **Optional Cost of Time Slider**: ₦0 to ₦2,000 / hr (weights faster plans higher).
- **Delay Non-Urgent Purchases Switch**: Cashflow preservation toggle.

---

## 🤖 Meta AI Integration & Architectural Safeguards

SmartMove uses Meta models where they provide real, demonstrable value, governed by strict engineering safeguards:

### 🎙️ Meta Muse Voice Transcribe (`muse-voice-transcribe-1.0`)
- **Push-to-Talk Speech Recognition**: Captures spoken requests and voice notes with animated soundwave indicators.
- **Immediate Text Fallback**: Transcriptions are displayed in an editable field before submission. If speech input is unavailable, users can type requests directly.

### 💡 Meta Muse Spark (`muse-spark-1.3` / `muse-spark-open`)
- **Structured Request Extraction**: Extracts budget, shopping items (names, quantities, units, and estimated unit prices), and deadline errands into strict, validated data models.
- **Clarification Questioning**: Detects missing budgets or unstated deadlines and prompts the user with interactive suggestion chips.
- **Records-Grounded Trade-Off Explainer**: Explains plan differences in clear, natural language referring **only** to authoritative calculated numbers (item costs, transit fares, stops, duration). **The model never invents prices or travel facts.**
- **Conversational Follow-Up Interpreter**: Understands natural-language preference refinements such as:
  > *"I want to spend less on transport even if the shopping bill is slightly higher."*  
  Interprets user intent, highlights Plan B, and prompts user confirmation to apply the new constraints.

### 🛡️ Required AI Safeguards (Hackathon Compliance)
1. **AI Output as Proposal**: All model extractions open an **AI Proposal Review Sheet** allowing users to adjust quantities, edit budgets, or discard the proposal. **The model never mutates user data without confirmation.**
2. **Deterministic Arithmetic**: All totals, sums, constraint checks, and plan rankings are executed in application Dart code ([`DecisionEngine`](file:///c:/Users/GENT/StudioProjects/socialflow/lib/core/services/decision_engine.dart)).
3. **Server-Side API Secrets**: Meta API keys and tokens are never embedded in the Flutter client. They are proxied through a secure backend/edge server ([`supabase/functions/meta-ai-proxy/`](file:///c:/Users/GENT/StudioProjects/socialflow/supabase/functions/meta-ai-proxy/index.ts)).
4. **Data Privacy (PII Scrubbing)**: Email addresses and Nigerian/international phone numbers are automatically stripped before payload transmission.
5. **100% Offline Demo Resilience**: High-fidelity local fallback parser guarantees seamless presentations during live judging even without an internet connection.

---

## 📱 Split APKs & Device Installation (Android)

To optimize download sizes for users in emerging markets and low-bandwidth mobile connections, SmartMove is built using **split APKs per ABI**.

### Why Split APKs?
Instead of a single bloated ~60MB universal APK containing native libraries for all architectures, splitting reduces the APK size down to **~15MB - 20MB** per device!

| Target Architecture | Target Devices | Generated APK Name |
| :--- | :--- | :--- |
| **`arm64-v8a`** | **Modern Android Phones (TECNO KJ5, Samsung, Xiaomi, Infinix, Pixel, etc.)** | `app-arm64-v8a-release.apk` |
| **`armeabi-v7a`** | Older 32-bit Android phones | `app-armeabi-v7a-release.apk` |
| **`x86_64`** | PC Android Emulators & ChromeOS | `app-x86_64-release.apk` |

### 🛠️ Building Split APKs Locally
Run the following command from the project root:
```powershell
flutter build apk --release --split-per-abi
```
The resulting split APKs will be output to:
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk
├── app-armeabi-v7a-release.apk
└── app-x86_64-release.apk
```

### 📲 Installing on Your Phone (e.g. TECNO KJ5)
Connect your device via USB with USB Debugging enabled:
```powershell
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
*Or copy `app-arm64-v8a-release.apk` directly to your phone via USB file transfer or Google Drive and tap to install.*

---

## ⚙️ Automated GitHub Actions CI/CD Workflow

We have configured an automated GitHub Actions pipeline in [`.github/workflows/build-split-apks.yml`](file:///c:/Users/GENT/StudioProjects/socialflow/.github/workflows/build-split-apks.yml).

### Features:
- Automatically triggers on every `push` to `main` and on version tags (`v*`).
- Supports manual triggering via **Run workflow** (`workflow_dispatch`) with a choice between `release` and `debug` builds.
- Automatically compiles split APKs on cloud Ubuntu runners (bypassing any local Gradle download or DNS network timeouts).
- Uploads downloadable split APK artifacts (`smartmove-arm64-v8a`, `smartmove-armeabi-v7a`, `smartmove-x86_64`).
- Automatically creates a GitHub Release when a tag (*e.g.*, `v1.0.0`) is pushed.

### How to Download Pre-Built APKs from GitHub:
1. Go to your repository on GitHub.
2. Click on the **Actions** tab.
3. Select the latest run of **Build Split Android APKs**.
4. Scroll to the **Artifacts** section at the bottom.
5. Download **`smartmove-arm64-v8a`** for modern phones (TECNO, Infinix, Samsung) and install directly!

---

## 💻 Local Development Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.24.0)
- [Java JDK 17](https://adoptium.net/)
- Android Studio / Android SDK (Platform 34+)

### 1. Clone the repository
```bash
git clone https://github.com/GentzofGod/SmartMove.git
cd SmartMove
```

### 2. Environment Configuration
Create a `.env` file in the root directory (refer to `.env.example`):
```env
# Cloud Supabase Configuration
SUPABASE_URL=https://ljhkptuvbtysuhddicsj.supabase.co
SUPABASE_ANON_KEY=sb_publishable_your_key_here

# Meta App Configuration
META_APP_ID=4820239824866512
META_CLIENT_TOKEN=431b591db92df606f6e695c8be332d4d
```

### 3. Install packages & run tests
```bash
flutter pub get
flutter test
```

### 4. Run the app on your connected device
```bash
flutter run
```

---

## 🔧 Troubleshooting Local Gradle Network Issues

If you encounter:
```
Could not download protos-31.0.2.jar: No such host is known (dl.google.com)
```
This is caused by an intermittent local DNS resolution failure or network block to `dl.google.com`.

**Fixes:**
1. **Use GitHub Actions (Recommended)**: Push to GitHub or run the GitHub Actions workflow to build in the cloud where Google Maven repositories download with 10Gbps connectivity.
2. **Switch DNS**: Change your PC's DNS to Google DNS (`8.8.8.8` and `8.8.4.4`) or Cloudflare (`1.1.1.1`).
3. **Flush DNS**:
   ```powershell
   ipconfig /flushdns
   ```
4. **Clean Gradle Cache**:
   ```powershell
   cd android
   ./gradlew clean --refresh-dependencies
   cd ..
   ```

---

## 📂 Project Structure

```
smartmove/
├── .github/
│   └── workflows/
│       └── build-split-apks.yml    # GitHub Actions Split APK CI/CD pipeline
├── lib/
│   ├── core/
│   │   ├── models/                 # PlanCandidate, Errand, Product, AiProposal
│   │   ├── services/
│   │   │   ├── decision_engine.dart    # Authoritative deterministic math engine
│   │   │   ├── meta_ai_service.dart    # Muse Spark & Muse Voice Transcribe layer
│   │   │   └── supabase_data_service.dart # Cloud Supabase synchronization
│   │   ├── state/
│   │   │   └── app_state.dart          # Riverpod state notifiers
│   │   └── theme/
│   │       ├── app_colors.dart         # Design palette & contrast standards
│   │       └── app_theme.dart          # Material3 themes & typography
│   └── features/
│       ├── home/                   # Scenario cards & voice transcribe modal
│       ├── market/discover/        # Price comparison & crowdsourced submissions
│       ├── errands/                # Itinerary list & task completion
│       ├── decision_lab/           # Compare plans, What If? sliders, Presets
│       └── profile/                # User settings & offline indicators
├── supabase/
│   ├── functions/
│   │   └── meta-ai-proxy/          # Server-side secrets proxy for Meta API
│   └── migrations/                 # PostgreSQL schema & price tables
└── test/
    ├── decision_engine_test.dart   # Deterministic arithmetic & plan tests
    └── meta_ai_service_test.dart   # Muse AI extraction, safeguards & voice tests
```

---

## 📄 License
This project is developed for the **Meta AI Hackathon**.
Licensed under the [MIT License](LICENSE).
