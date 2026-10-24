package com.neobrutalism.neo_brutalism_locket

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.ListView
import org.json.JSONArray

/**
 * Shown when a widget is placed (or reconfigured): whose photos should it show?
 * Everybody's, one friend's or one group's. The list of friends and groups is
 * saved by the Flutter app each time it loads the feed (w_choices); before the
 * app has ever run, only "all friends" is offered.
 */
class LocketWidgetConfigActivity : Activity() {

    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Backing out must leave the widget unplaced.
        setResult(RESULT_CANCELED)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setTitle(R.string.widget_pick_title)

        val keys = mutableListOf(WidgetSources.ALL)
        val labels = mutableListOf(getString(R.string.widget_all_friends))
        val stored = WidgetSources.prefs(this).getString("w_choices", null)
        if (stored != null) {
            try {
                val array = JSONArray(stored)
                for (i in 0 until array.length()) {
                    val item = array.getJSONObject(i)
                    val key = item.getString("k")
                    val label = item.getString("l")
                    keys.add(key)
                    labels.add(
                        if (key.startsWith("g_")) getString(R.string.widget_group_label, label)
                        else label,
                    )
                }
            } catch (_: Exception) {
                // A damaged list: offer "all friends" only.
            }
        }

        val list = ListView(this)
        list.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, labels)
        list.setOnItemClickListener { _, _, position, _ -> choose(keys[position]) }
        setContentView(list)
    }

    private fun choose(source: String) {
        WidgetSources.prefs(this).edit().putString("wcfg_$widgetId", source).apply()
        WidgetSources.refreshActive(this)
        // Draw it now, with whatever the app already saved for that source.
        sendBroadcast(
            Intent(this, LocketWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
            },
        )
        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
        )
        finish()
    }
}
