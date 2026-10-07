# Resume App Open lifecycle

## Placement map

| Placement | Load trigger | Show trigger | Eligibility |
| --- | --- | --- | --- |
| Resume App Open | App startup or a host-selected foreground preload | First foreground return after `inactive`, `hidden`, or `paused` | SDK initialized, consent allows requests, free user, remote/code flag enabled, no paywall, and no fullscreen lease |

## Lifecycle behavior

1. The host primes one App Open ad while the app is in the foreground.
2. `hidden` or `paused` starts a background cycle. An `inactive → resumed` only
   cycle, such as opening the notification shade, is not eligible.
3. The first safe returning `resumed` callback presents the primed ad. There is no minimum background duration.
4. A lifecycle cycle created by an interstitial, rewarded, or App Open presentation is suppressed so fullscreen ads cannot chain.
5. A fullscreen presentation completed earlier while the app stayed foreground is recorded as history and does not suppress a later real background return.
6. If no ad is ready, the user continues without blocking and the manager starts the next preload in the foreground.
7. Camera, gallery, file picker, and permission requests can run through
   `AdMobKit.appOpen.runWithResumeSuppressed`, which suppresses that external
   lifecycle cycle even if its future completes just before `resumed`.

## Callback behavior

- `loaded`: caches the ad with its load timestamp.
- `shown` and `impression`: report the SDK-confirmed presentation events.
- `dismissed` or failed presentation: releases the shared fullscreen lease, disposes the consumed ad, and primes a replacement.
- `loadFailed`: follows the bounded retry policy and does not block foreground navigation.

## Developer opt-in audit

The library already re-primes App Open after dismissal. The consuming app explicitly requested resume App Open behavior and enables it through `autoResumeAppOpen`.

## Verification checklist

- [x] Sub-second `paused` to `resumed` cycles are eligible.
- [x] Cold-start `resumed` does not show a resume ad.
- [x] Active or just-dismissed fullscreen lifecycle cycles do not chain an App Open ad.
- [x] A prior foreground fullscreen ad does not suppress the next genuine resume.
- [x] Paywall state suppresses resume App Open.
- [x] Entitlement, consent, freshness, readiness, and shared fullscreen lease gates remain active.
- [x] Android test mode uses Google's current App Open demo unit (`9257395921`).
- [x] Notification shade and other `inactive`-only UI do not show App Open.
- [x] Scoped external camera, gallery, picker, and permission flows suppress
  their resume cycle.
