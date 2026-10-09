# On-device Van Gogh fallback (Magenta)

`magenta_style_predict.tflite` + `magenta_style_transform.tflite` (with `assets/styles/van_gogh_starry_night.jpg`)
power the **fallback** Van Gogh path (`MagentaVanGoghBackend`). The main path is the laptop diffusion
server (see `server/README.md`); the app falls back Laptop -> Magenta -> mock and labels the result
with the path that actually ran.

# Daily-quest photo check (`assets/quest_model/`)

`quest_image_encoder_fp16.onnx` is the MobileCLIP2-S0 image encoder (`timm/MobileCLIP2-S0-OpenCLIP`, weights
`dfndr2b`), reparameterised and exported to ONNX. The big weights are *stored* as float16 (half the file) and
cast back to float32 on load, so every operation runs in float32: a model that computes in float16 loads on a PC but
fails on Android ("ORT_NOT_IMPLEMENTED ... Gelu ... float16"). `quest_labels.json` / `quest_labels.bin` are the
text embeddings of every quest description, so only the image side runs on the phone. All three are produced by
`server/eval/export_quest_model.py`; never edit them by hand. int8 quantisation was tried and breaks the model
(recall 3%), so do not use it. Licence of the weights: Apple ML Research (apple-amlr), verify before any public release.
