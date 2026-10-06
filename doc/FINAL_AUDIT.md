# Final technical and monetization audit

Date: 6 October 2026. Updated after consent-form cleanup and native Android/iOS builds. Scope: all tracked package source, tests, example source, package configuration, README and CHANGELOG; resolved Google Mobile Ads plugin configuration and current official guidance. The audited package version is 4.0.0. The user subsequently authorized GitHub source push and pub.dev publication.

## A. Architecture

The package now has a shared fullscreen lifecycle (`FullscreenManager`) with one authoritative manager per fullscreen format in `AdMobKit`. Banner/native resources remain scoped to each mounted placement. Consent and entitlement are shared gates, and one token-only orchestrator owns fullscreen exclusion. PaywallCloseGuard reuses the central interstitial. There is no duplicate internal preload subsystem, remote configuration, Firebase dependency, custom HTTP client, database, or analytics backend.

### Critical / blocker issues fixed

- `show(true)` previously treated an in-flight request as an expired cache, reset its state, and could issue duplicate requests. State checks now precede expiry handling.
- Stale load callbacks could complete another generation's pending future. Native requests now settle once; invalidated requests are discarded before a single coalesced replacement begins.
- Closing callbacks could clear newer resources, and invalidation during presentation could leave a permanently showing manager. Presentation closures own their ad and exact token until they close once.
- Consent was bypassed in fullscreen paths when UMP was disabled, absent from retry/show checks, and stale after privacy forms. All central paths now share initialization + consent + entitlement readiness.
- SDK initialization errors were swallowed and fallback manager access could create request-capable managers before initialization. Errors now propagate; premature access fails explicitly.

### Medium / important issues fixed

- Retries started at two seconds and explicit opportunities could immediately restart exhausted cycles. Defaults are now 30/60/120 seconds, with a five-minute exhaustion gate for fullscreen opportunities.
- Banner/native objects were retained only after success, leaking ownership while loading. Widgets now retain and dispose in-flight native objects, catch load invocation errors, and bound retries.
- Adaptive banners used screen width without tracking actual parent width. Width changes are now measured, coalesced after layout, and trigger a necessary reload.
- Native styles compared by object identity, causing equivalent non-const styles to reload. Styles now compare by value.
- Medium rectangles stretched native creatives. Rendering now preserves native dimensions.
- Fullscreen-induced background events could chain an App Open presentation. Such transitions are now suppressed.
- Repeated paywall close taps and nested paywalls had insufficient ownership protection. Dismissal is single-flight and paywall suppression is counted.
- Declared minimum dependency versions did not support used APIs. Requirements now match the verified plugin baseline.

### Minor issues fixed

- Example reward UI lacked a mounted check; its close button used a context outside the guard.
- Native custom heights could undercut supported template minima.
- Documentation contained incorrect API, expiry, metric, and feature claims.
- Banner/native impression and click callbacks were missing from the optional global event stream.

## B. Ad request efficiency

| Format | Duplicate requests | Preload | Retry | Expiry | Lifecycle | Pro blocking |
| --- | --- | --- | --- | --- | --- | --- |
| Interstitial | Single active native load and cached slot | Eligible startup/config changes; one replacement after consumption; explicit opportunity when idle | 3 bounded retries; exhaustion gate | At most 1 hour; checked on use | Foreground show; exact token ownership | Shared gate; cached eviction, retry cancellation |
| Rewarded | Same shared lifecycle | Same; caller chooses reward opportunity | Same | At most 1 hour | One presentation; earned callback once; failed presentation rejects stale reward | Same; already-earned valid events remain tied to presentation |
| App Open | Same; repeated resume cannot restart active load | Same; background-to-foreground opportunity | Same | At most 4 hours | Cold-start suppression, cooldown, paywall exclusion, no chaining from fullscreen | Same |
| Banner | One resource per mounted placement; stable rebuilds do not reload | On eligible mount; necessary unit/mode/size change | At most 3 failure retries; no wrapper success-refresh timer | Native SDK controls displayed banner refresh | Stable across unrelated lifecycle/rebuilds; adaptive parent sizing | Gate closes and native resource is disposed |
| Native | One resource per placement; equivalent style rebuilds do not reload | On eligible mount; relevant unit/mode/template/style change | At most 3 failure retries; no polling | No hidden offscreen cache or timed replacement loop | Mounted resource ownership; bounded template dimensions | Same as banner |

Separate simultaneously mounted inline placements are separate legitimate inventory. They cannot share one `AdWidget` native view. Host code should use stable placement keys and the facade, not instantiate duplicate standalone managers.

