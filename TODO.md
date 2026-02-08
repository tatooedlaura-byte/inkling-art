# Dot Art / Pointillism Canvas Mode

Third canvas mode for Inkling Art — pointillist-style painting where you tap to place individual dots that build up an image.

## Core Interaction

Tap to place dots. Each dot is a filled circle at a given position, size, and color.

## Left-Hand Size Slider

- Persistent vertical slider pinned to the left edge of the screen
- Slide up = bigger dots, slide down = smaller dots
- Control with left thumb while placing dots with Apple Pencil in right hand
- Shows a live dot-size preview circle that scales as you drag
- Range: ~2pt to ~60pt

## Placement Modes (toggle within dot art)

- **Free-form** — dots land exactly where you tap, natural/painterly
- **Grid-snap** — dots align to grid positions, structured/mosaic look

## Data Model

- `DotMark` struct: center, radius, color
- `DotCanvas` class: array of dots, add/remove/clear, hit-testing, render to image

## Tools Supported

- Pencil — tap to place dots
- Eraser — tap near a dot to remove it
- Eyedropper — sample color
- Fill — fill canvas with dots at current size/color
- Select — marquee, flip, move (same as pixel/smooth)

## Undo/Redo

Stack-based array snapshots (dots are lightweight).

## Files to Create

1. `PixelArtEditor/Models/DotMark.swift` — data model
2. `PixelArtEditor/Views/DotArtCanvasUIView.swift` — UIView with scroll/zoom, tap gestures, left-hand slider, Core Graphics rendering
3. `PixelArtEditor/Views/DotArtCanvasView.swift` — SwiftUI wrapper (same pattern as SmoothCanvasView)

## Files to Modify

4. `PixelArtEditor/Models/Tool.swift` — add `case dotArt` to `CanvasMode`
5. `PixelArtEditor/Views/ContentView.swift` — add `.dotArt` case to render `DotArtCanvasView`
6. `PixelArtEditor/Models/CanvasStore.swift` — add `dotArtCanvasView` property

## What Auto-Works (no changes needed)

- ToolbarView — `ForEach(Tool.allCases)` picks up tools automatically
- TopBarView — `ForEach(CanvasMode.allCases)` picks up new mode automatically
- ColorPaletteView — shared across all modes
