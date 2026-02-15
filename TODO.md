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

---

# Future Canvas Mode Ideas

Creative and experimental canvas types to explore.

## Symmetry/Kaleidoscope Canvases

### Mandala Mode
- Draw in one wedge section, auto-mirrors to create radial symmetry
- Adjustable number of mirror axes (4, 6, 8, 12, etc.)
- Instant symmetrical patterns
- Perfect for meditative drawing and decorative art

**Implementation**: Track strokes in one wedge, duplicate and rotate around center point

### Kaleidoscope Canvas
- Everything you draw reflects in real-time kaleidoscope patterns
- Multiple reflection axes create mesmerizing effects
- Adjustable number of reflections and angles

**Implementation**: Similar to mandala but with more complex reflection patterns

---

## Physics-Based Canvases

### Sand Art Mode
- "Pour" colored sand that falls and settles realistically
- Tilt iPad to shift sand around (use accelerometer)
- Layer different colors to create sand art compositions
- Optional: shake to mix/reset

**Implementation**: Particle system with gravity simulation, collision detection

### Watercolor Simulation
- Realistic wet-on-wet bleeding and color mixing
- Paint spreads and blends based on "wetness"
- Water droplets push paint around
- Colors mix naturally

**Implementation**: Fluid simulation, alpha blending, diffusion algorithms

### Spray Paint Mode
- Pressure-sensitive spray density
- Drips that run down over time
- Different nozzle sizes
- Layering with transparency
- Graffiti/street art aesthetic

**Implementation**: Particle spray system, drip physics, pressure curve mapping

---

## Pattern/Math Canvases

### Spirograph Mode
- Mathematical curve drawing with rotating circles
- Adjust inner/outer circle sizes and rotation ratios
- Creates satisfying geometric patterns
- Real-time preview as you adjust parameters

**Implementation**: Parametric equations for epicycloids and hypocycloids

### String Art Mode
- Place "pins" around the canvas edge or anywhere
- Connect pins with colored "strings"
- Creates geometric line patterns
- Like traditional nail-and-string artworks

**Implementation**: Pin placement, line rendering between points, layering

### Tessellation Canvas
- Draw a shape that automatically tiles seamlessly
- Create repeating patterns like M.C. Escher
- Adjust tile boundaries to see pattern updates
- Different tiling patterns (square, hexagonal, triangular)

**Implementation**: Shape transformations to ensure edge matching, tiling engine

---

## Reveal/Texture Canvases

### Scratch Art Mode
- Black surface covering rainbow colors (or custom color) underneath
- "Scratch away" the top layer to reveal colors below
- Like scratch-off cards or scratchboard art
- Different scratch widths

**Implementation**: Two-layer system - top mask layer, bottom color layer, eraser reveals bottom

### Light Painting Mode
- Draw glowing light trails that fade over time
- Long-exposure photography effect
- Trails blur and diminish gradually
- Different glow colors and intensities

**Implementation**: Trail rendering with alpha fade over time, glow/blur effects

### Origami Fold Mode
- Simulate paper folding
- Cut shapes while "folded"
- Unfold to reveal symmetrical designs
- Like making paper snowflakes digitally

**Implementation**: Virtual folding state machine, symmetry based on fold pattern

---

## Experimental/Text-Based

### ASCII Art Canvas
- Draw with text characters instead of pixels
- Different characters represent different densities/shades
- Retro computer art aesthetic
- Adjustable character size and font

**Implementation**: Convert brush strokes to character density, monospace font rendering

---

## Implementation Priority Considerations

**Easiest to Implement:**
1. Mandala Mode (symmetry is straightforward)
2. Scratch Art Mode (two-layer reveal)
3. Spirograph Mode (mathematical curves)

**Medium Complexity:**
1. String Art Mode
2. Light Painting Mode (fade effects)
3. ASCII Art Canvas

**Most Complex:**
1. Watercolor Simulation (fluid dynamics)
2. Sand Art Mode (particle physics)
3. Spray Paint Mode (drip physics)
4. Tessellation Canvas (edge matching algorithms)
