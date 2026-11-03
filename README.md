# SmartMove 🛒⏱️

> **A local market price intelligence, multi-channel shopping assistant, and deterministic decision platform for transparent everyday commerce in Nigeria.**  
> *Built for the Meta AI Hackathon with Flutter, Riverpod, Cloud Supabase, and Meta AI Models.*

[![Build Split Android APKs](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml/badge.svg)](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Database-3ECF8E?logo=supabase)](https://supabase.com)
[![Meta AI](https://img.shields.io/badge/Meta%20AI-Voice%20%26%20Vision%20%26%20Spark-0668E1?logo=meta)](https://about.meta.com)
[![Tests](https://img.shields.io/badge/Tests-275%2B%20Passing-success?logo=checkmarx)](test/)
[![Analyzer](https://img.shields.io/badge/Analyzer-0%20Issues-success)](lib/)

---

## ⚡ What is SmartMove?

In emerging markets like Lagos, Ibadan, and Abeokuta, the cheapest sticker price across town often ends up being the most expensive option once transport fares, transit hours, and packaging variances (*mudu, paint rubber, derica, bag*) are accounted for.

**SmartMove** unifies multimodal AI, crowd price intelligence, and a deterministic decision engine so shoppers find the best total outlay and trade-offs in seconds:
- **Multimodal AI Assistant:** Plan shopping from free-form text, photos of products or handwritten paper notes, and spoken voice notes in **Nigerian Pidgin, Yoruba, Hausa, Igbo, and English**.
- **Inference Lab:** Mathematically simulates 4 competing plan candidates (*Lowest Outlay, Fewest Stops, Express Speed, Cashflow Saver*) under custom budgets and transport constraints without hallucinated pricing.
- **Multi-Criteria Seller Matrix:** Compares Local Open Markets, Neighborhood SMB Stores, and Online Retailers across landed costs, delivery fees, dynamic GPS distance, quality, and return protection.
- **Live In-App Trader Chat:** Direct persistent two-way negotiation between shoppers and verified merchants with offer proposals and stock confirmations.
- **Verified Seller Portal & SuperAdmin:** Empowers market traders with 1-tap stock toggles, AI quote refinement, and stall geolocations, supervised by a role-based moderation panel.

---

## 🛡️ Core Safeguards & Architecture

```
User Input (Text / Voice / Image)
       │
       ▼
Secure Supabase Edge Function (meta-ai-proxy)
  • Zero embedded client secrets
  • Automated PII scrubbing (phone / email)
       │
       ▼
Meta AI Models (muse-voice-transcribe, muse-spark, vision)
       │
       ▼
Flutter Client Application
  • Editable Proposal Review (no unconfirmed state changes)
  • Deterministic DecisionEngine arithmetic (pure Dart calculations)
  • Resilient offline NLP fallback when cloud services are unreachable
```

---

## 📱 Split APK Downloads & Quick Install

SmartMove produces lightweight **split APKs per ABI** (~20 MB vs ~60 MB universal build) to minimize download costs:

| Architecture | Target Devices | APK File |
| :--- | :--- | :--- |
| **`arm64-v8a`** | **Modern Android Phones (TECNO, Infinix, Samsung, Xiaomi, Pixel)** | `app-arm64-v8a-release.apk` |
| **`armeabi-v7a`** | Older 32-bit Android phones | `app-armeabi-v7a-release.apk` |
| **`x86_64`** | PC Android Emulators & ChromeOS | `app-x86_64-release.apk` |

```bash
# Build split APKs locally
./build_apk.sh --split

# Install on connected device
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 💻 Local Development Setup

```bash
# 1. Clone & enter repository
git clone https://github.com/GentzofGod/SmartMove.git && cd SmartMove

# 2. Configure .env with Supabase & Meta keys
echo "SUPABASE_URL=https://your-project.supabase.co" >> .env
echo "SUPABASE_ANON_KEY=your-anon-key" >> .env
echo "META_APP_ID=your-meta-app-id" >> .env
echo "META_CLIENT_TOKEN=your-meta-client-token" >> .env

# 3. Get dependencies and verify
flutter pub get
flutter analyze
flutter test

# 4. Launch app
flutter run
```

---

## 👥 Roles & Permissions

- **Guest:** Browse unified catalog, view price benchmarks, rehearse plans in Inference Lab.
- **Customer:** Report community prices, chat and bargain with sellers, apply for trader verification.
- **Trader:** Manage stall listings, 1-tap stock switch (`In Stock`/`Out of Stock`), receive customer inquiries.
- **SuperAdmin:** Approve/revoke trader applications, manage categories dynamically, resolve flagged price anomalies.

---

## 📄 License & Attribution
Developed for the **Meta AI Hackathon**. Licensed under the [MIT License](LICENSE).
