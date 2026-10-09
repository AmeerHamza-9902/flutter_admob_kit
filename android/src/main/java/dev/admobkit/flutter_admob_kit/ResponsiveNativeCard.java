package dev.admobkit.flutter_admob_kit;

import android.content.Context;
import android.text.Layout;
import android.util.AttributeSet;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Allocates spare height to media while preserving required headline copy. */
public final class ResponsiveNativeCard extends LinearLayout {
    private int lastAvailableWidth = -1;
    private int lastAvailableHeight = -1;

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
        int width = MeasureSpec.getSize(widthSpec);
        int available = MeasureSpec.getSize(heightSpec);
        if ((width != lastAvailableWidth || available != lastAvailableHeight)
                && body.getText().length() > 0) {
            body.setVisibility(View.VISIBLE);
        }
        lastAvailableWidth = width;
        lastAvailableHeight = available;
        super.onMeasure(widthSpec, heightSpec);
        if (MeasureSpec.getMode(heightSpec) == MeasureSpec.UNSPECIFIED
                || media.getVisibility() == View.GONE) return;

        if (requiredHeight() > available && body.getVisibility() == View.VISIBLE) {
            // Body is optional; shrinking the required headline can truncate
            // it before Google's first-25-character display minimum.
            body.setVisibility(View.GONE);
            super.onMeasure(widthSpec, heightSpec);
        }
    }

    @Override
    protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
        super.onLayout(changed, left, top, right, bottom);
        TextView body = findViewById(R.id.ad_body);
        if (body.getVisibility() != View.VISIBLE) return;
        Layout textLayout = body.getLayout();
        if (textLayout == null || textLayout.getLineCount() == 0) return;
        int lastLine = textLayout.getLineCount() - 1;
        int visibleCharacters = textLayout.getLineEnd(lastLine)
            - textLayout.getEllipsisCount(lastLine);
        if (visibleCharacters < Math.min(90, body.getText().length())) {
            body.setVisibility(View.GONE);
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
