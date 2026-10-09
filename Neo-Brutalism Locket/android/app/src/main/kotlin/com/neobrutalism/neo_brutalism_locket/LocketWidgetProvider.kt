package com.neobrutalism.neo_brutalism_locket

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

/**
 * The home-screen widget: the newest photo a friend sent. The Flutter app
 * downloads the picture and saves the details (see lib/features/widget);
 * this only draws them. Tapping opens that post in the app.
 */
class LocketWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val postId = widgetData.getString("w_post_id", null)
        val bitmap = widgetData.getString("w_image", null)?.let { decode(it) }
        val shown = postId != null && bitmap != null

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.locket_widget)
            if (shown) {
                val name = widgetData.getString("w_name", "") ?: ""
                val caption = widgetData.getString("w_caption", "") ?: ""
                val ago = ago(context, createdAt(widgetData))
                views.setImageViewBitmap(R.id.widget_image, bitmap)
                views.setViewVisibility(R.id.widget_image, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty, View.GONE)
                views.setViewVisibility(R.id.widget_label, View.VISIBLE)
                views.setTextViewText(
                    R.id.widget_name,
                    if (name.isEmpty()) ago else "$name · $ago",
                )
                views.setTextViewText(R.id.widget_caption, caption)
                views.setViewVisibility(
                    R.id.widget_caption,
                    if (caption.isEmpty()) View.GONE else View.VISIBLE,
                )
            } else {
                views.setViewVisibility(R.id.widget_image, View.GONE)
                views.setViewVisibility(R.id.widget_label, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            }
            val link = if (shown) Uri.parse("neolocket://post/$postId") else null
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, link),
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /** The picture, shrunk: a widget's bitmaps have a small memory budget. */
    private fun decode(path: String): Bitmap? {
        val file = File(path)
        if (!file.exists()) return null
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= TARGET_SIZE &&
            bounds.outHeight / (sample * 2) >= TARGET_SIZE
        ) {
            sample *= 2
        }
        return BitmapFactory.decodeFile(
            path,
            BitmapFactory.Options().apply { inSampleSize = sample },
        )
    }

    /** Saved as a number from Dart: an Int or a Long depending on its size. */
    private fun createdAt(data: SharedPreferences): Long =
        (data.all["w_created"] as? Number)?.toLong() ?: 0L

    private fun ago(context: Context, createdMs: Long): String {
        if (createdMs <= 0L) return ""
        val minutes = (System.currentTimeMillis() - createdMs) / 60_000
        return when {
            minutes < 1 -> context.getString(R.string.widget_now)
            minutes < 60 -> "${minutes}m"
            minutes < 24 * 60 -> "${minutes / 60}h"
            else -> "${minutes / (24 * 60)}d"
        }
    }

    private companion object {
        const val TARGET_SIZE = 480
    }
}
