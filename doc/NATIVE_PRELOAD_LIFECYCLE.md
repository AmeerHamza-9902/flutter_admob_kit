# Library-managed native preload lifecycle

The host places `NativeAdWidget.bigNative()` or
`NativeAdWidget.mediumNative()` where an ad belongs. It does not create or
pass a preload controller.

After initialization and consent, the library warms one default ad for each
configured native shape. A widget joins a matching in-flight request or
claims a ready ad exclusively. Its normal loading placeholder remains visible
until the SDK responds. On a successful claim the library starts one
replacement for a future placement; the same native view is never shared by
two visible widgets.

Unclaimed ads expire after two minutes; pending requests time out after one
minute. Entitlement, consent, test-mode, configuration, and unit changes clear
invalid cached ads. A screen that closes during loading releases its claim
without preventing the library from using the pending ad on the next screen.

SDK callbacks remain the source of loaded, impression, and click events. A
widget disposes the ad it displays when that placement is removed.
