# Butter Knife

Butter Knife is a production-grade Flutter application that finds and saves images or videos from any web page. The project bundles store-ready copy, a full engineering roadmap, and implementation principles so the team can move straight into delivery.

## Documentation Map

- [`docs/STORE_DESCRIPTION.md`](docs/STORE_DESCRIPTION.md) — Complete App Store / Play Store metadata, including feature highlights and usage workflow.
- [`docs/ENGINEERING_PLAN.md`](docs/ENGINEERING_PLAN.md) — Senior-level implementation plan broken down into epics, tickets, acceptance bars, and execution notes.

## Store Snapshot

| Field | Value |
| --- | --- |
| Name | **Butter Knife — Bulk Image & Video Saver** |
| Short description | Collect images and videos from any web page. Preview, pick, and save. |
| iOS subtitle | Bulk media downloader |
| Primary permission rationale | Photos/Storage access is required so downloads can be written to the device gallery. |

Refer to the store description document for the full-length marketing copy, feature breakdown, and usage workflow.

## Product Highlights

- **One-tap processing** with a dedicated button and overlay feedback while the DOM is analyzed.
- **Smart filtering** that skips sub-10 KB assets and favicons so the gallery only shows meaningful media.
- **Video awareness**, capturing `<video>` posters and sources alongside images.
- **Grid-first browsing** that supports bulk selection plus single-item saves.
- **Download flexibility**, including "Download All" and per-item saves with a persistent history.

## End-to-End User Flow

1. Launch the app and paste a page URL or open it directly in the in-app WebView.
2. Tap **Process** and watch the overlay progress through DOM scanning, normalization, and probing.
3. Review the resulting media grid, select any subset, or choose **Download All**.
4. Save items to the Photos/Gallery destination that matches the platform defaults.
5. Return to the landing screen and repeat for the next page.

## Technology Stack & Key Dependencies

Butter Knife targets Android 8+ and iOS 14+ using Flutter (stable channel) with the following production libraries:

| Area | Package(s) | Purpose |
| --- | --- | --- |
| State & navigation | [`get`](https://pub.dev/packages/get) | Binding-driven state management and navigation. |
| Networking | [`dio`](https://pub.dev/packages/dio) | Robust HTTP client for HEAD/GET probing with interceptors and retry support. |
| Web content | [`webview_flutter`](https://pub.dev/packages/webview_flutter) | Embeds the WebView with JavaScript bridge support. |
| DOM parsing | [`html`](https://pub.dev/packages/html) | Parses markup when we need to inspect responses outside the WebView. |
| Persistence | [`path_provider`](https://pub.dev/packages/path_provider), [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Resolve filesystem paths and persist user preferences such as thresholds and concurrency. |
| Permissions | [`permission_handler`](https://pub.dev/packages/permission_handler) | Unified runtime permission flows across Android and iOS. |
| Downloads | [`flutter_downloader`](https://pub.dev/packages/flutter_downloader) (Android), platform channels, [`photo_manager`](https://pub.dev/packages/photo_manager) | Queue management, background support, and saving media into gallery destinations. |
| Media presentation | [`cached_network_image`](https://pub.dev/packages/cached_network_image) | Efficient thumbnail caching in the grid. |

The implementation plan calls out version-specific behaviors (e.g., Android scoped storage, iOS Photos album creation). Always verify plugin compatibility against the targeted Flutter stable release before upgrading.

## Engineering Execution

The full roadmap in [`docs/ENGINEERING_PLAN.md`](docs/ENGINEERING_PLAN.md) is organized as a series of epics that cover architecture, WebView integration, media extraction, filtering, UI, downloads, platform integration, settings, telemetry, QA, and store readiness. Each ticket has explicit acceptance criteria so teams can ship incremental, production-quality slices without placeholders or stubs.

Key delivery expectations include:

- Media extraction and normalization complete within ~4 seconds on mid-range hardware.
- Download success rate ≥95% for direct media URLs across large batches.
- No crashes or dead-ends when permissions are denied or network connectivity fluctuates.
- Comprehensive automated test coverage for all critical utilities and golden UI states.

## Privacy & Compliance Stub

Butter Knife does not include third-party analytics in v1. All network requests are initiated by the user for explicit downloads. Photos/Storage permission prompts explain the need to save media locally. Teams should extend this stub into a full privacy policy before submission.

## [The 17 Commandments of Quality Code]

1. Write code for humans first, machines second.
2. Choose clarity over cleverness.
3. Document the why, not just the what.
4. Be ruthlessly consistent.
5. Test relentlessly—code without tests is broken by default.
6. Get every change reviewed by another engineer.
7. Keep functions and modules small and focused.
8. Anticipate failure and handle errors gracefully.
9. Limit the reach of your data.
10. Leave the code cleaner than you found it.
11. Name things with purpose and clarity.
12. Favor simple control flow.
13. Automate what can be automated.
14. Be deliberate and sparse with dependencies.
15. Do not solve problems that do not exist.
16. Treat all external data as hostile.
17. Understand the cost of your operations.


## Developer Utilities

To derisk the extraction stack we ship a Python toolkit in the `butterknife/` directory. It implements the URL normalization, filtering, probing, and download orchestration used in the mobile app plan. Engineers can exercise the pipeline end-to-end from the command line while Flutter UI work progresses.

### Environment setup

1. `python -m venv .venv`
2. `source .venv/bin/activate`
3. `pip install -r requirements-dev.txt`

### Verification commands

- `pytest` — runs the unit and integration-style tests in `tests/`.
- `ruff check .` — enforces the Python style and catches common issues.
- `python -m butterknife https://example.com` — prints the structured extraction result for a page.
- `python -m butterknife https://example.com --download` — downloads all accepted assets into `./downloads`.

Structured logs follow the schema described in the guidance and include the human-readable `[The 17 Commandments of Quality Code]` derived line for traceability.

## Next Steps

1. Stand up the Flutter project scaffold following the feature-first structure described in the engineering plan.
2. Implement Epic A tickets to solidify dependency injection, models, and the global error surface.
3. Progress through Epics B–J, validating each slice with the specified acceptance criteria and automated tests.
4. Prepare store assets, privacy copy, and release notes so the submission package is ready when development completes.

