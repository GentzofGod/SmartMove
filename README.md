# SmartMove 🛒⏱️

> **A local market intelligence, multi-channel errand planning, and multimodal decision simulation platform for smart everyday spending and transparent local commerce.**  
> *Built for the Meta AI Hackathon with Flutter, Riverpod, Cloud Supabase, and Meta Muse Models.*

[![Build Split Android APKs](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml/badge.svg)](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Database-3ECF8E?logo=supabase)](https://supabase.com)
[![Meta AI](https://img.shields.io/badge/Meta%20AI-Muse%20Spark%20%26%20Voice%20%26%20Vision-0668E1?logo=meta)](https://about.meta.com)
[![Tests](https://img.shields.io/badge/Tests-150%20Passing-success?logo=checkmarx)](test/)
[![Analyzer](https://img.shields.io/badge/Analyzer-0%20Issues-success)](lib/)

---

## 📖 Executive Overview

In emerging markets and fast-paced urban centers like Lagos and Ibadan, Nigeria, everyday shopping and errand execution involve complex, non-obvious trade-offs. The lowest shelf price at an open market across town may actually be more expensive once transit fares, travel duration, traffic delays, and fulfillment quality are factored in. Furthermore, local packaging varies widely—from paint buckets and mudu basins to sacks and crates—making price comparisons opaque.

**SmartMove** solves this by unifying crowdsourced price intelligence, multimodal Meta AI, deterministic itinerary planning, and multi-criteria seller evaluation into a single high-performance mobile application:

1. **Multimodal Meta AI Assistant**: Understands user intent from natural-language prompts, photos of handwritten paper shopping lists, and spoken vernacular voice notes across 5 Nigerian dialects.
2. **Deterministic Decision Lab**: Simulates competing candidate travel plans under varying budgets, transport fares, time limits, and stop constraints—grounded purely in verified arithmetic without hallucinated pricing.
3. **Multi-Criteria Seller Matrix**: Compares Local Open Markets, SMB Neighborhood Stores, and Online Retailers across landed costs, delivery fees, transit duration, quality grades, reputation, and return policies.
4. **Transparent Market Intelligence**: Standardizes prices per base unit (₦/kg, ₦/L, ₦/piece), tracks crowdsourced seller observations, and provides genuine historical price trendlines.
5. **Role-Based Commerce & Moderation**: Empowers verified market traders to publish live inventory and negotiate directly with shoppers, while a dedicated SuperAdmin control panel oversees content moderation, anomaly detection, and seller verification.

---

## 🌟 Core Pillars & Key Features

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                               SMARTMOVE PLATFORM                                 │
├─────────────────────┬──────────────────────┬─────────────────────────────────────┤
│   MULTIMODAL AI     │    DECISION LAB      │         DISCOVER & COMMERCE         │
│  • Custom Prompt    │  • Plan Candidates   │  • Standardized Unit Pricing (₦/kg) │
│  • Paper Note Scan  │  • "What If?" Math   │  • Multi-Channel Landed Outlay      │
│  • Dialect Voice STT│  • Route Feasibility │  • Live In-App Trader Chat          │
│  • Meta AI Research │  • Cashflow Guard    │  • Dedicated SuperAdmin Panel       │
└─────────────────────┴──────────────────────┴─────────────────────────────────────┘
```

### 1. 🤖 Prompt-First Multimodal AI Assistant
- **Conversational Planning Box**: Positioned front-and-center. Users express custom errands, items, and budgets freely without canned foodstuffs or static presets.
- **Vision Paper Note Scanner (`muse-spark-vision-1.0`)**: Scans photos of handwritten paper market lists, notebook pages, and paper receipts, automatically extracting recognized commodities, quantities, and units into structured errand proposals.
- **Multi-Dialect Voice Transcribe (`muse-voice-transcribe-1.0`)**: Captures push-to-talk speech across **Nigerian English**, **Nigerian Pidgin**, **Yoruba**, **Igbo**, and **Hausa** with automatic language identification, audio playback, and English translation.
- **Transparent Error Reporting**: Eliminates silent synthetic fallbacks. Model failures or unparseable inputs report user-friendly error banners with one-tap recovery shortcuts directly to the Decision Lab.
- **Meta AI Commodity Price Research**: Researches current market benchmark ranges and active platforms for any entered commodity on demand.

### 2. 🔬 Decision Lab — Signature Itinerary Simulation
Compare 4 candidate plans calculated deterministically by the application engine:

| Plan | Strategic Objective | Key Optimization | Trade-Off Explained |
| :--- | :--- | :--- | :--- |
| **Plan A** | **Lowest Estimated Total Cost** | Wholesale multi-stop purchases | Lowest item outlay; trades higher transit time across multiple market stops. |
| **Plan B** | **Lowest Transport & Fewest Stops** | Consolidated commercial hub | Minimizes transit fares and walking steps by grouping purchases into a single center. |
| **Plan C** | **Shortest Estimated Duration** | Express commercial routing | Prioritizes speed and direct transit to beat errand deadlines. |
| **Plan D** | **Delay Non-Urgent Purchases** | Cashflow & budget safety | Defers non-essential shopping items to stay strictly within available cash limits. |

#### Interactive "What If?" Simulation Sliders:
- **Total Budget Slider**: ₦5,000 to ₦100,000.
- **Transport Fares Slider**: ₦200 to ₦10,000.
- **Available Time Slider**: 0.5 hr to 8.0 hrs.
- **Max Stops Limit Slider**: 1 to 6 stops.
- **Hourly Cost of Time Slider**: ₦0 to ₦5,000/hr (weights faster routes higher).
- **Delay Non-Urgent Toggle**: Real-time cashflow preservation switch.

### 3. ⚖️ Multi-Criteria Seller & Fulfillment Matrix
Evaluates seller choices across 3 primary fulfillment channels:
- **Local Market Hubs** (*e.g., Bodija, Mile 12, Oyingbo*): Direct wholesale pricing, physical goods inspection, ₦0 delivery fee.
- **SMB Neighborhood Stores** (*e.g., Local Grocers, Pharmacies*): Packaged shelf standards, rapid 1-2 hour neighborhood bike dispatch.
- **Online Retailers** (*e.g., Jumia, Konga, Supermart*): Tamper-evident factory packaging, escrow buyer protection, doorstep delivery.

Evaluates and re-ranks options across 6 weighted criteria based on user priority:
- `Balanced Value` (Composite balance of price, distance, and trust).
- `Lowest Outlay` (Strict landed cost minimization including delivery fees).
- `Doorstep & Speed` (Zero travel distance and doorstep fulfillment).
- `Quality & Trust` (Highest seller reputation, grade certification, and return guarantees).

### 4. 🏪 Discover & Market Price Intelligence
- **Standardized Unit Rates**: Normalizes diverse local units (paint buckets, dericas, mudus, crates, bunches, tubers) into standard rates (₦/kg, ₦/L, ₦/piece) for honest cross-market comparisons.
- **Grounded Price History**: Draws real historical price trendlines strictly when 3 or more verified time-stamped observations exist. When data is limited, it provides an honest empty state rather than inventing fake curves.
- **Category & Channel Filters**: Browse seamlessly by `'All'`, `'Groceries'`, `'Electronics'`, `'Pharmacy'`, or `'Others'`.

### 5. 💬 In-App Trader Chat & Negotiation
- Shoppers can make direct price offers and check stock availability with market traders in real time.
- Embedded negotiation drawer displays active listing unit rates, counter-offer proposals, and delivery coordination.

### 6. 🛡️ Role-Based Access Control & Dedicated SuperAdmin Panel
Strict separation of concerns ensures normal shoppers and guests see only customer-facing workflows, while administrators have a dedicated back-office control panel:
- **Platform Analytics**: Total users, active listings, pending trader applications, and flagged anomalies.
- **Trader Verification**: Review seller documents, market hub assignments, and stall locations to approve or reject trader credentials.
- **Content Moderation & Anomaly Resolution**: Inspect user-flagged price outliers and resolve price discrepancies.
- **Catalog Management**: Directly edit, verify, or deactivate marketplace listings.
- **Database Role Synchronization**: Safe admin role syncing with Cloud Supabase.

---

## 🤖 Meta AI Integration & Architectural Safeguards

```
                      ┌────────────────────────────────────────┐
                      │            USER INPUT LAYER            │
                      │  Prompt Text | Voice Audio | Note Photo│
                      └───────────────────┬────────────────────┘
                                          │
                                          ▼
                      ┌────────────────────────────────────────┐
                      │       SECURE BACKEND PROXY / EDGE      │
                      │  • Strips PII (Phone numbers, emails)  │
                      │  • Signs requests with server secrets  │
                      └───────────────────┬────────────────────┘
                                          │
                                          ▼
                      ┌────────────────────────────────────────┐
                      │            META MUSE MODELS            │
                      │  • muse-voice-transcribe-1.0 (Dialects)│
                      │  • muse-spark-vision-1.0 (Paper Notes) │
                      │  • muse-spark-1.3 / open (Extraction)  │
                      └───────────────────┬────────────────────┘
                                          │
                                          ▼
                      ┌────────────────────────────────────────┐
                      │          APPLICATION CLIENT            │
                      │  • AI Proposal Review Sheet (No silent │
                      │    state mutations)                    │
                      │  • Deterministic DecisionEngine math   │
                      │  • User-friendly error reporting       │
                      └────────────────────────────────────────┘
```

### 🎙️ Meta Muse Voice Transcribe (`muse-voice-transcribe-1.0`)
- Transcribes spoken audio with push-to-talk waveforms.
- Auto-detects dialects and vernacular phrasing across West African languages:
  - **Nigerian English** (`en-NG`)
  - **Nigerian Pidgin** (`pcm-NG`)
  - **Yoruba** (`yo-NG`)
  - **Igbo** (`ig-NG`)
  - **Hausa** (`ha-NG`)
- Provides immediate English translation and audio playback confirmation.

### 📷 Meta Muse Spark Vision (`muse-spark-vision-1.0`)
- Optical recognition for physical shopping notes, receipts, and market scraps.
- Parses handwritten line items, units, and quantities into clean shopping item records.
- Allows immediate editing in the scanner review sheet before submission.

### 💡 Meta Muse Spark (`muse-spark-1.3` / `muse-spark-open`)
- Extracts structured budgets, shopping items, and non-shopping deadline errands.
- Generates natural-language trade-off explanations grounded exclusively in verified calculations.

### 🛡️ Five Hackathon Compliance Safeguards
1. **AI Output as Proposal**: All model extractions open an editable **Proposal Review Sheet**. The model never mutates user plans or budgets without explicit user approval.
2. **Deterministic Arithmetic**: All totals, sums, constraint checks, and candidate plan rankings are computed in application Dart code ([`DecisionEngine`](lib/core/services/decision_engine.dart)).
3. **Zero Embedded Secrets**: Meta API keys and tokens are never bundled inside the client binary. Requests route through a secure edge proxy ([`supabase/functions/meta-ai-proxy/`](supabase/functions/meta-ai-proxy/index.ts)).
4. **Automated PII Scrubbing**: Phone numbers and email addresses are automatically sanitized before sending prompts to external APIs.
5. **User-Friendly Error Handling**: Network errors, empty inputs, or malformed responses present clear, respectful error dialogs and direct action shortcuts rather than falling back to hardcoded mock foodstuffs.

---

## 👥 User Roles & Permissions Matrix

| Capability / Screen | Guest | Customer | Trader | Admin | SuperAdmin |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Browse Catalog & Discover Prices | ✅ | ✅ | ✅ | ✅ | ✅ |
| Custom AI Prompt, Voice & Note Scan | ✅ | ✅ | ✅ | ✅ | ✅ |
| Decision Lab Plan Rehearsal | ✅ | ✅ | ✅ | ✅ | ✅ |
| Submit Community Price Observation | ❌ | ✅ | ✅ | ✅ | ✅ |
| In-App Trader Negotiation Chat | ❌ | ✅ | ✅ | ✅ | ✅ |
| Apply for Trader Verification | ❌ | ✅ | — | — | — |
| Manage Store Stock & Listing Prices | ❌ | ❌ | ✅ | ✅ | ✅ |
| Review & Approve Trader Applications| ❌ | ❌ | ❌ | ❌ | ✅ |
| Resolve Anomaly Flags & Moderation | ❌ | ❌ | ❌ | ❌ | ✅ |
| SuperAdmin Control Panel Access | ❌ | ❌ | ❌ | ❌ | ✅ |

---

## 🗄️ Database Architecture & Cloud Supabase

SmartMove uses **Cloud Supabase** (PostgreSQL with Row Level Security) for persistent real-time storage:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SUPABASE POSTGRESQL SCHEMA                      │
├─────────────────────┬──────────────────────┬───────────────────────────┤
│      products       │  price_observations  │    seller_applications    │
│  • id (UUID/Text)   │  • id (UUID)         │  • id (UUID)              │
│  • name, category   │  • product_id        │  • user_id                │
│  • lowest_price     │  • seller_name       │  • business_name          │
│  • best_seller      │  • price, unit       │  • market_hub, channel    │
│  • standard_unit    │  • channel, verified │  • phone, status          │
│  • standardized_rate│  • standardized_rate │  • submitted_at           │
├─────────────────────┼──────────────────────┼───────────────────────────┤
│      profiles       │    price_anomalies   │      app_audit_logs       │
│  • id (auth.uid)    │  • id (UUID)         │  • id (UUID)              │
│  • email, role      │  • observation_id    │  • action_type            │
│  • business_name    │  • anomaly_reason    │  • actor_id, target_id    │
│  • seller_channel   │  • is_resolved       │  • created_at             │
└─────────────────────┴──────────────────────┴───────────────────────────┘
```

- **Row Level Security (RLS)**: Enforces role boundaries so users can only modify their own submissions, traders can manage their assigned listings, and only SuperAdmins can approve applications or resolve moderation flags.
- **Clean Empty States**: The UI cleanly handles empty database tables with helpful onboarding messages rather than seeding fake foodstuffs.

---

## 🧪 Testing & Quality Assurance

SmartMove is built with test-driven discipline. Every feature, service, and screen is backed by automated tests:

```bash
flutter test
```

### Test Suite Coverage (150 Automated Tests):
- **[`decision_engine_test.dart`](test/decision_engine_test.dart)**: Deterministic multi-plan calculations, budget constraint enforcement, and cashflow delay logic.
- **[`meta_ai_service_test.dart`](test/meta_ai_service_test.dart)**: Natural language prompt parsing, AI proposal generation, PII sanitization, and graceful error reporting.
- **[`voice_transcribe_dialect_test.dart`](test/voice_transcribe_dialect_test.dart)**: Dialect detection across Pidgin, Yoruba, Igbo, and Hausa, translation, and push-to-talk recording flows.
- **[`paper_note_scanner_test.dart`](test/paper_note_scanner_test.dart)**: Optical handwritten list extraction, vision parsing, and scanner UI interactions.
- **[`multi_criteria_analysis_test.dart`](test/multi_criteria_analysis_test.dart)**: Landed cost calculation across Local, SMB, and Online channels, delivery fee additions, and priority re-ranking.
- **[`product_detail_sheet_test.dart`](test/product_detail_sheet_test.dart)**: Unit price standardization, single-listing rendering without fake fallbacks, and authentic price history trends.
- **[`discover_screen_test.dart`](test/discover_screen_test.dart)**: Default 'All' category filter chip, commodity research prompt dialog (no hardcoded rice fallback), and live search chip binding.
- **[`superadmin_panel_test.dart`](test/superadmin_panel_test.dart)**: Superadmin access controls, moderation workflows, trader verification approval, and anomaly resolution.
- **[`auth_service_test.dart`](test/auth_service_test.dart)**: Session persistence, role upgrading, and authentication state transitions.
- **[`trader_prioritization_and_outlets_test.dart`](test/trader_prioritization_and_outlets_test.dart)**: In-app trader chat negotiations, counter-offers, and stock inquiry workflows.
- **[`live_catalog_empty_state_test.dart`](test/live_catalog_empty_state_test.dart)**: Clean UI empty states when products or observations are empty.

---

## 📱 Split APKs & Device Installation (Android)

To optimize download sizes for users in emerging markets with low-bandwidth connections, SmartMove produces **split APKs per ABI**. Splitting reduces the package size down to **~15MB - 20MB** per device compared to ~60MB for universal builds:

| Architecture | Target Devices | Generated APK File |
| :--- | :--- | :--- |
| **`arm64-v8a`** | **Modern Android Phones (TECNO, Infinix, Samsung, Xiaomi, Pixel, etc.)** | `app-arm64-v8a-release.apk` |
| **`armeabi-v7a`** | Older 32-bit Android phones | `app-armeabi-v7a-release.apk` |
| **`x86_64`** | PC Android Emulators & ChromeOS | `app-x86_64-release.apk` |

### 🛠️ Building Split APKs Locally
```bash
flutter build apk --release --split-per-abi
```
Outputs are generated in:
```
build/app/outputs/flutter-apk/
├── app-arm64-v8a-release.apk
├── app-armeabi-v7a-release.apk
└── app-x86_64-release.apk
```

### 📲 Installing on Your Phone
Connect your phone via USB with USB Debugging enabled:
```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```
*Or copy `app-arm64-v8a-release.apk` directly to your phone via USB or Google Drive and tap to install.*

---

## ⚙️ Automated GitHub Actions CI/CD Pipeline

The repository includes an automated workflow in [`.github/workflows/build-split-apks.yml`](.github/workflows/build-split-apks.yml):
- Triggers automatically on every `push` to `main` and on version tags (`v*`).
- Supports manual execution via **Run workflow** (`workflow_dispatch`).
- Compiles split APKs in Ubuntu cloud runners with 10Gbps network connectivity.
- Uploads downloadable split APK artifacts for direct testing.
- Automatically publishes a GitHub Release when a version tag (*e.g.*, `v1.1.0`) is pushed.

---

## 💻 Local Development Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.24.0, tested on 3.29.0)
- [Dart SDK](https://dart.dev) (>= 3.5.0, tested on 3.12.0)
- [Java JDK 17](https://adoptium.net/)
- Android Studio / Android SDK (Platform 34+)

### 1. Clone Repository
```bash
git clone https://github.com/GentzofGod/SmartMove.git
cd SmartMove
```

### 2. Environment Configuration
Create a `.env` file in the project root:
```env
# Cloud Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-publishable-anon-key

# Meta App Configuration
META_APP_ID=your-meta-app-id
META_CLIENT_TOKEN=your-meta-client-token
```

### 3. Install Dependencies & Verify Tests
```bash
flutter pub get
flutter analyze
flutter test
```

### 4. Run Application
```bash
flutter run
```

---

## 📂 Project Directory Structure

```
smartmove/
├── .github/
│   └── workflows/
│       └── build-split-apks.yml          # GitHub Actions Split APK CI/CD
├── lib/
│   ├── core/
│   │   ├── models/                       # Product, PriceObservation, PlanCandidate, Errand
│   │   ├── services/
│   │   │   ├── decision_engine.dart          # Deterministic itinerary math engine
│   │   │   ├── meta_ai_service.dart          # Muse Spark, Voice Transcribe & Vision layer
│   │   │   ├── commodity_comparison_service.dart # Unit normalizer & multi-seller comparisons
│   │   │   ├── auth_service.dart             # RBAC auth and session management
│   │   │   ├── location_service.dart         # Market geocoordinates & distance math
│   │   │   └── supabase_data_service.dart    # Cloud Supabase REST / RLS interface
│   │   ├── state/
│   │   │   └── app_state.dart                # Riverpod state notifiers (Auth, Catalog, Lab)
│   │   └── theme/
│   │       ├── app_colors.dart               # Palette & accessibility contrast standards
│   │       └── app_theme.dart                # Material 3 styling & typography
│   └── features/
│       ├── home/presentation/            # Prompt-first assistant, voice & note scanner
│       ├── discover/presentation/        # Category discovery & product comparison sheet
│       ├── community/presentation/       # Crowdsourced observations & trader negotiation
│       ├── decision_lab/presentation/    # Itinerary candidates & "What If?" sliders
│       ├── itinerary/presentation/       # Live errand checklist & stop progress
│       ├── admin/presentation/           # SuperAdmin control panel & moderation tools
│       └── profile/presentation/         # User roles, trader application & settings
├── supabase/
│   ├── functions/
│   │   └── meta-ai-proxy/                # Secure server edge proxy for Meta API
│   ├── migrations/                       # PostgreSQL database migrations & RLS policies
│   └── schema.sql                        # Core table definitions & constraints
└── test/                                 # 150 automated unit and widget test suites
```

---

## 📄 License & Hackathon Attribution
Developed for the **Meta AI Hackathon**.  
Licensed under the [MIT License](LICENSE).
