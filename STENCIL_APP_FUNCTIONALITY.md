# Stencil App — Functionality Reference

This document captures **what the existing Python/Gradio frontend does**, not how it looks. It is the functional spec for porting the experience to iPad.

Source repo of reference: `/Users/sebas1541/Projects/stencil/microservice_stencil`
Reference frontend file: `frontend/app.py` (Gradio test rig)
Reference backend root: `app/` (FastAPI microservice + pipeline modules)

---

## 0. The single most important architectural fact

There are **two ways the pipeline is exposed**:

1. **The FastAPI HTTP microservice** (`app/main.py`) — three endpoints, S3-backed, this is what a real client (the iPad app) must consume.
2. **The Gradio test frontend** (`frontend/app.py`) — bypasses HTTP entirely. It `import`s `run_pipeline` directly and runs the pipeline in-process. **No S3, no auth header, no presigned URLs.**

The Gradio UI is therefore the *functional* reference (what features exist, what every slider does), but it is **NOT** a wire-level reference. The iPad app must speak HTTP and S3.

Side effect of this split: **all retouching, overlay, color swap, and Procreate single-PNG export logic lives only in `frontend/app.py`**. The HTTP API returns the raw stencil and that's it. The iPad app must reimplement retouching/overlay client-side (or those features must first be added to the API).

---

## 1. HTTP API contract (the only thing the iPad app talks to)

Base URL: configured per env. Auth header: `X-Api-Key: <value>` if `API_KEY` is configured server-side; otherwise omit.

### `GET /health`
Returns `{"status": "ok"}`. Used for liveness and Lambda warming.

### `POST /presigned-upload`
Request:
```json
{ "filename": "tattoo-ref.jpg" }
```
Response:
```json
{
  "upload_url": "https://s3.../inputs/<uuid>.jpg?...",
  "s3_key":     "inputs/<uuid>.jpg"
}
```
Client must then `PUT` the raw image bytes to `upload_url` with the right `Content-Type`.

### `POST /stencil`
Request:
```json
{
  "request_id":   "<uuid v4>",
  "s3_key":       "inputs/<uuid>.jpg",
  "estilo":       "fine_line",
  "grosor_linea": 2,            // 1-5 (only used by `nano` tier)
  "contraste":   5,             // 1-10 (only used by `nano` tier)
  "tier":         "flash",
  "resolution":   "4K",         // "1080p" | "2K" | "4K"; "6K" is rejected
  "prompt_mode":  "standard",   // or "technical_trace"
  "prompt_config": {
    "ui_background":       true,
    "ui_thickness":        "Medio",        // "Fino" | "Medio" | "Grueso"
    "ui_shadows_enabled":  false,
    "ui_shadow_detail":    "Detallado",    // "Breve" | "Medio" | "Detallado" | "Súper Detallado"
    "ui_shadow_weight":    "Suave",        // "Muy Suave" | "Suave" | "Notable"
    "ui_texture_level":    "Bajo (Limpio)" // "Bajo (Limpio)" | "Medio" | "Alto (Detallado)"
  }
}
```
Response:
```json
{
  "stencil_url":        "https://s3.../outputs/<uuid>_stencil.png?...",
  "preview_url":        "https://s3.../outputs/<uuid>_preview.webp?...",
  "formato":            "PNG",
  "content_type":       "portrait",
  "content_confidence": 0.92,
  "usage": {
    "request_id":         "<uuid>",
    "tier":               "flash",
    "gemini_calls":       2,
    "input_mpx":          3.21,
    "output_resolution":  "4K",
    "processing_time_ms": 4128,
    "success":            true,
    "resolution_warning": false
  }
}
```

Server-side hard rules:
- `s3_key` must start with `inputs/` (the `S3_INPUT_PREFIX`) — otherwise 400.
- Image bytes must be ≤ 15 MB — otherwise 413.
- `6K` resolution → 422.
- `technical_trace` + `nano` → 422.
- Anything else from the pipeline → 422 with `Pipeline error: ...`.

### Validation enums (from `app/models.py`)

