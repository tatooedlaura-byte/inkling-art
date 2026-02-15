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

1. `InklingArt/Models/DotMark.swift` — data model
2. `InklingArt/Views/DotArtCanvasUIView.swift` — UIView with scroll/zoom, tap gestures, left-hand slider, Core Graphics rendering
3. `InklingArt/Views/DotArtCanvasView.swift` — SwiftUI wrapper (same pattern as SmoothCanvasView)

## Files to Modify

4. `InklingArt/Models/Tool.swift` — add `case dotArt` to `CanvasMode`
5. `InklingArt/Views/ContentView.swift` — add `.dotArt` case to render `DotArtCanvasView`
6. `InklingArt/Models/CanvasStore.swift` — add `dotArtCanvasView` property

## What Auto-Works (no changes needed)

- ToolbarView — `ForEach(Tool.allCases)` picks up tools automatically
- TopBarView — `ForEach(CanvasMode.allCases)` picks up new mode automatically
- ColorPaletteView — shared across all modes

---

# Tangram Mode (Future Feature)

A new creative mode where users can drag preset geometric shapes onto the canvas and arrange them to create images, patterns, and designs.

## Core Concept

- Drag predefined shapes (triangles, squares, parallelograms, etc.) from a shape library onto the canvas
- Move, rotate, and possibly scale shapes to arrange compositions
- Color each shape individually
- Build traditional tangram puzzles, or create freeform art compositions

## Key Features

- **Shape Library**: Preset geometric shapes available to drag onto canvas
  - Traditional tangram pieces (2 large triangles, 1 medium triangle, 2 small triangles, 1 square, 1 parallelogram)
  - Additional geometric shapes (circles, hexagons, other polygons?)

- **Shape Manipulation**:
  - Drag to move
  - Rotate (two-finger rotation or rotation handle?)
  - Scale/resize (optional)
  - Layer ordering (bring to front/send to back)

- **Coloring**:
  - Select a shape and apply color from palette
  - Each shape maintains its own fill color
  - Optional: stroke color and width

- **Canvas Interaction**:
  - Tap to select shape
  - Drag to move
  - Tap empty space to deselect
  - Delete selected shape (trash button or gesture)

## Implementation Considerations

- New canvas mode or separate tool?
- Shape data model (position, rotation, scale, color, type)
- Hit testing for shape selection
- Rendering order (z-index/layers)
- Undo/redo for shape operations
- Save/export compositions

## Files to Create/Modify

- New shape data models
- Tangram canvas view
- Shape library UI component
- Update CanvasMode enum if new mode
