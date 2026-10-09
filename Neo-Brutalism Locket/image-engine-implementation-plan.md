# Image Engine Plan: 8-bit and Van Gogh

The camera flow, `NeoPhoto` archive, original/processed toggle, and neo-brutalism UI remain. The active engine contract is `StyleEngine`: it accepts the original `File` and a `StyleType`, then returns a newly written PNG `File`. Implementations are selected through `StyleEngineFactory`.

## Active Constraints

- Processing stays on-device. No upload, network retry, segmentation, face contours, OpenCV, or ML Kit.
- Never modify the original. Every processing attempt writes a new PNG; changing style starts from the original and retains older processed files.
- Pure-Dart image work runs in `compute()`. Platform inference must use the plugin-supported path, never an assumed `compute()` call.
- Failures persist `failed` plus a reason, show the original, and allow retry.
- If 8-bit processing takes longer than five seconds, retry once at a lower pixel width. A failed retry still leaves the original intact.

## 8-bit Filter

`Pixel8BitStyleEngine` runs the deterministic pipeline in an isolate: EXIF orientation, centered square crop, 128px default resolution (96-192 configurable), mild contrast/saturation lift, nearest-color mapping in CIELAB, ordered Bayer 4x4 dithering, and nearest-neighbor enlargement to a 4x PNG. The selectable palettes are PICO-8 (16 colors) and Game Boy (4 colors); quantized pixels always belong to the selected palette.

The default resolution and contrast remain provisional until selfie fixtures are reviewed on real devices. The current test suite covers deterministic output, dithering, palette membership, and original-file preservation; it does not establish the under-one-second device target.

## Van Gogh Filter

`VanGoghStyleEngine` delegates through `VanGoghBackend`. The active `MockVanGoghBackend` waits one second and writes a simple yellow/blue tint. This is a UI-flow mock only; it is not neural style transfer and must not be described as a completed Van Gogh filter.

When the trained model is available, the intended asset path is `assets/models/van_gogh.tflite`. Required tensor values are RGB `float32` in `[0, 1]`, with output matching the input shape and range. The spatial tensor shape (fixed or dynamic) is deliberately unresolved until the real exported model is inspected; the runtime must read its dimensions from model metadata rather than hardcode them. Do not add TFLite inference until this contract is confirmed against the artifact.

## Delivery Status

- Phase A: `StyleEngine`, `StyleType`, metadata persistence, factory selection, and original-safe camera/retry flow are active.
- Phase B: PICO-8/Game Boy 8-bit pipeline and focused unit tests are active. Device performance and selfie-quality review remain outstanding.
- Phase C: filter and palette controls, isolate-generated thumbnail previews, and reprocessing from the original are active.
- Phase D: not started. No model asset or real TFLite inference is present.

Historical implementation and superseded plan: `legacy/`.# Image Engine Implementation Plan

## Goal

Turn the current local poster filter into a deterministic neo-brutalist photo pipeline while preserving the original image, running processing on-device, and degrading safely when ML results are missing or unreliable.

## Current Baseline

`lib/features/image_engine/neo_stylizer.dart` currently decodes the photo, scales its longest edge to at most 900px, detects a simple luminance gradient edge, and maps non-edge pixels to the approved palette. `CameraExperienceScreen` runs this pure-Dart function in `compute()` and saves its PNG beside the untouched original. It does not currently segment people, detect faces, smooth regions, or replace backgrounds.

## Non-Negotiable Constraints

- Keep capture and image processing offline. Never upload photos or call generative image services.
- Never overwrite the original. Write the processed file separately and only mark the photo `done` after the new file is complete.
- Only use the app's approved design palette for poster pixels: `#ECE6C2`, `#FDF2E9`, `#FF6B6B`, `#A388EE`, `#4ECDC4`, `#FFE66D`, `#45B7D1`, `#F7A072`, plus outline ink `#1A1A1A`.
- Keep each processing stage independently testable and keep ML/native implementations behind an `ImageProcessingBackend` boundary.
- Prefer a conservative fallback over a visually incorrect cutout or forced face treatment.

## Target Pipeline

1. Decode, validate, orient, and scale the image for the device budget.
2. Run on-device person segmentation and retain the soft confidence mask.
3. Run cross-platform face detection with contours when a face is present.
4. Refine/feather the person mask and create region masks where confidence permits.
5. Smooth regions conservatively: face/skin with bilateral smoothing, hair with Kuwahara-like smoothing, clothing with lighter edge-preserving smoothing.
6. Extract strong structural edges with XDoG; add face contour strokes only for trusted landmarks.
7. Quantize per region: adaptive luminance bands for face, 2 tones for hair, 2-3 tones for clothing; map final clusters to the approved palette in LAB space.
8. Replace the real background only when segmentation confidence is sufficient; otherwise retain it and apply the non-cutout poster treatment.
9. Composite layers and encode a separate processed PNG.

