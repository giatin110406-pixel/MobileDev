package com.neobrutalism.neo_brutalism_locket

import android.graphics.Bitmap
import android.graphics.BitmapRegionDecoder
import android.graphics.Matrix
import android.graphics.Rect
import android.media.ExifInterface
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

// Centre-crops a camera JPEG to a square with the phone's own decoder: only
// the square is decoded (BitmapRegionDecoder), then it is turned upright
// from its EXIF orientation and re-encoded. Much faster than the Dart
// `image` package, which decodes and copies the whole photo several times.
object SquareCrop {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        MethodChannel(
            messenger,
            "com.neobrutalism.neo_brutalism_locket/square_crop",
        ).setMethodCallHandler { call, result ->
            if (call.method != "cropToSquareJpeg") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            val quality = call.argument<Number>("quality")?.toInt() ?: 92
            if (path == null) {
                result.error("badArgs", "path is required", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val bytes = crop(path, quality)
                    main.post { result.success(bytes) }
                } catch (e: Exception) {
                    main.post { result.error("cropFailed", e.message, null) }
                }
            }
        }
    }

    private fun crop(path: String, quality: Int): ByteArray {
        @Suppress("DEPRECATION")
        val decoder = BitmapRegionDecoder.newInstance(path, false)
            ?: throw IllegalStateException("Unsupported image")
        val square = try {
            // The centre square stays the centre square under any EXIF turn
            // or flip, so it can be cut before the photo is turned upright.
            val side = minOf(decoder.width, decoder.height)
            val left = (decoder.width - side) / 2
            val top = (decoder.height - side) / 2
            decoder.decodeRegion(Rect(left, top, left + side, top + side), null)
                ?: throw IllegalStateException("Could not decode image")
        } finally {
            decoder.recycle()
        }
        val upright = turnUpright(square, path)
        return ByteArrayOutputStream().use { out ->
            upright.compress(Bitmap.CompressFormat.JPEG, quality, out)
            upright.recycle()
            out.toByteArray()
        }
    }

    private fun turnUpright(bitmap: Bitmap, path: String): Bitmap {
        val matrix = Matrix()
        when (
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.setScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.setRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.setScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.setRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.setRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.setRotate(-90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.setRotate(-90f)
            else -> return bitmap
        }
        val turned = Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
        )
        if (turned !== bitmap) bitmap.recycle()
        return turned
    }
}
