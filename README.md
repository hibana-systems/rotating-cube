# RotatingCube

Native macOS Metal app, screensaver, and offline render tool for a spectral wireframe cube floating above a retro grid floor.

## What This Repo Contains

- `RotatingCubeApp`
  - macOS preview app for live tuning
- `RotatingCubeSaver`
  - native `.saver` bundle using the same Metal renderer
- `RotatingCubeRenderTool`
  - CLI exporter for silent MP4 output
- `RotatingCubeCore`
  - shared scene spec, geometry, math, Metal renderer, and shaders

The project is driven by `project.yml` and generated with XcodeGen. The checked-in `.xcodeproj` is present for convenience, but `project.yml` is the source of truth.

## Current Baseline

This is the current approved baseline for future tweaks.

### Cube

- `size = 3.2`
- `center = (0, 1.98, 0)`
- `xTiltDegrees = 30`
- `initialYawDegrees = 45`
- `xRevolutionsPerLoop = 1`
- `yRevolutionsPerLoop = 2`

### Grid

- `extent = 26`
- `spacing = 0.72`
- `y = -1.4`

### Camera

- `position = (0, 4.14, 13.0)`
- `target = (0, 1.3, 0)`
- `upVector = (0, -1, 0)`
- `pitchDegrees = 0`
- `fieldOfViewDegrees = 36`
- `nearPlane = 0.1`
- `farPlane = 120`

### Timing

- `durationSeconds = 30`
- `simulationFPS = 30`
- `outputFPS = 30`

### Output

- `3840 x 2160`
- `h264`
- `30_000_000` average bitrate

### CRT / Post

The CRT stack exists in the renderer, and the current baseline uses restrained bloom, scanlines, and overscanned barrel warp:

- `bloomThreshold = 0.68`
- `bloomIntensity = 0.10`
- `bloomRadius = 1.5`
- `scanlineIntensity = 0.12`
- `scanlineDensity = 1.0`
- `phosphorMaskIntensity = 0.0`
- `vignetteIntensity = 0.08`
- `barrelDistortion = 0.035`
- `cornerPinch = 0.0`
- `edgeFillMode = crop`
- `overscanScaleX = 1.12`
- `overscanScaleY = 1.04`

## Camera Reset

The reset target is codified in:

- `SceneSpec.baselineWallpaperCamera`

File:

- `/Users/josh/rotating-cube/Sources/RotatingCubeCore/SceneSpec.swift`

`SceneSpec.defaultWallpaper.camera` should match that preset unless a new baseline has been explicitly approved.

## Running The Preview App

Open the project in Xcode:

```bash
open /Users/josh/rotating-cube/RotatingCube.xcodeproj
```

Then run the `RotatingCubeApp` scheme.

## Building / Testing

Run the standard verification commands after visual or timing changes:

```bash
xcodebuild -project /Users/josh/rotating-cube/RotatingCube.xcodeproj -scheme RotatingCubeApp -destination 'platform=macOS' test
xcodebuild -project /Users/josh/rotating-cube/RotatingCube.xcodeproj -scheme RotatingCubeRenderTool -destination 'platform=macOS' build
```

Build the screensaver bundle:

```bash
xcodebuild -project /Users/josh/rotating-cube/RotatingCube.xcodeproj -scheme RotatingCubeSaver -destination 'platform=macOS' build
```

## Exporting MP4

Render the default silent loop:

```bash
/Users/josh/Library/Developer/Xcode/DerivedData/RotatingCube-dmoaxdrbqxitndgeksaxorsgsnsw/Build/Products/Debug/RotatingCubeRenderTool --output ~/Desktop/RotatingCube-4K-Loop.mp4
```

Useful options:

```bash
--output /path/to/file.mp4
--width 3840
--height 2160
--seconds 30
```

## File Ownership

These are the main files to edit, depending on what you want to change.

### Scene and baseline config

- `/Users/josh/rotating-cube/Sources/RotatingCubeCore/SceneSpec.swift`

This is the main tuning surface for:

- cube placement and motion defaults
- grid footprint and floor height
- camera framing and FOV
- loop cadence
- output settings
- CRT defaults

### Geometry

- `/Users/josh/rotating-cube/Sources/RotatingCubeCore/SceneGeometry.swift`

This controls:

- cube edge generation
- grid line generation
- cube spectral endpoint coloring

### Camera / projection math

- `/Users/josh/rotating-cube/Sources/RotatingCubeCore/MatrixMath.swift`

Change this only if the problem is truly projection/orientation math. Do not use it for routine framing tweaks.

### Renderer and startup behavior

- `/Users/josh/rotating-cube/Sources/RotatingCubeCore/RotatingCubeMetalRenderer.swift`

This controls:

- MTKView setup
- frame timing hookup
- first-frame readiness behavior
- render passes

### Shader behavior

- `/Users/josh/rotating-cube/Sources/RotatingCubeCore/RotatingCubeShaders.metal`

This controls:

- line anti-aliasing
- bloom pass
- blur pass
- CRT composite pass

## Safe Tuning Guide

### If the perspective feels off

Change the camera before changing geometry:

- raise/lower `camera.position.y`
  - moves the horizon
- move `camera.position.z`
  - changes scene compression / depth
- change `camera.target.y`
  - changes where the camera looks
- change `camera.pitchDegrees`
  - direct vertical tilt in degrees around the local right axis
- change `camera.fieldOfViewDegrees`
  - changes how dramatic the floor perspective feels

### If the cube needs to move in frame

Change:

- `cube.center.y`

Do not change cube size or tilt just to fix perspective.

### If the floor looks like a finite board

Change:

- `grid.extent`

This is the main control for keeping the side edges offscreen on wider displays.

If CRT barrel distortion creates black side gutters, change:

- `crt.overscanScaleX`
- `crt.overscanScaleY`

before changing camera or grid geometry.

### If the floor is physically too high or too low

Change:

- `grid.y`

### If the animation cadence needs to change

Change:

- `loop.simulationFPS`
- `loop.outputFPS`

Keep them matched unless there is a deliberate reason to decouple them.

## Important Do-Nots

- Do not reintroduce a full-frame `180°` post-process flip in the shader.
- Do not remove the renderer’s first-frame readiness behavior.
- Do not change the spectral cube look unless color changes are explicitly requested.
- Do not promote a new camera baseline without also updating `baselineWallpaperCamera`.

## Regression Tests

Useful tests in:

- `/Users/josh/rotating-cube/Tests/RotatingCubeCoreTests/SceneGeometryTests.swift`
- `/Users/josh/rotating-cube/Tests/RotatingCubeCoreTests/RendererTimelineTests.swift`

These cover:

- loop timing
- cube topology
- color continuity
- floor placement
- widescreen grid coverage
- baseline camera wiring

## Regenerating The Project

If you change `project.yml`, regenerate the Xcode project with XcodeGen:

```bash
xcodegen generate
```

Then re-run the build/test commands above.