- **`StyleName`** (15): `realismo, black_grey, tradicional, neotradicional, blackwork, fine_line, minimalista, japones, acuarela, puntillismo, geometrico, trash_polka, biomecanico, new_school, lettering`.
- **`ModelTier`** (6): `nano, flash, pro, gpt_mini, gpt_flash, gpt_pro`.
- **`Resolution`**: `1080p, 2K, 4K` (`6K` is in the enum but always rejected).
- **`PromptMode`**: `standard, technical_trace`.
- `request_id` must match a UUID v4 regex.

---

## 2. End-to-end user flow

### Stage A — Pre-generation inputs the user picks
1. **Image source** — file upload or clipboard paste. PNG bytes are sent as-is.
2. **Tattoo style** — dropdown of the 15 `StyleName` values (default: `fine_line`).
3. **Processing tier** — radio of the 6 tiers (default: `flash`). Each shows a price estimate.
4. **Export resolution** — radio of `1080p / 2K / 4K` (default: `4K`).
5. **Prompt controls** (the `prompt_config` payload), all defaults shown below:
   - `ui_background` — boolean, default `true`. "Preserve background" toggle.
   - `ui_thickness` — `"Fino" | "Medio" | "Grueso"`, default `Medio`. Main contour thickness.
   - `ui_shadows_enabled` — boolean, default `false`. "Topographic value contours" toggle.
   - `ui_shadow_detail` — 4 levels, default `Detallado`. Only meaningful when shadows enabled.
   - `ui_shadow_weight` — 3 levels, default `Suave`. Only meaningful when shadows enabled.
   - `ui_texture_level` — 3 levels, default `Bajo (Limpio)`. Texture filtering.
6. **Two trigger buttons** (mutually exclusive):
   - **Generate Stencil** → submits with `prompt_mode = "standard"`.
   - **Technical Trace** → submits with `prompt_mode = "technical_trace"`. Disabled for `nano` tier.

UX rule actually implemented in Gradio: when `ui_shadows_enabled` is turned on, if `ui_shadow_detail < Detallado` it is auto-promoted to `Detallado`, and if `ui_shadow_weight < Suave` it is auto-promoted to `Suave`. (Function `topography_enabled_changed`.)

### Stage B — What "Generate" does (`run_pipeline` in `app/pipeline/__init__.py`)
1. Validate `prompt_mode` and `resolution`.
2. **Content classification** — 1 Gemini Flash Lite call → returns `(content_type, confidence)`. Categories include at least: `portrait, animal, geometric, floral, lettering, character, abstract`.
3. Compute `input_mpx = h*w/1_000_000`. Flag `resolution_warning = (input_mpx < 1.0 AND resolution == "4K")`.
4. **Stencil generation**, branching on tier:
   - `flash` / `pro` → 1 Gemini image-gen call (Gemini 3.1 Flash Image / Gemini 3 Pro Image), `refine_stencil(...)`.
   - `gpt_mini` / `gpt_flash` / `gpt_pro` → 1 OpenAI image-gen call (`gpt-image-1-mini` / `gpt-image-1.5` / `gpt-image-2`), `refine_stencil_gpt(...)`.
   - `nano` → local OpenCV: grayscale → CLAHE(2.0, 8×8) → resolve style+content params → `detect_edges`. Zero image-gen API calls. Here `grosor_linea` and `contraste` actually matter.
5. **Export**:
   - `export_stencil` → PNG bytes, 300 DPI, no compression, pass-through size.
   - `export_preview` → WebP, longest side scaled to 1366 px, lossless.

