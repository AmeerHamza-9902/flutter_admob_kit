package dev.admobkit.flutter_admob_kit;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.ImageView;
import android.widget.TextView;
import com.google.android.gms.ads.nativead.AdChoicesView;
import com.google.android.gms.ads.nativead.MediaView;
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;
import io.flutter.plugins.googlemobileads.NativeAdFactory;
import java.util.Collections;
import java.util.Locale;
import java.util.Map;

/** Fullscreen media-overlay native template with style supplied by Dart. */
public final class FullscreenNativeAdFactory implements NativeAdFactory {
    private final Context context;

    public FullscreenNativeAdFactory(Context context) { this.context = context; }

    @Override
    public NativeAdView createNativeAd(NativeAd ad, Map<String, Object> customOptions) {
        Map<String, Object> options = customOptions == null ? Collections.emptyMap() : customOptions;
        NativeAdView view = (NativeAdView) LayoutInflater.from(context)
            .inflate(R.layout.admob_kit_native_fullscreen, null);
        int background = color(options, "backgroundColor", Color.BLACK);
        int primary = color(options, "primaryTextColor", Color.WHITE);
        int secondary = color(options, "secondaryTextColor", 0xE0FFFFFF);
        int ctaColor = color(options, "callToActionColor", Color.WHITE);
        int ctaText = color(options, "callToActionTextColor", Color.BLACK);
        float radius = Math.max(0, number(options, "cornerRadius", 10).floatValue())
            * context.getResources().getDisplayMetrics().density;
        view.findViewById(R.id.ad_fullscreen_root).setBackgroundColor(background);

        MediaView media = view.findViewById(R.id.ad_media);
        ImageView fallback = view.findViewById(R.id.ad_media_fallback);
        view.setMediaView(media);
        view.setImageView(fallback);
        if (ad.getMediaContent() != null) {
            media.setMediaContent(ad.getMediaContent());
        } else if (!ad.getImages().isEmpty()) {
            fallback.setImageDrawable(ad.getImages().get(0).getDrawable());
            fallback.setVisibility(View.VISIBLE);
            media.setVisibility(View.GONE);
        }

        TextView headline = view.findViewById(R.id.ad_headline);
        headline.setText(ad.getHeadline());
        headline.setTextColor(primary);
        view.setHeadlineView(headline);
        TextView body = view.findViewById(R.id.ad_body);
        body.setText(ad.getBody());
        body.setTextColor(secondary);
        body.setVisibility(ad.getBody() == null || ad.getBody().isEmpty() ? View.GONE : View.VISIBLE);
        view.setBodyView(body);
        ImageView icon = view.findViewById(R.id.ad_app_icon);
        if (ad.getIcon() != null) {
            icon.setImageDrawable(ad.getIcon().getDrawable());
            icon.setVisibility(View.VISIBLE);
        }
        view.setIconView(icon);

        TextView rating = view.findViewById(R.id.ad_rating_text);
        Double stars = ad.getStarRating();
        if (stars != null && Double.isFinite(stars) && stars >= 0 && stars <= 5) {
            int filled = Math.min(5, Math.max(0, (int) Math.round(stars)));
            StringBuilder text = new StringBuilder();
            for (int i = 0; i < 5; i++) text.append(i < filled ? '★' : '☆');
            rating.setText(String.format(Locale.getDefault(), "%s %.1f", text, stars));
            rating.setTextColor(primary);
            rating.setVisibility(View.VISIBLE);
            view.setStarRatingView(rating);
        }
        TextView badge = view.findViewById(R.id.ad_badge);
        badge.setTextColor(primary);
        badge.setBackground(rounded(0x66000000, Math.min(radius, 4)));
        TextView cta = view.findViewById(R.id.ad_call_to_action);
        cta.setText(ad.getCallToAction());
        cta.setTextColor(ctaText);
        cta.setBackground(rounded(ctaColor, radius));
        cta.setVisibility(ad.getCallToAction() == null ? View.GONE : View.VISIBLE);
        view.setCallToActionView(cta);
        AdChoicesView choices = view.findViewById(R.id.ad_choices_view);
        view.setAdChoicesView(choices);
        choices.bringToFront();
        view.setNativeAd(ad);
        return view;
    }

    private static Number number(Map<String, Object> options, String key, Number fallback) {
        Object value = options.get(key);
        return value instanceof Number ? (Number) value : fallback;
    }

    private static int color(Map<String, Object> options, String key, int fallback) {
        return number(options, key, fallback).intValue();
    }

    private static GradientDrawable rounded(int color, float radius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(radius);
        return drawable;
    }
}
