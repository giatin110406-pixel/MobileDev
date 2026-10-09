package com.neobrutalism.neo_brutalism_locket

import io.flutter.embedding.android.FlutterActivity

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.segmentation.Segmentation
import com.google.mlkit.vision.segmentation.SegmentationMask
import com.google.mlkit.vision.segmentation.Segmenter
import com.google.mlkit.vision.segmentation.selfie.SelfieSegmenterOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

class MainActivity : FlutterActivity() {
	private val segmentationChannel =
		"com.neobrutalism.neo_brutalism_locket/image_segmentation"
	private var selfieSegmenter: Segmenter? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, segmentationChannel)
			.setMethodCallHandler { call, result ->
				if (call.method != "segmentPerson") {
					result.notImplemented()
					return@setMethodCallHandler
				}

				val imagePath = call.argument<String>("path")
				if (imagePath.isNullOrBlank()) {
					result.error("INVALID_PATH", "An image path is required.", null)
					return@setMethodCallHandler
				}

				val inputImage = try {
					InputImage.fromFilePath(
						applicationContext,
						Uri.fromFile(File(imagePath)),
					)
				} catch (error: IOException) {
					result.error("IMAGE_READ_FAILED", error.message, null)
					return@setMethodCallHandler
				}

				getSelfieSegmenter().process(inputImage)
					.addOnSuccessListener { mask -> result.success(mask.toChannelResult()) }
					.addOnFailureListener { error ->
						result.error("SEGMENTATION_FAILED", error.message, null)
					}
			}
	}

	override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
		selfieSegmenter?.close()
		selfieSegmenter = null
		super.cleanUpFlutterEngine(flutterEngine)
	}

	private fun getSelfieSegmenter(): Segmenter {
		val current = selfieSegmenter
		if (current != null) return current
		val options = SelfieSegmenterOptions.Builder()
			.setDetectorMode(SelfieSegmenterOptions.SINGLE_IMAGE_MODE)
			.build()
		return Segmentation.getClient(options).also { selfieSegmenter = it }
	}

	private fun SegmentationMask.toChannelResult(): Map<String, Any> {
		val count = width * height
		val bytes = ByteBuffer.allocate(count * 4).order(ByteOrder.LITTLE_ENDIAN)
		val maskBuffer = buffer.asReadOnlyBuffer()
		maskBuffer.rewind()
		repeat(count) { bytes.putFloat(maskBuffer.getFloat()) }
		return mapOf(
			"width" to width,
			"height" to height,
			"maskBytes" to bytes.array(),
		)
	}
}
