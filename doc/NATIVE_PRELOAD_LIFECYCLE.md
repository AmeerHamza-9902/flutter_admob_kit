# Native destination preload lifecycle

## Placement map

| Placement | Format | Load trigger | Display trigger | Eligibility |
| --- | --- | --- | --- | --- |
| Upcoming destination | Native | Preceding high-intent screen | Destination widget mounts | Initialized, consent permits ads, free user, matching unit/template/style |

## Lifecycle

1. The host creates one `NativePreloadController` for each upcoming placement.
2. `preloadMediumNative` or `preloadBigNative` loads one view close to expected navigation. Repeated matching calls share that request.
3. The destination passes the same controller to `NativeAdWidget`. The widget claims the ready or in-flight ad and does not create another request.
4. A claim is exclusive because Google native platform views cannot be shared by two mounted widgets.
5. Unclaimed ads expire after two minutes. Pending requests time out after one minute. Configuration, consent, test-mode, entitlement, or unit changes dispose invalid preloads.
6. A failed preload falls back to the widget's existing bounded retry behavior without blocking navigation.

## Callback behavior

- `loaded`, `impression`, and `clicked` remain SDK-sourced events.
- A claimed ad is disposed by its destination widget.
- An unused controller disposes its pending ad when cleared or disposed.

## Developer opt-in audit

No native ad is reloaded from its dismissal callback. Native preloading is initiated only by the host at a known high-probability navigation point.

## Verification checklist

- [x] Matching preload and destination use one network request.
- [x] Separate simultaneous placements require separate controllers.
- [x] Entitled or consent-ineligible users do not preload.
- [x] Configuration changes invalidate unused views.
- [x] Unmounted or reconfigured widgets release their claim.
- [x] Matching-height shimmer preserves the destination layout while fallback loading occurs.
