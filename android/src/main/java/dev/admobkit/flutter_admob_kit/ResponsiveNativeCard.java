package dev.admobkit.flutter_admob_kit;

import android.content.Context;
import android.util.AttributeSet;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Allocates spare height to media and reduces text lines before clipping assets. */
public final class ResponsiveNativeCard extends LinearLayout {
    public ResponsiveNativeCard(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    @Override
    protected void onMeasure(int widthSpec, int heightSpec) {
        TextView headline = findViewById(R.id.ad_headline);
        TextView body = findViewById(R.id.ad_body);
        View media = findViewById(R.id.ad_media_container);
        headline.setMaxLines(3);
        body.setMaxLines(2);
        super.onMeasure(widthSpec, heightSpec);
        if (MeasureSpec.getMode(heightSpec) == MeasureSpec.UNSPECIFIED
                || media.getVisibility() == View.GONE) return;

        int available = MeasureSpec.getSize(heightSpec);
        while (requiredHeight() > available) {
            if (headline.getMaxLines() > 1) {
                headline.setMaxLines(headline.getMaxLines() - 1);
            } else if (body.getMaxLines() > 1) {
                body.setMaxLines(1);
            } else {
                break;
            }
            super.onMeasure(widthSpec, heightSpec);
        }
    }

    private int requiredHeight() {
        int height = getPaddingTop() + getPaddingBottom();
        for (int i = 0; i < getChildCount(); i++) {
            View child = getChildAt(i);
            if (child.getVisibility() == View.GONE) continue;
            LayoutParams params = (LayoutParams) child.getLayoutParams();
            height += params.topMargin + params.bottomMargin;
            height += child.getId() == R.id.ad_media_container
                    ? child.getMinimumHeight() : child.getMeasuredHeight();
        }
        return height;
    }
}
