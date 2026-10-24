package com.neobrutalism.neo_brutalism_locket

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences

/**
 * Which photos each placed widget follows. A widget shows everybody's newest
 * photo ("all"), or one friend's ("u_<id>"), or one group's ("g_<id>"). The choice
 * is made per widget when it is placed (LocketWidgetConfigActivity) and kept here,
 * beside the data the Flutter app saves (see lib/features/widget).
 */
object WidgetSources {
    /** The file home_widget keeps its values in. */
    private const val PREFS = "HomeWidgetPreferences"
    const val ALL = "all"

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun sourceOf(prefs: SharedPreferences, widgetId: Int): String =
        prefs.getString("wcfg_$widgetId", ALL) ?: ALL

    /** The key the app saved [field] under for [source]; "all" keeps the plain names. */
    fun key(source: String, field: String): String =
        if (source == ALL) field else "ws_${source}_$field"

    /**
     * Writes the list of sources the placed widgets follow (besides "all") to
     * w_active, which the app reads to know whose pictures to download. Settings
     * of widgets that no longer exist are dropped.
     */
    fun refreshActive(context: Context) {
        val prefs = prefs(context)
        val manager = AppWidgetManager.getInstance(context)
        val alive = manager
            .getAppWidgetIds(ComponentName(context, LocketWidgetProvider::class.java))
            .toSet()
        val edit = prefs.edit()
        val active = sortedSetOf<String>()
        for (name in prefs.all.keys) {
            if (!name.startsWith("wcfg_")) continue
            val id = name.removePrefix("wcfg_").toIntOrNull()
            if (id == null || id !in alive) {
                edit.remove(name)
                continue
            }
            val source = prefs.getString(name, ALL) ?: ALL
            if (source != ALL) active.add(source)
        }
        edit.putString("w_active", active.joinToString(","))
        edit.apply()
    }
}
