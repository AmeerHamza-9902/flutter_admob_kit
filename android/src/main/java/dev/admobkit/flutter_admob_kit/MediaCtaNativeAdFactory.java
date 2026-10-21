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
import java.text.NumberFormat;
import java.util.Collections;
import java.util.Map;

/** Media-first card with compact details and a CTA beside the headline. */
public final class MediaCtaNativeAdFactory implements NativeAdFactory {
    private final Context context;

    public MediaCtaNativeAdFactory(Context context) { this.context = context; }

    @Override
    public NativeAdView createNativeAd(NativeAd ad, Map<String, Object> customOptions) {
        Map<String, Object> options = customOptions == null ? Collections.emptyMap() : customOptions;
        NativeAdView view = (NativeAdView) LayoutInflater.from(context)
            .inflate(R.layout.admob_kit_native_media_cta, null);
        float radius = Math.max(0, number(options, "cornerRadius", 10).floatValue())
            * context.getResources().getDisplayMetrics().density;
        int background = color(options, "backgroundColor", Color.WHITE);
        int primary = color(options, "primaryTextColor", Color.rgb(17, 24, 39));
        int secondary = color(options, "secondaryTextColor", Color.rgb(107, 114, 128));
        int accent = color(options, "callToActionColor", Color.rgb(37, 99, 235));
        View card = view.findViewById(R.id.ad_card);
        card.setBackground(rounded(background, radius));
        card.setClipToOutline(true);

        View mediaContainer = view.findViewById(R.id.ad_media_container);
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
        } else {
            mediaContainer.setVisibility(View.GONE);
        }

        TextView headline = view.findViewById(R.id.ad_headline);
        headline.setText(ad.getHeadline());
        headline.setTextColor(primary);
        view.setHeadlineView(headline);
        TextView body = view.findViewById(R.id.ad_body);
        bindOptional(body, ad.getBody(), secondary);
        view.setBodyView(body);
        ImageView icon = view.findViewById(R.id.ad_app_icon);
        if (ad.getIcon() != null) {
            icon.setImageDrawable(ad.getIcon().getDrawable());
            icon.setVisibility(View.VISIBLE);
            view.setIconView(icon);
        }
        TextView badge = view.findViewById(R.id.ad_badge);
        badge.setBackground(rounded(accent, 3 * context.getResources().getDisplayMetrics().density));
        TextView rating = view.findViewById(R.id.ad_rating_text);
        Double stars = ad.getStarRating();
        if (stars != null && Double.isFinite(stars) && stars >= 0 && stars <= 5) {
            NumberFormat format = NumberFormat.getNumberInstance();
            format.setMaximumFractionDigits(1);
            rating.setText(format.format(stars) + " ★");
            rating.setTextColor(secondary);
            rating.setVisibility(View.VISIBLE);
            view.setStarRatingView(rating);
        }
        TextView cta = view.findViewById(R.id.ad_call_to_action);
        bindOptional(cta, ad.getCallToAction(),
            color(options, "callToActionTextColor", Color.WHITE));
        float ctaRadius = Math.min(radius, 8 * context.getResources().getDisplayMetrics().density);
        cta.setBackground(rounded(accent, ctaRadius));
        if (cta.getVisibility() == View.VISIBLE) view.setCallToActionView(cta);
        view.setAdChoicesView((AdChoicesView) view.findViewById(R.id.ad_choices_view));
        view.setNativeAd(ad);
        return view;
    }

    private static void bindOptional(TextView view, String text, int color) {
        view.setText(text);
        view.setTextColor(color);
        view.setVisibility(text == null || text.isEmpty() ? View.GONE : View.VISIBLE);
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
