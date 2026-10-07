# Ad delivery audit and measurement

The library owns one cached ad and one in-flight request per fullscreen format.
The library manages one inline ad per exact banner size or native template/style
key; a destination widget takes exclusive ownership. Every request is gated by SDK initialization, UMP permission
and entitlement. Fullscreen presentation additionally checks foreground state,
cooldown and the shared fullscreen lease. The SDK impression callback is the only
impression signal.

## Format-by-format lifecycle

| Format | Eligibility and request | Loaded ownership and opportunity | Impression, close and next request |
| --- | --- | --- | --- |
| Interstitial | Initialization/consent/premium gate; configured unit is eagerly preloaded unless `autoPreload: false`. One request and bounded retries per manager. | A fresh single-slot cache is used only at an explicit `show(true)` opportunity, subject to cooldown, foreground and fullscreen lease. A missing ad primes a request and returns immediately. | SDK impression callback is recorded separately from show acceptance. Dismiss/failure releases the exact lease, disposes the ad and starts one replacement load. |
| Rewarded | Same shared eligibility gate and single-slot preload. | Host offers an explicit reward opportunity; a ready ad needs the fullscreen lease. No ad is shown later after a missed opportunity. | SDK reward callback is delivered at most once per presentation, including permitted callback ordering around dismissal. SDK impression and reward are separate events. Dismiss/failure disposes and replenishes. |
| App Open | Same request gate and single-slot preload; expiry is capped at four hours. | Lifecycle observer offers a ready ad on a genuine foreground return; paywall, scoped external flows, consent, cooldown and another fullscreen ad suppress that opportunity. Manual `show(true)` is also available. | SDK impression is confirmed by its callback. Close disposes and replenishes; a late load never presents on an unrelated screen. |
| Banner | The library warms one large banner after initialization and consent. Other exact sizes and orientations load on first use. | A matching cached or pending ad is handed to one widget only; the widget owns the visible `AdWidget`. | SDK impression/click callbacks are recorded. Handoff starts one replacement for a later visit. Unmount or invalidation disposes the visible ad; unused cache entries expire after two minutes. There is no success refresh loop for a mounted banner. |
| Native | The library warms default big and medium templates after consent. Other templates, styles and ad-unit overrides load on first use after Android factory registration. | A matching cached or pending ad is transferred to one widget only. | SDK impression/click callbacks are recorded. Handoff starts one replacement for a later visit. Unmount/invalidation disposes the visible ad; unused cache entries expire after two minutes. A native view is never reused across screens. |

Banner and native are inline formats, so fullscreen dismissal and an accepted
`show()` result do not apply. Their opportunity is the eligible mounted
placement; a successfully loaded view can still fail to receive an impression
if it is never mounted, is immediately removed, or does not become visible.

## Where loaded ads can be lost

- The library's default warm inline ads may expire unused if the user never
  visits their screen. They never generate a fake impression.
- A loaded fullscreen ad can expire before an opportunity (one hour for
  interstitial/rewarded; four hours for App Open), or be invalidated by consent,
  premium or ad-unit changes. These are legitimate discards.
- A presentation attempt can lose the fullscreen lease, be blocked by cooldown,
  occur while backgrounded, or fail in the SDK. These are distinct from no fill.
- A `show()` call during a slow load returns unavailable immediately; it never
  schedules a late display on a different screen. An explicit readiness wait may
  time out while the request continues for a later opportunity.
- Banner/native views must not be mounted in two places. Each cached ad offers
  one handoff; a second destination needs its own ad.

Initialization preloads configured fullscreen units after consent, each manager
coalesces repeated requests, and dismissal triggers one bounded replacement.
Inline widgets reuse a matching library-owned cache entry and retry failures with a
bounded policy. Legacy preload controllers remain for source compatibility but
normal app integration does not need them. App Open suppression covers fullscreen/paywall and scoped
external flows; a host must wrap its own camera, gallery, file picker and
permission calls in `runWithResumeSuppressed`.

## Event interpretation

Use the optional `AdMobKit.addEventListener` callback to record format, event
type, timestamp, ad unit and reason. Avoid storing personal data in the callback.
The following ratios answer different questions:

| Metric | Numerator | Denominator |
| --- | --- | --- |
| Client load success proxy | `loaded` | `loaded + loadFailed` completed requests |
| Ready loaded-ad show | `presentationAccepted` | `cacheHit` with `reason == 'presentation'` |
| SDK impression after acceptance | SDK `impression` | `presentationAccepted` |
| Impressions per eligible session | SDK `impression` | Sessions eligible for the placement |

Compare the same format, placement, platform and time window. The second ratio
is the 90%+ optimization target, not a fill or revenue guarantee. `opportunity`
is emitted after basic eligibility gates and before cache/lease checks; a
`cacheMiss` identifies an eligible opportunity without a ready ad, including
one that arrives while a request is still loading. A show result
or `presentationAccepted` must never be reported as an impression.

The exact AdMob request match rate comes from AdMob reporting, not these client
events. The reported 30–40% figure cannot be attributed to match, show or SDK
impression loss without the corresponding request, load, opportunity and
impression counts over the same period.

## Real-device verification with Google test ads

1. Configure Google test unit IDs (`testMode: true`) and start with a fresh
   install. Confirm consent interaction completes before the first request.
2. On Android and iOS, exercise interstitial, rewarded, App Open, standard and
   inline/adaptive banner, and each native template. Confirm SDK impression
   callbacks only after a visible ad; verify reward once and dismissal once.
3. Initialize with configured native and banner units, then navigate to a
   matching placement. Confirm one cached handoff and one replacement request.
   Leave without visiting a warmed destination and confirm no fake impression
   is logged; its unused ad should expire after two minutes.
4. With a delayed network, use an explicit wait shorter than load time. Confirm
   the wait returns false, navigation continues, and a late ad remains ready
   without appearing on the departed screen. Restore connectivity and verify a
   later eligible opportunity can use it.
5. Switch offline/online, revoke consent, enable premium, enter a paywall,
   open a permission prompt and launch camera/gallery. Confirm stale ads are
   invalidated, App Open is suppressed during external flows, and no duplicate
   fullscreen presentation occurs.
6. Repeat across cold launch, quick background/resume, and notification shade.
   Compare request/load/acceptance/impression counts with the Ad Inspector and
   AdMob reporting, allowing for reporting latency.

Automated tests use fake SDK callbacks and do not establish live inventory,
network fill, mediation behavior or real-device impression rates. Those require
the device procedure above and production measurement over a meaningful cohort.

## Verification recorded on 2026-10-07

| Check | Result |
| --- | --- |
| `flutter test` | 175 automated tests passed (fake SDK callbacks and widget tests). |
| `flutter analyze --no-pub` | No issues found. |
| `flutter build apk --debug --no-pub` in `example/` | Android APK built. |
| `flutter build ios --no-codesign --no-pub` in `example/` | iOS app built without signing; this does not verify installation or live ad delivery. |

No live-device ad impressions or production AdMob report were supplied, so the
observed 30–40% result cannot yet be assigned to one metric. The device steps
above and same-period AdMob request/matched-request/impression counts are the
remaining evidence needed for that diagnosis.
