# Butter Knife — Engineering Plan

The following senior-level plan organizes the work required to ship the Butter Knife production application on Flutter with GetX, Dio, and supporting libraries. Each ticket includes a clear acceptance bar so work can be tracked in Jira or Linear.

## Epic A — Core Architecture & State

### A1. App scaffolding and DI
- Create feature-first structure: `features/{browser,extract,gallery,download}/…`, `core/{network,storage,util}/…`.
- Wire GetX bindings for controllers: `BrowserController`, `ExtractionController`, `DownloadController`, `SettingsController`.
- Define sealed result types and app-wide error model.
- **Acceptance:** App builds and runs. Controllers injectable via bindings; global error model usable across layers.

### A2. Models & serialization
- Define `MediaItem { id, type(image|video), url, normalizedUrl, width?, height?, bytes?, contentLength?, thumbnailUrl?, isSelected }`.
- Define `ExtractionResult { pageUrl, found: List<MediaItem>, skipped: SkippedStats }`.
- Add JSON serialization and equality.
- **Acceptance:** Round-trip tests pass; equality works for dedupe.

## Epic B — WebView + Page Pipeline

### B1. WebView screen with URL bar
- Implement a URL entry screen with validation and an **Open in WebView** action.
- Use `webview_flutter` with custom user-agent toggle.
- **Acceptance:** User can open arbitrary pages; navigation controls (back/forward/reload) work.

### B2. JS bridge for DOM extraction
- Inject JS to collect:
  - `<img src/srcset>` best candidate URLs
  - `<source>` under `<picture>`
  - `<video poster>` and `<video><source src>` URLs
  - Filter obvious favicon links via `<link rel="icon">` and common paths.
- Send extracted candidates through `JavascriptChannel` back to Flutter.
- **Acceptance:** For a test page, bridge returns arrays of candidate URLs with element tag and attributes.

### B3. Process overlay
- Add full-screen overlay with progress states: `Scanning DOM → Normalizing URLs → Probing sizes → Building grid`.
- **Acceptance:** Overlay appears during processing and hides on completion or error.

## Epic C — URL Normalization, Probing, and Filtering

### C1. URL normalization & de-duplication
- Resolve relative URLs against page URL, strip fragments, sort query keys for canonical comparison.
- De-duplicate by normalized URL.
- **Acceptance:** Unit tests cover relative paths, query noise, and duplication.

### C2. Content probing (HEAD/GET)
- Use Dio to fetch `Content-Type` and `Content-Length` with HEAD; fall back to lightweight GET on servers that block HEAD.
- Classify as `image/*` or `video/*`.
- Handle `data:` and `blob:` URLs (skip or attempt fallback snapshot if feasible).
- **Acceptance:** Items include `contentLength` and `type`. Unknown or streaming types are flagged.

### C3. Filter rules
- Exclude:
  - Favicons by rel/type and common file names (`/favicon.ico`, `apple-touch-icon*`).
  - Images where `contentLength < 10 KB`.
- Keep: images (jpg/png/webp/gif/svg*) and videos (mp4/webm/mov*) with known content length or direct file URL.
- Mark HLS/DASH (`.m3u8`, `.mpd`) as **streaming** and not downloadable in v1.
- **Acceptance:** Test fixture verifies correct keep/skip decisions.

## Epic D — UI: Grid, Selection, and Details

### D1. Grid gallery
- Lazy grid with thumbnails. Use network thumbnails; for videos show play overlay icon.
- Quick select/deselect; counter of selected items; **Download All** button.
- **Acceptance:** Stable 60fps on 50–200 items; selection state persists while navigating.

### D2. Item details sheet
- Bottom sheet: preview, file type, approximate size, source tag, open in browser.
- **Acceptance:** Tapping tile opens sheet; links work.

### D3. Empty/error states
- Empty state with suggestions (try another page).
- Error state with retry.
- **Acceptance:** Visuals meet design spec.

## Epic E — Download Manager

### E1. Download orchestration
- Implement a queued download manager with concurrency limit (default 3), retry policy (e.g., 2 retries, exponential backoff), pause/cancel.
- Per-item progress and overall progress.
- **Acceptance:** Can download 20–100 items reliably with progress and cancellation.

