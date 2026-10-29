package com.neobrutalism.neo_brutalism_locket.rewind

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.neobrutalism.neo_brutalism_locket.MainActivity
import com.neobrutalism.neo_brutalism_locket.SquareCrop
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import java.io.File

// Rewind capture opened from the quick-settings tile, over the lock screen.
// It only shoots and picks a frame. Sending asks the person to unlock, then
// hands the picture to MainActivity and closes. It never starts Supabase or
// touches the user's data: the Dart side is rewindLockscreenMain.
class RewindLockscreenActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        super.onCreate(savedInstanceState)
    }

    override fun getDartEntrypointFunctionName(): String = "rewindLockscreenMain"

    override fun getDartEntrypointLibraryUri(): String =
        "package:neo_brutalism_locket/features/rewind/rewind_lockscreen_main.dart"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SquareCrop.register(flutterEngine.dartExecutor.binaryMessenger)
        flutterEngine.plugins.add(RewindPlugin())
    }

    /**
     * Opens the main app on [bytes] (the picture the person picked) and
     * closes this screen. With no bytes it just opens the main app.
     */
    fun handOff(bytes: ByteArray?) {
        val intent = Intent(this, MainActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP,
        )
        if (bytes != null && bytes.isNotEmpty()) {
            val dir = File(filesDir, "rewind_handoff").apply { mkdirs() }
            val name = "${System.currentTimeMillis()}.jpg"
            File(dir, name).writeBytes(bytes)
            intent.data = Uri.parse("neolocket://rewind?file=$name")
        }
        startActivity(intent)
        finish()
    }
}