### Request-flow map

**Interstitial:** initialize / consent becomes ready / premium becomes free / relevant config change / paywall mount / explicit preload / eligible idle show → shared gate → reuse fresh cache or current load → one `InterstitialAd.load`. Failure → one backoff timer → same guarded request path. Consumption → dispose exact ad and release exact lease → one replacement. Paywall mount is deduplicated against the same slot.

**Rewarded:** same eligible startup/config/opportunity paths → shared gate/cache/single-flight checks → one `RewardedAd.load`. SDK reward events are deduplicated separately from dismissal. Consumption → one replacement; no reward-related extra load.

**App Open:** same preload paths → one `AppOpenAd.load`. Resume first verifies a real background transition, suppression, readiness, cooldown and mutex. A slow load continues without being restarted or automatically shown later. An expired/empty cache can be primed for a future opportunity.

**Banner:** mount/readiness/unit-mode-size change → shared gate → resolve adaptive container size if needed → construct and retain one native object → `BannerAd.load`. Generation checks ignore old results; invalidation disposes the old resource. Failure → bounded retry. Rebuilds and unrelated settings do not trigger loads. AdMob may independently refresh a successfully displayed banner.

**Native:** mount/readiness/unit-mode-template-style change → shared gate → construct and retain one native object → `NativeAd.load`. Value-equal styles reuse the placement. Generation checks, invalidation and retry follow banner ownership. No preload buffer exists beyond the visible placement.

`show(false)` exits before any mutation/request. Every fullscreen retry rechecks consent and entitlement. Configuration invalidates pending generations; stale callbacks cannot revive old ads or complete a new request. Requests already submitted to native SDKs cannot be recalled by changing Dart state.

## C. Monetization funnel

- **Initialization → consent:** failed initialization is visible and retryable; automatic UMP runs by default. Disabling automatic forms does not grant permission. No request is permitted merely because a consent status enum looks favorable.
- **Consent → request:** configured fullscreen formats preload immediately after initialization and consent resolve. Inline placements react to gate changes, including when mounted before initialization. No unrelated service or custom network call blocks them.
- **Request → match:** deduplication and conservative backoff reduce waste. Google demand, inventory, account eligibility, geography and mediation determine matching; code cannot manufacture fill.
- **Matched ad → ready cache:** successful loads are retained until consumption, expiry or a legitimate invalidation. No widget rebuild or incidental resume evicts a valid fullscreen cache.
- **Cache → show → impression:** foreground checks, exact mutex ownership, callback identity and one-time closure improve reliability. A show result is an accepted attempt, never a synthetic impression. Only native impression callbacks emit impression events.
- **Impression → click:** no click automation, fake taps or touch overlays were added. Banner scaling was removed and native minimum heights enforced. Host placement still needs device validation to avoid clipping and accidental taps.
- **Impression → revenue:** successful impressions create opportunities, not revenue guarantees. Paid-event forwarding was evaluated but not added; it is optional and not necessary to fix request/lifecycle reliability. This wrapper does not infer revenue or transmit analytics.

## D. Slow network review

A slow native load remains the single active request until its SDK callback. There is no speculative timeout replacement or connectivity polling. This avoids overlapping requests during high latency, packet loss or Wi-Fi/mobile handovers. After a real load failure, retries wait 30, 60, then 120 seconds; the configurable policy is capped at five minutes by default. Success resets the failure count. Retry timers are cancelled by invalidation/disposal and eligibility is checked again at execution.

A configuration change cannot cancel a submitted fullscreen native request: its result is discarded, then one pending replacement can start. If a native SDK never supplies a terminal callback, that slot can remain unavailable; launching overlapping watchdog requests would violate the request-efficiency objective. SDK timeout/failure recovery is simulated with delayed callbacks and real failure events, not live network traffic.

Fresh caches survive ordinary foreground/background transitions. Background loads can complete for later use; fullscreen presentation remains foreground-only. App Open does not show merely because a load eventually completes. Expired ads are rejected at use and replaced for a later opportunity; continuous refresh was deliberately avoided. Initialization still awaits SDK readiness and the required consent flow; these are necessary gates, not unrelated latency.

## E. Exact files and fixes

