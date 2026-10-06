package dev.admobkit.flutter_admob_kit;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.RatingBar;
import java.text.NumberFormat;
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;
import com.google.android.gms.ads.nativead.MediaView;
import com.google.android.gms.ads.nativead.AdChoicesView;
import io.flutter.plugins.googlemobileads.NativeAdFactory;
import java.util.Collections;
import java.util.Map;

public final class MediumNativeAdFactory implements NativeAdFactory {
    private final Context context;

    public MediumNativeAdFactory(Context context) { this.context = context; }

    @Override
    public NativeAdView createNativeAd(NativeAd ad, Map<String, Object> customOptions) {
        Map<String, Object> options = customOptions == null ? Collections.emptyMap() : customOptions;
        NativeAdView view = (NativeAdView) LayoutInflater.from(context)
            .inflate(R.layout.admob_kit_native_medium, null);
        float density = context.getResources().getDisplayMetrics().density;
        float radius = Math.max(0, number(options, "cornerRadius", 8).floatValue()) * density;
        int background = color(options, "backgroundColor", Color.WHITE);
        int primary = color(options, "primaryTextColor", Color.rgb(17, 24, 39));
        int secondary = color(options, "secondaryTextColor", Color.rgb(75, 85, 99));
        View card = view.findViewById(R.id.ad_card);
        card.setBackground(rounded(background, radius));
        card.setClipToOutline(true);
        View mediaContainer = view.findViewById(R.id.ad_media_container);
        mediaContainer.setBackgroundColor(background);
        mediaContainer.setClipToOutline(false);
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
        TextView advertiser = view.findViewById(R.id.ad_advertiser);
        bindOptional(advertiser, ad.getAdvertiser(), secondary);
        view.setAdvertiserView(advertiser);
        View ratingGroup = view.findViewById(R.id.ad_rating_group);
        RatingBar stars = view.findViewById(R.id.ad_stars);
        TextView ratingValue = view.findViewById(R.id.ad_rating_value);
        Double rating = ad.getStarRating();
        if (rating != null && Double.isFinite(rating) && rating >= 0 && rating <= 5) {
            stars.setRating(rating.floatValue());
            NumberFormat format = NumberFormat.getNumberInstance();
            format.setMaximumFractionDigits(1);
            ratingValue.setText(format.format(rating));
            ratingValue.setTextColor(secondary);
            ratingGroup.setVisibility(View.VISIBLE);
            view.setStarRatingView(ratingGroup);
        } else {
            ratingGroup.setVisibility(View.GONE);
        }
        TextView store = view.findViewById(R.id.ad_store);
        bindOptional(store, ad.getStore(), secondary);
        view.setStoreView(store);
        ((TextView) view.findViewById(R.id.ad_badge)).setTextColor(primary);
        ImageView icon = view.findViewById(R.id.ad_app_icon);
        icon.setBackground(rounded(background, radius));
        if (ad.getIcon() == null) {
            icon.setVisibility(View.GONE);
        } else {
            icon.setImageDrawable(ad.getIcon().getDrawable());
        }
        view.setIconView(icon);
        Button cta = view.findViewById(R.id.ad_call_to_action);
        cta.setText(ad.getCallToAction());
        cta.setVisibility(ad.getCallToAction() == null ? View.GONE : View.VISIBLE);
        cta.setBackgroundTintList(null);
        cta.setBackground(rounded(color(options, "callToActionColor", Color.rgb(37, 99, 235)), 10 * density));
        cta.setTextColor(color(options, "callToActionTextColor", Color.WHITE));
        view.setCallToActionView(cta);
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
