# RotatingCube Agent Notes

This project is a native macOS Metal app plus screensaver plus offline render tool for a wireframe cube above a retro grid floor.

## Project Structure

- `project.yml`
  - XcodeGen source of truth. Do not hand-edit the `.xcodeproj` unless absolutely necessary.
- `Sources/RotatingCubeCore`
  - Shared renderer, scene spec, math, geometry, shaders, and MP4 export logic.
- `Sources/RotatingCubeApp`
  - Native preview app shell.
- `Sources/RotatingCubeSaver`
  - macOS `.saver` bundle wrapper around the same Metal view.
- `Sources/RotatingCubeRenderTool`
  - CLI exporter for silent MP4 output.
- `Tests/RotatingCubeCoreTests`
  - Geometry, projection, and timing regression tests.

## Rendering Model

- The scene is fully data-driven from `SceneSpec.defaultWallpaper` in `Sources/RotatingCubeCore/SceneSpec.swift`.
- The renderer builds line primitives in `Sources/RotatingCubeCore/SceneGeometry.swift`.
- Camera math lives in `Sources/RotatingCubeCore/MatrixMath.swift`.
- Frame cadence and quantized motion live in `Sources/RotatingCubeCore/RendererTimeline.swift`.
- Metal drawing and post-process passes live in:
  - `Sources/RotatingCubeCore/RotatingCubeMetalRenderer.swift`
  - `Sources/RotatingCubeCore/RotatingCubeShaders.metal`

## Current Approved Baseline

These are the current reset values. Treat them as the visual baseline unless the user explicitly approves a new one.

- Cube
  - `size = 3.2`
  - `center = (0, 1.98, 0)`
  - `lineStyle.coreWidthPixels = 4.6`
  - `lineStyle.glowWidthPixels = 18.0`
  - `lineStyle.coreOpacity = 1.0`
  - `lineStyle.glowOpacity = 0.40`
  - `lineStyle.coreIntensity = 1.40`
  - `lineStyle.glowIntensity = 2.50`
  - `depthHierarchy.nearCoreScale = 1.15`
  - `depthHierarchy.farCoreScale = 0.78`
  - `depthHierarchy.nearGlowScale = 1.40`
  - `depthHierarchy.farGlowScale = 0.60`
  - `xTiltDegrees = 30`
  - `initialYawDegrees = 45`
  - `xRevolutionsPerLoop = 1`
  - `yRevolutionsPerLoop = 2`
- Grid
  - `extent = 26`
  - `spacing = 0.72`
  - `y = -1.4`
  - `lineStyle.coreWidthPixels = 3.4`
  - `lineStyle.glowWidthPixels = 5.2`
  - `lineStyle.coreOpacity = 0.58`
  - `lineStyle.glowOpacity = 0.06`
  - `lineStyle.coreIntensity = 0.80`
  - `lineStyle.glowIntensity = 1.00`
  - `distanceFalloff.startDepth = 14.0`
  - `distanceFalloff.endDepth = 34.0`
  - `distanceFalloff.minimumCoreScale = 0.35`
  - `distanceFalloff.minimumGlowScale = 0.20`
- Camera
  - `position = (0, 4.14, 13.0)`
  - `target = (0, 1.3, 0)`
  - `upVector = (0, -1, 0)`
  - `fieldOfViewDegrees = 36`
  - `pitchDegrees = 0`
  - `nearPlane = 0.1`
  - `farPlane = 120`
- Timing
  - `durationSeconds = 30`
  - `simulationFPS = 30`
  - `outputFPS = 30`
- Output
  - `3840 x 2160`
  - `h264`
  - `30_000_000` average bitrate
- CRT / post
  - CRT effects are tuned for a punchier menace pass without changing the overall composition.
  - `bloomThreshold = 0.56`
  - `bloomIntensity = 0.26`
  - `bloomRadius = 2.4`
  - `scanlineIntensity = 0.28`
  - `scanlineDensity = 1.0`
  - `phosphorMaskIntensity = 0.04`
  - `vignetteIntensity = 0.08`
  - `barrelDistortion = 0.035`
  - `cornerPinch = 0.0`
  - `edgeFillMode = crop`
  - `overscanScaleX = 1.12`
  - `overscanScaleY = 1.04`