| File | Change |
| --- | --- |
| `lib/src/fullscreen_manager.dart` (new) | Shared single-flight cache/load/retry state, coalesced invalidation, callback identity, close-once lease ownership, show-error handling, expiry limits and event isolation |
| `lib/src/interstitial/interstitial_manager.dart` | Thin SDK adapter using shared lifecycle |
| `lib/src/rewarded/rewarded_manager.dart` | Shared lifecycle plus one-time valid reward handling, including mediation rewards after dismissal |
| `lib/src/app_open/app_open_manager.dart` | Shared lifecycle and counted paywall suppression |
| `lib/src/ad_orchestrator.dart` | Remove ownership-less acquisition/release APIs; only exact token release remains |
| `lib/src/admob_kit.dart` | Central consent/entitlement gate, explicit initialization errors, safe manager access, selective config preloads, widget notifications and SDK event forwarding |
| `lib/src/consent_manager.dart` | Deduplicated UMP flow, fail-closed permission query, privacy requirement/busy/error state, separate form results and generation checks |
| `lib/src/widgets/privacy_consent_button.dart` (new) | Required-only privacy settings entry point; disabled during forms; mounted-safe completion |
| `test/consent_manager_test.dart` (new) | Actual UMP form method calls, initialization gate, parameters, duplicate taps, privacy errors, reset safety and settings button |
| `lib/src/ad_config.dart` | Enable automatic UMP by default |
| `lib/src/retry_policy.dart` | Conservative bounded delays and valid retry numbering |
| `lib/src/inline_ad_retry.dart` (new) | Cancellable bounded placement retry timer |
| `lib/src/banner/banner_ad_widget.dart` | In-flight resource ownership, shared gate, retry, parent-width sizing, stale callback guards, native-size rendering and SDK events |
| `lib/src/banner/banner_manager.dart` | Safe adaptive sizing fallback on platform failure |
| `lib/src/native/native_ad_widget.dart` | In-flight ownership, shared gate, retry, minimum height and native events |
| `lib/src/native/native_templates.dart` | Value equality for styles |
| `lib/src/lifecycle_manager.dart` | Avoid App Open chaining after fullscreen-induced background transitions |
| `lib/src/widgets/paywall_close_guard.dart` | Central slot only, late attachment, counted paywall scope, duplicate-dismiss and mounted guards |
| `example/lib/main.dart` | Test mode/UMP, mounted reward UI, correct descendant context for guard dismissal |
| `pubspec.yaml`, `example/pubspec.yaml` | Verified minimum SDK requirements; package versions unchanged |
| `README.md`, `CHANGELOG.md` | Accurate platform setup, API migration, request semantics and realistic metrics |
| `test/request_efficiency_test.dart` (new) | Shared-format delayed-load, retry, invalidation, duplicate-close, entitlement, expiry, reward and impression regression tests |
| `test/widget_request_efficiency_test.dart` (new) | Native method-channel request counts, rebuild/config/gate/disposal/size/retry and initialization/consent races |
| Existing tests | Correct native initialization codec/result mocks, explicit host-managed consent setup, token-only mutex tests and additional lifecycle regression |

Other differences in ad state, shimmer and existing tests are required `dart format .` output, not feature changes.

## F. Verification

Final verification results are recorded after the final source edits:

- `dart format .`: completed, 36 Dart files checked. The example now declares its inherited lint dependency, resolving the earlier formatter include warning.
- `flutter pub get`: completed for package and example; google_mobile_ads 9.1.0 resolved.
- `flutter analyze`: no issues found.
- `flutter test --timeout 30s`: 115 tests passed.
- `git diff --check`: passed.
- `flutter build apk --debug`: passed; Android example installed on API 37 emulator.
- `flutter build ios --simulator --debug`: passed; iOS example installed on iOS 26 simulator.
- iOS CocoaPods resolved Google Mobile Ads 13.11.0 and UMP 3.1.0. Removed unnecessary `use_frameworks!` from the example Podfile to avoid plugin private-header module errors.
- Flutter 3.44.1 / Dart 3.12.1.

The Flutter performance scanner reports zero findings in `lib/` and `example/lib/`. Its whole-project scan flags small test-only `.where()`/`.map()` assertions as synchronous CPU work after awaits. These are low-confidence performance findings: the lists contain only captured test method calls. Moving them to isolates would add complexity without production benefit. The original confirmed example mounted-check issue is fixed. No runtime performance profiling claim is made.

Tests simulate native callbacks and method channels; they do not establish actual fill, rendered native UI, live mediation, real impressions, or device network behavior. Existing weak tests were supplemented with explicit request counts rather than treated as proof of loading.

## G. Remaining risks and platform review

