package dev.admobkit.flutter_admob_kit;

import android.content.Context;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

/** Registers the bundled layout after all engine plugins are attached. */
public final class FlutterAdmobKitPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    public static final String FACTORY_ID = "flutter_admob_kit/medium";
    private FlutterEngine engine;
    private Context context;
    private MethodChannel channel;
    private boolean ownsFactory;

    @Override
    @SuppressWarnings("deprecation")
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        engine = binding.getFlutterEngine();
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_admob_kit/native_templates");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (!call.method.equals("ensureRegistered")) {
            result.notImplemented();
            return;
        }
        if (engine == null || !engine.getPlugins().has(GoogleMobileAdsPlugin.class)) {
            result.error("ads_plugin_missing", "Google Mobile Ads must be registered on this engine.", null);
            return;
        }
        if (!ownsFactory) {
            ownsFactory = GoogleMobileAdsPlugin.registerNativeAdFactory(engine, FACTORY_ID,
                new MediumNativeAdFactory(context));
        }
        if (ownsFactory) {
            result.success(null);
        } else {
            result.error("factory_conflict", "The AdMob Kit factory ID is already registered.", null);
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        if (engine != null && ownsFactory) {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, FACTORY_ID);
        }
        channel = null;
        engine = null;
        context = null;
        ownsFactory = false;
    }
}
