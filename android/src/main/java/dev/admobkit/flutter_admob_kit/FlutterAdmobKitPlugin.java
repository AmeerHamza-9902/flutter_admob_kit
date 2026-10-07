package dev.admobkit.flutter_admob_kit;

import android.content.Context;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

/** Registers the bundled layout after all engine plugins are attached. */
public final class FlutterAdmobKitPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    public static final String BIG_FACTORY_ID = "flutter_admob_kit/big_native";
    public static final String MEDIUM_FACTORY_ID = "flutter_admob_kit/medium_native";
    private FlutterEngine engine;
    private Context context;
    private MethodChannel channel;
    private boolean ownsBigFactory;
    private boolean ownsMediumFactory;

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
        if (!ownsBigFactory) {
            ownsBigFactory = GoogleMobileAdsPlugin.registerNativeAdFactory(engine, BIG_FACTORY_ID,
                new MediumNativeAdFactory(context));
        }
        if (!ownsMediumFactory) {
            ownsMediumFactory = GoogleMobileAdsPlugin.registerNativeAdFactory(engine, MEDIUM_FACTORY_ID,
                new HorizontalNativeAdFactory(context));
        }
        if (ownsBigFactory && ownsMediumFactory) {
            result.success(null);
        } else {
            result.error("factory_conflict", "An AdMob Kit native factory ID is already registered.", null);
        }
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        if (engine != null && ownsBigFactory) {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, BIG_FACTORY_ID);
        }
        if (engine != null && ownsMediumFactory) {
            GoogleMobileAdsPlugin.unregisterNativeAdFactory(engine, MEDIUM_FACTORY_ID);
        }
        channel = null;
        engine = null;
        context = null;
        ownsBigFactory = false;
        ownsMediumFactory = false;
    }
}