## Phases

### Phase 0: Contracts and Baseline Tests

- Define the `ImageProcessingBackend` contract and a Dart baseline backend.
- Split the current stylizer into pure helpers for resize, luminance, edge mask, palette mapping, and encoding without changing its existing output contract.
- Add unit tests for invalid inputs, deterministic output, palette membership, edge detection, luminance calculation, and resize limits.

Acceptance: existing capture flow still calls one top-level isolate-safe entry point; originals remain unchanged; tests pass.

### Phase 1: Segmentation and Background Replacement

- Add ML Kit selfie segmentation for still images on Android through a native Kotlin MethodChannel (`com.google.mlkit:segmentation-selfie:16.0.0-beta6`). The resolved app minSdk is 24, which meets ML Kit's Android API 23 requirement.
- Prepare a PNG working copy with a 900px maximum side, segment it in `SINGLE_IMAGE_MODE`, and return the confidence buffer to Dart without touching the original file.
- Convert the confidence output into a soft mask; validate foreground coverage, resample/feather its edge, then composite only when the mask is trusted.
- Add selectable flat background presets using only approved palette colors.
- Gate replacement on mask quality and expose a keep-original-background fallback.

Platform scope: Android uses native ML Kit. iOS remains at its existing 13.0 target and uses the no-mask poster fallback; the Flutter ML Kit plugin is not added because its current release requires iOS 15.5. Revisit iOS segmentation only after choosing an iOS 15.5 minimum or an iOS 13-compatible backend.

Acceptance: synthetic mask tests cover thresholds, feathering, fallback, and selected palette colors; Android no-person/low-confidence cases preserve the source background; iOS remains build-compatible at 13.0; output background uses only the approved palette.

### Phase 2: Structural Abstraction

- Add a stable OpenCV/native backend behind `ImageProcessingBackend` for resize, edge-preserving smoothing, and XDoG.
- Benchmark the `opencv_dart` package against Android and iOS build requirements before committing to it; keep native platform-channel implementation as the fallback if its API or binaries are unsuitable.
- Add strong-edge thresholds and silhouette outline from the segmentation mask.

Acceptance: golden tests show major edges without excessive texture noise; processing stays within memory limits at the target resolution.

### Phase 3: Face-Aware Refinement

- Add cross-platform face contours using `google_mlkit_face_detection`.
- Build face-region masks from the face oval and landmark points; add eye, brow, lip, and face-outline strokes only when geometry is trusted.
- Treat face size, crop-at-frame-edge, contour completeness, and head pose as reliability checks. The detector may not provide a single general confidence score, so do not invent one.
- Keep face mesh optional and Android-only; never make iOS depend on it.

Acceptance: no-face and unreliable-face images use general edges only; diverse skin tones retain adaptive luminance bands; no landmarks are forced when confidence checks fail.

### Phase 4: Reliability, Performance, and Visual QA

- Persist `pending/done/failed` state and an engine version; process one image at a time.
- Keep ML Kit plugin calls on the platform-supported async path. Run pure CPU-heavy Dart stages in an isolate; do not assume platform plugins can be called from `compute()`.
- If processing exceeds the device budget (target under 3s on a mid-range device; warn/scale down beyond 5s), lower the working resolution and retry conservatively.
- Build a consented visual fixture set covering lighting, diverse skin tones, pose, occlusion, no person, multiple people, and mask edge cases.
- Benchmark on at least one mid-range Android device and one iPhone before claiming performance targets.

Acceptance: original file checksum is unchanged; processed output is reproducible; failures preserve the original and offer retry; visual and performance gates pass on real devices.

## Fallback Matrix

| Condition | Behavior |
|---|---|
| Segmentation missing or weak | Keep the real background; run whole-image palette/edge treatment |
| No face detected | Skip face masks and locked strokes |
| Face small, cropped, or unreliable | Use general edge extraction across the person region |
| Mask has holes or rough hair boundaries | Feather/refine conservatively; if still poor, skip background removal |
| Severely underexposed photo | Warn that quality may be poor and offer retake; do not aggressively stylize |
| Slow/low-memory device | Process one photo at a time at reduced resolution; retain the original |
| Any pipeline exception | Keep original visible, mark processing failed, allow retry |

## Implementation Order

Start with Phase 0, then land each later phase as a separately tested change. Do not add ML Kit or OpenCV dependencies until their platform/build compatibility has been checked. Do not claim the full pipeline is implemented until segmentation, face-aware fallback, background handling, golden tests, and real-device performance checks all meet their acceptance criteria.
