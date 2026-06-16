# Fliper: Scale-from-Center Magnify Effect

## Problem

Tapping a thumbnail to open the fullscreen image viewer uses `matchedGeometryEffect` for a hero transition, but it feels like a shape resize rather than a magnify/zoom-in effect. The thumbnail morphs to fullscreen without the satisfying "grows from center" feel that iOS Photos provides.

## Solution

Add a scale-from-center magnify effect that works on top of the existing `matchedGeometryEffect` hero transition. The image will visually zoom in from the thumbnail's relative scale to fullscreen on open, and shrink back on dismiss.

## Architecture

Replace `fullScreenCover` presentation with a custom overlay-based presentation that uses `matchedGeometryEffect` for position tracking combined with an animated `scaleEffect` for the magnify feel. The transition is driven by an `animationProgress` state (0.0 to 1.0).

### Components

#### 1. FliperTransition (new internal view modifier)

A transition controller that:
- Tracks `animationProgress` state (0.0 to 1.0)
- On appear: animates `animationProgress` to 1.0 with a spring animation
- On dismiss: animates `animationProgress` to 0.0, then calls `onDismissComplete`
- Drives background opacity from 0 to 1 using `animationProgress`
- Drives a `scaleEffect` on the image content from a small initial scale to 1.0 using `animationProgress`

#### 2. FliperThumbnail (no changes)

Already sets `matchedGeometryEffect` and triggers `isPresented`. No modifications needed.

#### 3. FliperViewer (modified)

- Accept an `animationProgress` binding to drive the scale effect
- Apply `scaleEffect` based on `animationProgress` (small scale at 0, 1.0 at 1)
- The `matchedGeometryEffect` continues to handle position tracking

#### 4. ContentView / demo app (modified)

- Replace `.fullScreenCover` with an `overlay` that conditionally shows `FliperViewer`
- The viewer appears/disappears based on `isPresented` with the custom transition

### Animation Details

- **Open:** Spring animation (`.spring(response: 0.35, dampingFraction: 0.85)`) — slightly underdamped for a satisfying "pop"
- **Dismiss:** Same spring in reverse, triggered by the drag-to-dismiss gesture
- **Scale calculation:** The `matchedGeometryEffect` handles position/size interpolation automatically. The `scaleEffect` starts at a small value (proportional to thumbnail size relative to screen, read from a GeometryReader) and animates to 1.0 via `animationProgress`. This creates the magnify feel on top of the hero transition.
- **matchedGeometryEffect** handles the position/size morph; `scaleEffect` adds the magnify feel on top

### Data Flow

1. User taps thumbnail → `isPresented = true`, `selection = index`
2. Overlay renders `FliperViewer` with `animationProgress` starting at 0
3. On appear, `animationProgress` animates to 1 — image scales up from thumbnail proportion to fullscreen
4. On dismiss gesture, `animationProgress` animates back to 0 — image shrinks back
5. When `animationProgress` reaches 0, the overlay is removed

### Files to Modify

- `Sources/Fliper/Internal/FliperTransition.swift` — new file
- `Sources/Fliper/Public/FliperViewer.swift` — add `animationProgress` binding, apply scale effect
- `Demo/FliperDemo/FliperDemo/ContentView.swift` — replace `fullScreenCover` with overlay