`gemini_calls` reported in `usage`: `nano=1, flash=2, pro=2, gpt_*=1` (classification counts even when the gen API is OpenAI's).

### Stage C — Receiving the response
The two URLs returned by the API are short-lived presigned S3 GETs. Display `preview_webp` for fast on-screen display; download `stencil_png` only when the user exports.

`usage.resolution_warning = true` should be surfaced to the user ("low-resolution source, results at 4K may be soft") — it is purely informational, the call still succeeded.

---

## 3. Style parameter system (only relevant for `nano` tier)

Defined in `app/styles/config.py`. Three layers stack:

1. **Style preset** — picks a `StyleConfig` (Canny low/high, dilation iters, kernel, bilateral filter, CLAHE clip/tile). 15 presets covering ultra-fine, shading, traditional, geometric, narrative, watercolor families.
2. **User overrides** —
   - `contraste` (1–10) remapped via factor `0.5 + (contraste-1)*(1.5/9)` → multiplies the preset's `clahe_clip`. (1→0.5×, 5→~1.17×, 10→2.0×.)
   - `grosor_linea` (1–5) → bonus dilation iterations: `{1:0, 2:0, 3:1, 4:2, 5:3}`.
3. **Content modifier** — selected by the classifier's `content_type`. Adjusts `bilateral_sigma_factor`, `clahe_clip_factor`, `min_component_size`, and optionally `use_skeleton`. `puntillismo` overrides `min_component_size=5` to preserve intentional dots.

For AI tiers (everything that is not `nano`), `grosor_linea`/`contraste` are sent in the payload but ignored — the AI prompt is built from `estilo`, `prompt_mode`, and `prompt_config`.

---

## 4. Client-side retouching (Gradio only — must be reimplemented client-side on iPad)

After generation, the Gradio UI lets the user retouch the stencil **without re-running the pipeline**. Every slider runs locally via OpenCV/NumPy on the cached stencil array. **None of this exists in the HTTP API.**

Function: `_apply_retouching_binary` in `frontend/app.py`.

Pipeline of operations (in order):
1. **Convert to grayscale uint8** if not already.
2. **Threshold** — slider `10..250`, default `128`. Higher = fewer pixels become lines.
   - **Internal coupling**: the *Line Thickness* slider also nudges the threshold by `±line_weight * 4`, clamped to `[-24, +24]`, clamped final threshold to `[1, 254]`. So pushing thickness up also makes lines a touch darker before morphology runs.
3. **Line Thickness** — slider `-10..+10`, default `0`. Only applies morphology when `|value| ≥ 4`:
   - kernel: `MORPH_CROSS 3×3`, iterations: 1.
   - positive → `cv2.dilate` (thicker), negative → `cv2.erode` (thinner).
   Below the threshold the slider is a no-op (it still tweaks threshold via the coupling above).
4. **Denoise (pre-threshold)** — slider `0..8`, default `0`. Speckle cleanup via connected-components: drops components whose area is below `max(1, pre_blur*2)` px. Removes isolated dots without warping deliberate lines.
5. **Noise Filter (px²)** — slider `0..3000` step 10, default `0`. Same connected-components approach but using the user's literal area threshold. Removes isolated components smaller than N pixels.
6. **Close Gaps** — slider `0..25`, default `0`. Bridges small gaps via morphological closing:
   - horizontal kernel `(amount+2, 1)`, vertical kernel `(1, amount+2)`, both OR'd into the result.
   - If `amount >= 4`, also adds a small `MORPH_CROSS 3×3` closing pass.
   - `amount` is internally clamped to `min(value, 6)`.
7. **Smooth Edges** — checkbox. `MORPH_OPEN` with `MORPH_ELLIPSE 2×2` then `MORPH_CLOSE` with `MORPH_ELLIPSE 3×3`. Removes jagged stair-step edges.
8. **Sharpen Lines** — checkbox. Single `MORPH_CLOSE` with `MORPH_RECT 2×2`. Reconnects tiny breaks at corners.
9. **Invert** — checkbox. `cv2.bitwise_not` at the end. White-on-black instead of black-on-white.

Output: a clean binary uint8 array (255 white background, 0 black lines). This array is cached as `retouched_binary_state` for instant color/overlay updates.

### Line color (instant — no retouching re-run)
Function: `_colorize`. Reads cached binary, paints pure-black pixels (`gray == 0`) with the chosen RGB, leaves background white. Uses `== 0` not `< 128` to avoid LANCZOS halo coloring.

Three presets, RGB:
- **Black** → `None` (keep grayscale)
- **Red** → `(200, 20, 20)` (red transfer paper)
- **Blue** → `(0, 80, 210)` (blue/purple hectograph transfer paper)

### Reference overlay preview
Function: `_make_overlay_preview`. Composites the stencil over a brightness-adjusted, opacity-controlled copy of the original photo. Three sliders:
- **Stencil opacity** `0..100` step 5, default `85`.
- **Reference opacity** `0..100` step 5, default `45`.
- **Reference brightness** `50..150` step 5, default `100`. Clamped to `[0.25, 2.0]` factor.

Math (after resizing original to the stencil's `(w, h)` via LANCZOS):
```
canvas    = reference * ref_alpha + white * (1 - ref_alpha)   # faded background
line_mask = stencil_gray < 128
canvas[line_mask] = canvas[line_mask] * (1 - line_alpha) + line_rgb * line_alpha
```
Result is `uint8 RGB`. This is a preview only — full-quality export ignores it.

---

## 5. Exports (four download buttons)

1. **Provider-native stencil (PNG)** — raw `stencil_url` bytes. Untouched by retouching.
2. **Retouched version (PNG)** — the post-retouching, post-color-swap array written as PNG.
3. **Exportar para Procreate (PNG)** — `export_for_procreate` in `app/pipeline/export.py`:
   - Take the full-res stencil.
   - Force RGB.
   - Build alpha channel: `alpha[pixel where all RGB > 240] = 0`, else `255`. (White background becomes transparent.)
   - PNG, 300 DPI, no compression.
4. **Generar nuevo PSD Procreate** — `export_api_procreate_layers` + `generate_procreate_api_layers` in `app/pipeline/procreate_layers.py`.

### Procreate layered PSD (the heavy export)

Five possible layers, user picks any subset via checkbox:
- `original` — the reference photo (local, no API call)
- `main_frame` — structural outlines only (1 API call)
- `topography` — broken-line tonal-zone guides (1 API call)
- `details` — fine internal details (1 API call)
- `merged` — the already-generated stencil (local, no API call)

The three **semantic layers** (`main_frame`, `topography`, `details`) each trigger a **separate image-generation API call** with a layer-specific prompt. They run **in parallel** via `ThreadPoolExecutor(max_workers=min(n, 3))`.

Rules:
- `nano` tier cannot generate semantic layers (raises). User must switch to an API tier.
- Generating semantic layers requires the original reference photo to still be in memory.
- Layer order in the final PSD: `details, topography, main_frame, merged, original` (bottom-up).
- Layer prompts are built from style + content_type + the same `prompt_config` (notably `ui_shadow_detail` and `ui_shadow_weight` for the topography layer).

Cost shown to the user before export:
- 0 semantic layers selected → free, local packaging only.
- N semantic layers → `N × per_image_cost + 1 Gemini classification call`.
- Per-image cost = `GENERATION_OUTPUT_ESTIMATES[tier][resolution]` (table below).

---

## 6. Cost / pricing display

Hard-coded estimates the Gradio UI shows. These are just display labels — server doesn't enforce or know about them.

| Tier | 1080p | 2K | 4K | Notes |
|---|---|---|---|---|
| `nano` | $0.000 | $0.000 | $0.000 | Local OpenCV, no API |
| `flash` | $0.067 | $0.101 | $0.151 | Gemini 3.1 Flash Image |
| `pro` | $0.135 | $0.135 | $0.241 | Gemini 3 Pro Image (only one with a real 4K bump) |
| `gpt_mini` | $0.006 | $0.006 | $0.006 | Token-metered floor |
| `gpt_flash` | $0.013 | $0.013 | $0.013 | Token-metered floor |
| `gpt_pro` | $0.050 | $0.050 | $0.050 | Token-metered floor |

GPT tiers are token-metered — the dollar figure is the output floor, input tokens add on top.

---

## 7. Constraints the iPad app must enforce client-side (mirror server validations)

- Image ≤ 15 MB before upload.
- `request_id` is a UUID v4.
- `6K` is not a valid export option (don't even show it).
- `technical_trace` + `nano` is disallowed — disable the Technical Trace button when `nano` is selected.
- `prompt_mode != "technical_trace"` if `tier == "nano"`.
- `s3_key` returned by `/presigned-upload` is what gets sent to `/stencil`; client never constructs it.

---

## 8. Mapping: which Gradio features will the iPad app need to re-implement client-side

| Feature | Lives where today | iPad app responsibility |
|---|---|---|
| Image upload | Gradio `gr.Image` widget | PHPicker / drag-drop / paste |
| Style/tier/resolution pickers | Gradio components | Native pickers driven by enum lists |
| Cost estimate string | `_estimate_cost` in `frontend/app.py` | Re-implement with the table in §6 |
| Calling the pipeline | Direct Python import | HTTP: `/presigned-upload` → S3 `PUT` → `/stencil` |
| Generated stencil display | `gr.Image` | Async-load `preview_url` (WebP) for screen; keep `stencil_url` for export |
| Detected content + time + tier readouts | Gradio textboxes | Native text from response |
| Retouching (threshold, thickness, denoise, noise filter, close gaps, smooth, sharpen, invert) | `_apply_retouching_binary` (OpenCV) | **Native re-implementation** — Core Image or Metal (`CIMorphologyMaximum`, `CIMorphologyMinimum`, threshold via `CIColorThreshold`, connected components via custom Metal pass) |
| Line color swap | `_colorize` | Trivial — paint exact-black pixels with chosen RGB on the cached array |
| Reference overlay (3 sliders) | `_make_overlay_preview` | Composite the photo + cached binary with the same math; do it as a `CALayer` blend or Metal |
| Download retouched PNG | `export_retouched_png` | Use Files / Share Sheet on the result |
| Procreate transparent PNG | `export_for_procreate` (alpha from `RGB > 240`) | Replicate; trivial pixel pass |
| Procreate layered PSD | `export_api_procreate_layers` — calls the **server again** N times | Server today doesn't expose this over HTTP. **Two options**: (a) add a new server endpoint `POST /procreate-layers` that wraps `generate_procreate_api_layers`, (b) defer this feature in v1 |

The Procreate layered PSD path is the single biggest gap: the Gradio UI calls a **Python function** that today is only reachable in-process. To support it from iPad, the microservice must grow an HTTP endpoint around `generate_procreate_api_layers` + `export_api_procreate_layers`.

---

## 9. Quick state machine

```
[idle]
  └─ user picks image + estilo + tier + resolution + prompt_config
       └─ press "Generate Stencil" / "Technical Trace"
            │
            ▼
[uploading] ── POST /presigned-upload ──> PUT to S3
            │
            ▼
[generating] ── POST /stencil ──> wait ~3–10s depending on tier
            │
            ▼
[result-loaded] ── show preview, content_type, time, tier, optionally resolution_warning
            │
            ├─ user adjusts retouching sliders ─► [retouching] (client-only, instant)
            ├─ user swaps line color           ─► [colorized] (client-only, instant)
            ├─ user adjusts overlay sliders    ─► [overlay-preview] (client-only, instant)
            │
            └─ user picks an export:
                  ├─ download original stencil PNG       (read stencil_url)
                  ├─ download retouched PNG              (write local array)
                  ├─ download Procreate transparent PNG  (alpha from white pixels)
                  └─ generate Procreate PSD              (NEEDS NEW API ENDPOINT)
```

---

## 10. TL;DR

- **HTTP API has 3 endpoints**: `/health`, `/presigned-upload`, `/stencil`. Everything else (retouching, overlay, color swap, single-PNG Procreate export) is **client-side OpenCV/NumPy in the Gradio file** and must be ported natively on iPad.
- **Generation is one round-trip**: upload to S3 → call `/stencil` → get two presigned URLs.
- **Six tiers, 15 styles, 3 resolutions, 2 prompt modes, 6 prompt_config fields** define the generation request.
- **Nano is the only tier that uses `grosor_linea`/`contraste`** (the OpenCV-only path).
- **Procreate layered PSD is the only feature that needs a new server endpoint** — every other Gradio feature is either already in the API or trivially client-side.