The example now includes Android manifest/Gradle and iOS Info.plist/Xcode hosts with official Google test app IDs. Both debug native builds pass. Emulator/simulator installation and startup checks are limited smoke evidence; screenshots confirm both Flutter home screens rendered, and an iOS Google test banner rendered. Android reported an ad load error code 3 (no fill) during the smoke run. Full live-format and network recovery verification remains outstanding. The resolved plugin's Android build config uses compile SDK 36, min SDK 24, GMA 25.4.0 and UMP 4.0.0; its iOS podspec depends on GMA ~13.7 and declares iOS 13.0. A consuming application's resolved native dependencies and deployment targets must satisfy Google's actual SDK requirements.

The current [plugin changelog](https://pub.dev/packages/google_mobile_ads/changelog) confirms the 9.1.0 dependency baseline. Android loading/initialization optimization flags are already enabled by default since GMA 24.0.0, per [official guidance](https://developers.google.com/admob/android/optimize-initialization); no redundant manifest flags or unsupported iOS equivalents were added. Native templates, UMP flow and App Open cache rules were checked against [native template guidance](https://developers.google.com/admob/flutter/native/templates), [UMP guidance](https://developers.google.com/admob/flutter/privacy), and [App Open guidance](https://developers.google.com/admob/flutter/app-open).

Operational limits remain: no guaranteed demand/fill/CTR/revenue; native SDK callbacks can fail or stall; privacy/ad-unit configuration and appropriate placement are host responsibilities; mediation reward ordering varies; and already-started native requests cannot be recalled. A shown ad retains its lease until its SDK close callback rather than risking overlap after forced release.

The unreleased API/default/minimum-version changes require consuming-app migration. No backend, custom networking, extra runtime dependency, paid analytics or remote configuration was introduced.

### Consent and cleanup follow-up

Automatic UMP remains enabled by default. `initialize(consentParameters: ...)` now accepts SDK age/debug parameters and preserves them when automatic UMP is enabled by a later config update. The settings button uses UMP's actual privacy-entry-point requirement; the library exposes `isBusy`, `isPrivacyOptionsRequired`, and `lastError` for custom UI. Hosts must configure/publish the matching AdMob privacy message; test ad IDs alone do not force a form.

Removed the unused `AdMobKit.instance` alias, ignored paywall `adUnitId` parameter, duplicate inline eligibility checks, obsolete example ad IDs in test mode, and repetitive comments. Kept useful public API documentation and resource-ownership explanations. These removed legacy APIs are listed in README migration notes.

## H. Final verdict

**NOT READY — FIX REQUIRED**

Source analysis, automated regressions and both native debug builds pass, but unconditional production sign-off still needs live integration evidence:

1. Configure a real AdMob app ID and published privacy message to verify the required consent and privacy-options forms. Both supplied example native builds already pass with Google test app IDs.
2. Run Google test ads on both platforms for all five formats, including actual template sizing/touch layout, real foreground transitions, consent/privacy forms, reward callbacks, and delayed/offline/network-handover recovery.

These are explicit integration verification blockers, not claims that unit tests established real AdMob performance. The source fixes and audit are complete; publication was subsequently authorized by the user.


## Unreleased native layout follow-up

The Android medium native template now uses a bundled XML layout with a media area, 52dp icon/header, visible Ad attribution, SDK-managed AdChoices and a 50dp pill CTA. The factory registers once per engine through a setup channel before a native request; it uses actual ad assets, hides unavailable optional assets and never adds custom click listeners. Small and iOS layouts remain the official Google templates. All native templates default to white; `NativeAdStyle` retains developer background/text/CTA color and card-radius overrides.

The package now bundles an Android Flutter plugin; consumers must fully rebuild native apps after adopting this GitHub change. Factory setup failure makes no ad request, and unmount/config invalidation during setup cannot start a stale request. Verification: 121 tests passed, static analysis and diff whitespace checks passed, Android debug APK and iOS simulator builds passed, and the production Dart performance scan had no findings. Full rendered-ad verification still depends on SDK test fill. The package remains version 4.0.0; this follow-up is GitHub-only and was not published to pub.dev.


### Android medium layout refinement (GitHub-only)

Removed media corner rounding and changed CTA rounding to 10dp. The native factory registers the actual SDK star rating view and store asset; absent/invalid ratings and absent stores are hidden without inventing Play Store data. Headlines use 16sp, up to three lines with ellipsis; bodies use 13sp, at most two lines. This is the requested typography, not a claim that Google mandates a universal 16sp minimum. Full 24-word headlines are not guaranteed to fit every width. Android medium cards reserve at least 380dp so multiline text and rating/store assets do not consume the minimum media area. White defaults and custom colors remain supported; no pub.dev publication was performed.