## Camera Reset

- Use `SceneSpec.baselineWallpaperCamera` in `Sources/RotatingCubeCore/SceneSpec.swift` as the reset target.
- `SceneSpec.defaultWallpaper.camera` should equal `SceneSpec.baselineWallpaperCamera` unless the user has explicitly approved a new baseline.
- If you change the camera temporarily for tuning:
  - update `defaultWallpaper.camera`
  - do **not** update `baselineWallpaperCamera` unless the user wants the new framing to become the new baseline
  - use `camera.pitchDegrees` for direct vertical tilt in degrees before changing target y

## Safe Tuning Rules

### For perspective tweaks

Prefer changing the camera before touching geometry:

- Raise/lower `camera.position.y`
  - changes horizon height
- Move `camera.position.z`
  - changes scene compression / depth feel
- Change `camera.target.y`
  - changes where the camera looks without moving the camera body
- Change `camera.pitchDegrees`
  - direct vertical tilt in degrees around the local right axis
- Change `camera.fieldOfViewDegrees`
  - changes how dramatic the grid perspective feels

### For cube placement tweaks

- Change `cube.center.y`
  - use this only when the user explicitly wants the cube moved in frame
- Do not change cube size or tilt just to fix perspective problems

### For grid / floor tweaks

- Change `grid.extent`
  - use this first when the grid looks like a finite board and the side edges are visible
- Change `grid.y`
  - use this only for actual floor height changes
- Avoid using `grid.spacing` as the first knob for perspective work
  - it changes the style/density of the grid, not just its footprint
- If barrel distortion creates black edge gutters, adjust `crt.overscanScaleX` and `crt.overscanScaleY` before changing camera or grid geometry

## Important Constraints

- Do **not** reintroduce a full-frame `180°` post-process flip in `RotatingCubeShaders.metal`.
  - Orientation should be solved in camera space, not by flipping the composite.
- Do **not** remove the first-frame readiness behavior in `RotatingCubeMetalRenderer`.
  - It waits for valid drawable size and resets animation start time to avoid bad startup frames.
- Keep the spectral cube look locked unless the user explicitly asks for color changes.
- Keep the grid floor wide enough that its side edges stay offscreen on 16:9 displays unless the user asks for a different framing.

## Known Tests And What They Protect

`Tests/RotatingCubeCoreTests/SceneGeometryTests.swift`

- `testDefaultWallpaperUsesBaselineCameraPreset`
  - baseline camera stays wired in
- `testDefaultWallpaperGridExtendsPastViewportSides`
  - floor still reads as effectively infinite on widescreen
- `testDefaultWallpaperProjectsFloorWithinCubeVerticalSpan`
  - floor still projects through the expected part of the scene
- other tests cover cube topology and color continuity

`Tests/RotatingCubeCoreTests/RendererTimelineTests.swift`

- protects loop length and frame cadence

## Verification Commands

Run these after any visual or timing change:

```bash
xcodebuild -project /Users/josh/rotating-cube/RotatingCube.xcodeproj -scheme RotatingCubeApp -destination 'platform=macOS' test
xcodebuild -project /Users/josh/rotating-cube/RotatingCube.xcodeproj -scheme RotatingCubeRenderTool -destination 'platform=macOS' build
```

Use this for manual preview:

```bash
open /Users/josh/rotating-cube/RotatingCube.xcodeproj
```

Use this for export:

```bash
/Users/josh/Library/Developer/Xcode/DerivedData/RotatingCube-dmoaxdrbqxitndgeksaxorsgsnsw/Build/Products/Debug/RotatingCubeRenderTool --output ~/Desktop/RotatingCube-4K-Loop.mp4
```

## Agent Guidance

- Default to small, isolated visual changes.
- When the user says “keep X fixed,” respect that by adjusting only the requested subsystem.
  - Example: if cube framing is approved, do camera or grid changes without moving the cube.
- If you promote a new baseline, update this file too.