### E2. Background downloads (Android)
- Integrate `flutter_downloader` or keep foreground with `WorkManager` fallback.
- Persist queue across app restarts.
- **Acceptance:** Kill app mid-download; queue resumes automatically on reopen.

### E3. Save destinations
- Android: MediaStore (Pictures/ButterKnife and Movies/ButterKnife), handle scoped storage on Android 10+.
- iOS: Save to Photos album (Butter Knife).
- Optional setting: save to app documents instead of gallery.
- **Acceptance:** Files visible in Photos/Gallery; album created if missing.

## Epic F — Permissions & Platform Integration

### F1. Runtime permissions
- Android: manage `READ_MEDIA_IMAGES/VIDEO` (Android 13+), legacy fallback with `WRITE_EXTERNAL_STORAGE` if required on older versions.
- iOS: request `PHPhotoLibraryAddOnly` permission and add Info.plist strings.
- **Acceptance:** Permission flows are clear, localized, and handled gracefully if denied.

### F2. App settings deep links
- Provide "Open Settings" when permission is permanently denied.
- **Acceptance:** Works on Android and iOS.

## Epic G — Settings & Preferences

### G1. Settings screen
- Toggle: minimum image size (default 10 KB), user-agent (mobile/desktop), concurrency, include SVG, include GIF/video autoplay thumbnails.
- **Acceptance:** Settings persist via `shared_preferences` and apply on next run.

## Epic H — Logging, Telemetry, and Privacy

### H1. Local activity log
- Local ring buffer log for debugging (no PII, no external telemetry). Export log as text for support.
- **Acceptance:** Log captures page URL host, counts, durations, and errors without storing content.

### H2. Privacy review
- Confirm no third-party analytics for v1. Document data handling in a privacy policy stub.
- **Acceptance:** Policy text prepared for store submission.

## Epic I — Testing & QA

### I1. Unit tests
- URL normalization, filter logic, content-type classification, HEAD fallback logic.
- **Acceptance:** ≥90% coverage for core utilities.

### I2. Integration tests
- Happy path on a controlled local HTML fixture.
- Large page stress test (200+ media items).
- Permission denial and recovery.
- **Acceptance:** All tests pass in CI.

### I3. Golden tests
- Grid view (empty, partial, full), error screens.
- **Acceptance:** Golden diffs stable across platforms.

## Epic J — Store Readiness

### J1. App icons, branding, and screenshots
- Generate adaptive icons and iOS asset catalog.
- Capture screenshots that show URL entry, WebView, processing overlay, grid, and downloads.
- **Acceptance:** Assets meet Play/App Store requirements.

### J2. Store metadata
- Finalize description, keywords, privacy labels, and permission rationale.
- **Acceptance:** Metadata files ready for submission.

## Implementation Notes (Senior Pointers)
- Packages: `webview_flutter`, `dio`, `html`, `get`, `path_provider`, `permission_handler`, `flutter_downloader` (Android), `photo_manager` or platform save helpers for iOS, `cached_network_image` for grid thumbs.
- Performance: Use `compute` or isolates to parse HTML and to run HEAD probes on a throttled pool. Batch HEADs (e.g., 10 at a time) to avoid rate-limits.
- Favicons: Exclude via DOM rel checks and filename heuristics, then fall back to size threshold.
- Videos: Ship v1 with direct file URLs only (`.mp4`, `.webm`, `.mov`). Mark HLS/DASH as **Streaming** and do not download in v1.
- Resilience: Some sites block HEAD; fall back to ranged GET with `Range: bytes=0-0` to infer content type when safe.
- Storage: On Android 10+, prefer MediaStore insert with `RELATIVE_PATH`. On iOS, use `PHPhotoLibrary` via plugin to create album and save.
- Legal: Add a warning dialog on first run to respect copyrights and site terms.

## Definitions of Done (DoD) Summary
- Processes a real-world page with mixed media and returns a deduplicated grid in under ~4 seconds on a mid-range device.
- Correctly excludes favicons and images under the size threshold.
- Downloads succeed for at least 95% of direct image/video URLs across a 100-item batch.
- All critical paths covered by tests; no crashes on permission denials or network loss.
- Store metadata and privacy text are complete and accurate.

