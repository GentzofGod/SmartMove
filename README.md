# SmartMove 🛒⏱️

> **A local market intelligence, multi-channel errand planning, and multimodal decision simulation platform for smart everyday spending and transparent local commerce.**  
> *Built for the Meta AI Hackathon with Flutter, Riverpod, Cloud Supabase, and Meta Muse Models.*

[![Build Split Android APKs](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml/badge.svg)](https://github.com/GentzofGod/SmartMove/actions/workflows/build-split-apks.yml)
[![Flutter](https://img.shields.io/badge/Flutter-3.29.0-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.12-0175C2?logo=dart)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Cloud%20Database-3ECF8E?logo=supabase)](https://supabase.com)
[![Meta AI](https://img.shields.io/badge/Meta%20AI-Muse%20Spark%20%26%20Voice%20%26%20Vision-0668E1?logo=meta)](https://about.meta.com)
[![Tests](https://img.shields.io/badge/Tests-222%20Passing-success?logo=checkmarx)](test/)
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

## 🚀 Recent Features & Major Upgrades

SmartMove has undergone continuous iterative development and real-world hardening, delivering enterprise-grade commerce workflows, vernacular acoustic intelligence, and seamless offline reliability:

### 1. 🏪 Comprehensive Seller Inventory & Listing Management
- **1-Tap Stock Switch**: Directly on each commodity listing card in the seller portal, market traders can toggle between **`In Stock`** (green badge) and **`Out of Stock`** (red badge) with a single tap, updating the live community feed instantly.
- **Modify Existing Quotes**: Full editing modal (`Icons.edit_outlined`) enabling verified sellers to update commodity names, prices, units, brands, categories, and descriptive notes with automated recalculation of standardized unit prices (₦/kg, ₦/L).
- **Delete Listings with Confirmation**: Safe deletion modal preventing accidental de-listing while enabling quick cleanup of discontinued inventory.
- **Mandatory Category Classification**: Clear classification across `Groceries`, `Electronics`, `Pharmacy`, and `Others` on all listing forms and card tags.

### 2. ✨ AI Auto-Fill & Refinement for Seller Listings
- **One-Tap Listing Assistant (`Icons.auto_awesome`)**: Powered by [`MetaAiService.refineSellerListing()`](lib/core/services/meta_ai_service.dart), traders can paste raw colloquial notes (*e.g., "50kg Mama Gold rice 85000 fresh stock in Bodija warehouse"*) or tap AI Refine.
- **Intelligent Field Extraction & Normalization**: Automatically standardizes:
  - **Commodity / Product Name** (*e.g., Parboiled Rice*)
  - **Standardized Packaging Unit** (*e.g., 50kg bag, 25L jerrycan, paint rubber, 1 derica, piece*)
  - **Category** (*Groceries*, *Electronics*, *Pharmacy*, *Others*)
  - **Price Amount** (safely separating prices from metric units like `1.5L` or `500mg`)
  - **Recognized Commercial Brands** (*Mama Gold, Golden Penny, Dangote, Binatone, Emzor, May & Baker, Panadol, Peak, Haier, etc.*)
  - **Polished Trader Notes** for shopper clarity.

### 3. 🖼️ Rich Commodity & Product Imagery (`CommodityImageWidget`)
- **Visual Commodity Representation**: Integrated across `ProductDetailSheet`, `DiscoverScreen`, `HomeScreen`, and `SellerPortalScreen`.
- **Curated Nigerian Market Photography**: High-resolution photography for staple local commodities including *Rice, Brown Beans, Garri/Cassava, Palm Oil, Vegetable Oil, Yam/Tuber, Fresh Tomatoes, Onions, Eggs, Titus Fish, Chicken/Meat, Cookers, Blenders, and Cement*.
- **Graceful Vector Fallbacks**: Tinted category badges with contextual icons when operating offline or when custom photography is unavailable.
- **Remote Custom Network Image Support**: Allows verified stores and online platforms to supply external product image URLs.

### 4. 🌍 Real-Time Multilingual Localization (16 Languages, No Restart)
- **Instant Reactive Translation**: Swaps the entire app interface dynamically without requiring an app restart or reload across **16 supported languages**:
  - *English, Nigerian Pidgin, Yoruba, Hausa, Igbo, French, Spanish, Arabic, German, Portuguese, Swahili, Hindi, Chinese, Bengali, Japanese, Russian*.
  - Powered by Riverpod reactive state (`appLanguageProvider`) and localized string matrices (`AppStrings`).
- **First-Launch Language Preference Onboarding**: Prompts new users to select their preferred regional dialect or international language upon first opening the app, persisted locally via `SharedPreferences`.
- **Full Legal & Regulatory Translation**: Terms & Conditions, Privacy Policy, and NDPA/FCCPC data protection charters are fully translated and accessible in offline mode.

### 5. 📶 Offline Session Persistence & SharedPreferences Upgrades
- **Persistent User Sessions**: User accounts, trader profiles, and roles persist reliably across app restarts and network dropouts via robust local `SharedPreferences` caching, eliminating unintended fallbacks to Guest mode.
- **Offline Mode Readiness**: Saved price observations, catalog items, and regulatory screens are accessible without an active internet connection.

### 6. 📍 High-Precision Geolocation & Reverse Geocoding
- **Granular Seller Location Capture**: Automatically detects exact stall numbers, line names, market hubs, and streets (*e.g., "Stall B4, Grain Section, Bodija Market"*), replacing raw latitude/longitude numbers with readable physical addresses for buyer navigation.
- **High-Accuracy GPS Scanning**: Captures 7-decimal place coordinates (`NUMERIC(10, 7)`) for accurate walking and transit route calculations.

### 7. 🛡️ Store Profile Verification & Governance Workflow
- **Marketplace Credibility Protection**: Modifications to approved seller business names, stall locations, or market hubs submit a verification request (`store_edit_requests`) to prevent fraudulent bait-and-switch behavior.
- **SuperAdmin Moderation Pipeline**: Administrators review and approve profile changes before they reflect publicly on live listings.
- **Isolated Seller Portal Entry**: Seller portal management is housed securely on the authenticated trader profile, eliminating misplaced portal buttons from customer discovery feeds.

### 8. 🔒 Token-Based Password Recovery
- **6-Digit OTP Token Verification**: Replaces fragile email confirmation links with quick, high-deliverability 6-digit numeric tokens stored securely in `public.password_resets`.

### 9. 🎙️ Acoustic Dialect Normalizer & Speech Accuracy Fix
- **Intelligent Phonetic Normalizer**: Solves mobile OS STT acoustic bias (where Nigerian terms are forced into English lookalikes like *garri* $\rightarrow$ *"carry"*, *shinkafa* $\rightarrow$ *"she car far"*, *kongo* $\rightarrow$ *"can go"*) by running an acoustic phonetic cleanser before search processing.

### 10. 🎨 UI Polish, Accessibility & Safe Area Protection
- **Vertically Expandable Homepage Prompt**: Replaced redundant "Custom Prompt" buttons with a clean, dynamic multi-line text input (`minLines: 1`, `maxLines: 5`).
- **Device Safe Area Optimization**: Polished top and bottom padding across heterogeneous notch, hole-punch, and navigation bar configurations.
- **Sign-Out Confirmation Dialog**: Prevents accidental session termination.
- **Streamlined User-Friendly Terminology**: Replaced technical model codenames (*Muse Spark*, *Muse Vision*, *Muse Voice*) with intuitive, user-friendly labels (*AI Planning Assistant*, *Smart Vision Scanner*, *Voice Assistant*).

### 11. 🗺️ Interactive Open-Source OpenStreetMap & Leaflet Map View (`SellerLocationMapSheet`)
- **Zero API Key Requirement**: Built using `flutter_map` and `latlong2` rendering standard, fast, open-source OpenStreetMap raster tiles (`https://tile.openstreetmap.org/{z}/{x}/{y}.png`) without Google Maps billing or restrictive API keys.
- **Interactive Stall & Route Visualization**: Renders buyer GPS location (`Icons.person_pin`), seller stall location (`Icons.location_on_rounded`), and a dashed connection polyline with live geodesic distance estimation (km).
- **Physical Stall Navigation Controls**: Includes in-map Zoom (+/-), Recenter on Seller Stall, Turn-by-Turn GPS navigation launcher (`geo:` / `google.navigation:` / Google Maps web fallback), and instant attribution badging.

### 12. 📍 Direct In-App Seller Selection, Physical Stall Navigation & Chat-and-Buy
- **Locate on Map & Chat & Buy Action Row**: Accessible directly on every commodity listing card across `CommunityScreen`, `DiscoverScreen` (`ProductDetailSheet`), and the live multi-vendor comparison sheets.
- **Instant Trader Negotiation**: 1-tap launcher initializing `TraderNegotiationSheet` with pre-filled commodity name, standardized unit, base price, and seller identity for instant bargaining or stock confirmation.

### 13. 🧠 Meta AI In-App Verified Sellers Database Combing Priority
- **Verified Trader Inventory First**: When Meta AI conducts price research on the Homepage or Explore tab (`MetaAiService.conductLiveAiVendorComparison` / `queryAiPriceResearch` / `parseToProposal`), the system combs through the active in-app verified sellers database first.
- **Top-Ranked Placement**: Local verified sellers are placed at the very top of vendor options with a distinctive `SmartMove Verified Seller` badge and green physical market indicator before external online stores like Jumia, Konga, or Jiji appear.
- **AI Recommendation Highlights**: AI synthesized advice explicitly prioritizes verified in-app market traders for immediate physical pickup and direct bargaining over external online delivery lead times.

### 14. 📑 Streamlined Community Feed (Two-Segment Tabs & Single-Line Category Filter Chips)
- **Eliminated Double Line Filter**: Removed the cumbersome stacked channel and source filter rows in favor of a clean, modern layout.
- **Role-Separated 2-Segment Control**: Two top-level tabs displaying live item counts:
  - **`Verified Sellers (N)`**: Listings from registered market traders with confirmed stalls.
  - **`Community Reports (N)`**: Crowdsourced price reports submitted by community shoppers.
- **Single-Line Category Filter Chips**: Clean horizontal category row (`All`, `Groceries`, `Electronics`, `Pharmacy`, `Others`) with contextual category icons, instant counts, and empty-state resilience.

### 15. 🚩 Comprehensive Product & Seller Reporting System (`ReportModalSheet`)
- **Report Inaccurate or Abusive Listings**: Accessible via dedicated Report flag buttons across both `CommunityScreen` listings and `ProductDetailSheet` quotes.
- **Granular Issue Categorization**:
  - **Product Issues**: Inaccurate or fake prices, phantom / permanently out-of-stock items, counterfeit / damaged goods, packaging unit discrepancies, and incorrect category tags.
  - **Seller / Stall Issues**: Refusal to honor advertised prices, fake / non-existent stall addresses, unreachable / invalid phone numbers, rude or unprofessional trader conduct, and suspected scammer / imposter activity.
- **Direct Moderation Queue Pipeline**: Flags listings as anomalies in `CommunityNotifier.reportListing(...)`, highlights reported items with an alert banner (`Flagged for Moderation`), and submits detailed reports with reporter attribution directly to the SuperAdmin console.

### 16. 👤 Community Posts Poster Name Attribution
- **Contributor Transparency**: Every crowdsourced community price observation prominently displays the contributor's name (`Posted by: <name>`) alongside the location and timestamp.
- **Attribution Input Field**: General shoppers can customize their poster attribution name when submitting new price reports via the Community addition sheet.
- **Distinction from Verified Merchants**: Verified seller inventory cards clearly bear `Verified Seller: <businessName>` to distinguish official merchant listings from crowdsourced shopper reports.

### 17. 🚪 Verified Seller Community Posting Restriction & Portal Routing
- **Enforced Merchant Integrity**: Verified and approved traders are restricted from publishing inventory through general community channels to ensure all merchant listings maintain verified stall geolocations, official business metadata, and live stock tracking.
- **Automatic Portal Redirect**: When an approved seller taps the add button in the Community tab, a dedicated "Verified Seller Portal Notice" dialog guides them to manage and publish their inventory directly within their official **Seller Portal** (`/seller-portal`).

### 18. 🎙️ End-to-End High-Fidelity Audio Recording & Meta Voice Transcription Pipeline
- **Modern Audio Capture (`record: ^7.1.2`)**: Replaced fragile on-device STT with cross-platform native audio recording using `AudioRecorder`.
- **Automated Microphone Permissions**: Verifies and requests Android runtime microphone permission (`android.permission.RECORD_AUDIO`) on-demand when the mic button is tapped.
- **Strict Audio Specification**: Formats recorded audio to **WAV, mono, 24 kHz, 16-bit PCM** (`RecordConfig(encoder: AudioEncoder.wav, sampleRate: 24000, numChannels: 1)`) matching Meta's ASR transcription models.
- **Live Recording Indicator & Elapsed Time**: Displays real-time dynamic amplitude waveforms and ticking elapsed timer (`00:01`, `00:02`...) tracking active session duration.
- **Adaptive Silence & Pause Detection**: Monitors audio amplitude stream (`onAmplitudeChanged`) and auto-stops recording after 2.5s of quiet once speech starts, or immediately when the user taps "Finish".
- **Meta Transcription Endpoint Integration**: Uploads the WAV payload with audio metadata headers to the backend proxy directing to Meta's `muse-voice-transcribe-1.0` ASR endpoint.
- **Editable Chat Input Field Insertion**: Injects the returned transcript directly into the chat input field on the home screen, keeping the input focused and allowing the user to review, edit, or adjust the prompt before sending.

### 19. 🎯 Zero Fake Data & True-to-Life Geolocation Scanning
- **Eliminated False Bodija Coordinates**: Purged hardcoded defaults across the codebase that mistakenly assumed all Nigerian users or sellers were in Ibadan at Bodija Market (`7.4243, 3.9168`), which previously led to jarring synthetic ~66km distance estimates for Abeokuta residents.
- **Granular Multi-City Hub Directory**: Added comprehensive market hubs and coordinates for **Abeokuta** (*Kuto Market, Itoku Market, Omida Market, Lafenwa, Ibara*), **Lagos** (*Mile 12, Oyingbo, Tejuosho, Balogun, Alaba*), **Abuja** (*Wuse 2, Utako*), and **Ibadan** (*Dugbe, Bodija, Oje, Oja Oba, Gbagi*).
- **Cleansed Synthetic Nomenclature**: Completely removed synthetic `"Commercial Hub"` naming in favor of authentic market names and local store areas.
- **Uncalibrated Stall Detection**: When a seller has not yet calibrated precise GPS coordinates, `SellerLocationMapSheet` renders a clear, transparent **`Stall GPS Not Yet Calibrated`** card with one-tap Chat & Buy and Call actions rather than generating artificial pins or misleading distance calculations.

### 20. 🗂️ Dynamic Multi-Tier Commodity Categories & SuperAdmin Category Editor
- **Dynamic Category Administration**: SuperAdmin and Admin users can now create, edit, and delete commodity categories dynamically via dedicated dialogs in the SuperAdmin console (`/superadmin`).
- **Full-Stack Synchronization**: Category modifications update live Riverpod state (`categoriesProvider`), persist directly to Supabase (`categories` table), and cache locally via `SharedPreferences`.
- **Instant Omnichannel Propagation**: Real-time propagation immediately updates category pills on the Discover page, single-line category filter chips on the Community feed, and category dropdowns on the Seller Portal listing sheets.

### 21. 💬 Real Persistent Two-Way Buyer-Seller Chat & Trader Inquiry Inbox
- **Zero Automated Simulations**: Removed canned 600ms fake auto-replies, replacing them with authentic persistent two-way messaging between shoppers and verified merchants.
- **Dual-Layer Persistence**: Powered by Supabase (`negotiation_messages` table) with instant offline cache in `SharedPreferences`.
- **Seller Portal Inquiries Inbox**: Added a dedicated **Customer Inquiries & Live Chat** card in `SellerPortalScreen` where verified traders can review buyer inquiries/offers and reply directly with confirmed pricing and stall directions.

### 22. 🛡️ User-Friendly, Respectful Error Handling & Anomaly Reporting
- **Polite Human-Centered Messaging**: Eliminated raw technical exceptions (`$e`), stack trace dumps, and cryptic toasts across the app.
- **Clear Actionable Guidance**: Polished user feedback across GPS scanning, camera/gallery receipt OCR failures, external navigation launchers, and empty search results.

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

### 5. 💬 In-App Trader Chat & Direct Negotiation
- **Authentic Two-Way Messaging**: Real persistent chat backed by Supabase and local cache—zero simulated auto-replies.
- **Dedicated Seller Inquiries Inbox**: Market traders review customer inquiries, send counter-offers, and confirm stall inventory directly from their Seller Portal.
- Embedded negotiation drawer displays active listing unit rates, counter-offer proposals, and delivery coordination with real-time status tracking.

### 6. 🛡️ Role-Based Access Control & Dedicated SuperAdmin Panel
Strict separation of concerns ensures normal shoppers and guests see only customer-facing workflows, while administrators have a dedicated back-office control panel:
- **Platform Analytics**: Total users, active listings, pending trader applications, and flagged anomalies.
- **Trader Verification**: Review seller documents, market hub assignments, and stall locations to approve or reject trader credentials.
- **Dynamic Category Administration**: Create, edit, and delete commodity categories dynamically with instant live sync across user discovery, community feeds, and merchant portals.
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
SmartMove implements an end-to-end 10-step high-fidelity acoustic pipeline for vernacular speech:
1. **User taps microphone button**: Available directly within the chat prompt input field as a prefix/suffix action or dedicated quick action.
2. **Android requests microphone permission**: Checks `AudioRecorder.hasPermission()`, requesting Android `android.permission.RECORD_AUDIO` if not yet granted.
3. **Flutter starts recording audio**: Initializes `AudioRecorder` using `package:record/record.dart`.
4. **Live recording indicator & elapsed time**: Renders dynamic pulsing waveform bars and ticking timer (`00:01`, `00:02`...) tracking active session duration.
5. **Finish tap or pause detection**: Users can tap Finish, or the silence detection listener automatically concludes the session upon detecting a 2.5s pause after speech.
6. **WAV mono 24 kHz 16-bit PCM conversion**: The audio stream is finalized into an uncompressed WAV format (`AudioEncoder.wav`, 24,000 Hz sample rate, single mono channel, 16-bit PCM).
7. **Upload recording to backend**: The client sends the WAV binary payload to the secure backend proxy (`MetaAiService.transcribeAudio`).
8. **Backend sends to Meta transcription endpoint**: Dispatches payload with audio metadata to Meta's `muse-voice-transcribe-1.0` ASR model.
9. **Receive transcript & insert into chat input field**: Delivers the high-accuracy vernacular transcript directly into `_inlinePromptController.text`.
10. **User reviews & edits before sending**: The text field remains active and focused with cursor positioned at the end, allowing full user review and editing before tapping Send.

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
│  • name, category   │  • product_id        │  • user_id, status        │
│  • lowest_price     │  • seller_name       │  • business_name, stall   │
│  • best_seller      │  • price, unit       │  • market_hub, channel    │
│  • standard_unit    │  • channel, verified │  • phone, submitted_at    │
│  • standardized_rate│  • category, in_stock│  • latitude, longitude    │
├─────────────────────┼──────────────────────┼───────────────────────────┤
│      profiles       │ store_edit_requests  │      password_resets      │
│  • id (auth.uid)    │  • id (UUID)         │  • id (UUID)              │
│  • email, role      │  • seller_id         │  • email                  │
│  • business_name    │  • proposed_business │  • token (6-digit OTP)    │
│  • stall_location   │  • proposed_hub/stall│  • expires_at, used       │
│  • latitude, long   │  • status, reviewer  │  • created_at             │
├─────────────────────┼──────────────────────┼───────────────────────────┤
│   price_anomalies   │    app_audit_logs    │   commodity_categories    │
│  • id (UUID)         │  • id (UUID)         │  • id, name, icon         │
│  • observation_id    │  • action_type       │  • is_active, display_rank│
│  • anomaly_reason    │  • actor_id          │  • created_at             │
│  • is_resolved       │  • created_at        │                           │
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

### Test Suite Coverage (202 Automated Tests across 26 Test Suites):
- **[`seller_listing_management_ai_refine_and_images_test.dart`](test/seller_listing_management_ai_refine_and_images_test.dart)**: 1-tap stock switch, listing modifications, safe deletions, AI listing refinement, and visual commodity image rendering.
- **[`realtime_language_switch_test.dart`](test/realtime_language_switch_test.dart)**: Instant reactive language switching across 16 languages without app restart, and first-launch preference onboarding.
- **[`offline_session_and_legal_screens_test.dart`](test/offline_session_and_legal_screens_test.dart)**: Offline session persistence, SharedPreferences caching, and offline legal screen rendering.
- **[`voice_mic_seller_reapply_settings_cleanup_test.dart`](test/voice_mic_seller_reapply_settings_cleanup_test.dart)**: Microphone audio capture, approved seller access without reapplication loops, and settings UI cleanup.
- **[`database_role_sync_and_appliance_resolution_test.dart`](test/database_role_sync_and_appliance_resolution_test.dart)**: Appliance classification (Electric Cookers vs grain Rice), zero fake trader fallbacks, and database role synchronization.
- **[`lathe_spare_parts_and_outlet_resolution_test.dart`](test/lathe_spare_parts_and_outlet_resolution_test.dart)**: Hardware and spare parts resolution without erroneous supermarket fallbacks.
- **[`live_web_search_grounding_test.dart`](test/live_web_search_grounding_test.dart)**: Grounded live web search for fresh commodities and authentic platform deep-links.
- **[`profile_and_settings_functional_test.dart`](test/profile_and_settings_functional_test.dart)**: Profile updates, seller applications, store profile modifications, and sign-out confirmation dialogs.
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
- **[`commodity_catalog_schema_test.dart`](test/commodity_catalog_schema_test.dart)**: Database schema validation, category definitions, and pricing audit trail models.
- **[`commodity_comparison_service_test.dart`](test/commodity_comparison_service_test.dart)**: Standardized price conversions across bulk and retail package formats.
- **[`location_service_test.dart`](test/location_service_test.dart)**: High-accuracy GPS geocoding and market hub distance calculations.
- **[`seller_application_test.dart`](test/seller_application_test.dart)**: Trader credential verification and approval status lifecycles.
- **[`guide_service_test.dart`](test/guide_service_test.dart)**: Interactive user guide walkthroughs and contextual tooltips.
- **[`splash_screen_test.dart`](test/splash_screen_test.dart)**: App cold-boot initialization, session restore, and first-launch routing.
- **[`ai_proposal_review_sheet_test.dart`](test/ai_proposal_review_sheet_test.dart)**: AI proposal presentation and layout compliance across compact mobile viewports.

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
│   │   ├── localization/
│   │   │   └── app_language.dart             # 16-language reactive localization matrix
│   │   ├── presentation/widgets/
│   │   │   └── commodity_image_widget.dart   # Curated commodity photography & fallback badges
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
│       ├── seller/presentation/          # Seller portal, inventory stock & AI quote refiner
│       ├── admin/presentation/           # SuperAdmin control panel & moderation tools
│       └── profile/presentation/         # User roles, trader application & settings
├── supabase/
│   ├── functions/
│   │   └── meta-ai-proxy/                # Secure server edge proxy for Meta API
│   ├── migrations/                       # PostgreSQL database migrations & RLS policies
│   └── schema.sql                        # Core table definitions & constraints
└── test/                                 # 202 automated unit and widget test suites (26 files)
```

---

## 📄 License & Hackathon Attribution
Developed for the **Meta AI Hackathon**.  
Licensed under the [MIT License](LICENSE).
