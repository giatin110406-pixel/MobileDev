# On-device Van Gogh fallback (Magenta)

`magenta_style_predict.tflite` + `magenta_style_transform.tflite` (with `assets/styles/van_gogh_starry_night.jpg`)
power the **fallback** Van Gogh path (`MagentaVanGoghBackend`). The main path is the laptop diffusion
server (see `server/README.md`); the app falls back Laptop -> Magenta -> mock and labels the result
with the path that actually ran.
