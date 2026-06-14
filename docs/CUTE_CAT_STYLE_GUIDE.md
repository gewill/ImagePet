# Cute Cat Style Guide

## Design Goal

Cute Cat is ImagePet's default desktop pet theme. It should feel like a small macOS desk sticker with enough personality to make compression feedback visible at a glance.

The theme is not a mascot platform. It is a single polished built-in character for PRD v0.6.

## Character Shape

- Use a chibi cat proportion: oversized head, compact body, small paws, and a readable tail silhouette.
- Keep the full character legible at the Mini pet size, where the rendered frame is roughly 64 points wide.
- Prefer asymmetric details over perfect geometry: one ear can sit slightly higher, the head can lean by state, and the tail curve can carry the pose.
- Avoid generic circles and triangles as the only construction language. The final silhouette should read as a designed character, not a diagram.

## Palette

- Fur: warm orange, slightly less saturated than pure system orange.
- Outline: warm dark brown, used sparingly to preserve small-size readability.
- Belly and paws: warm cream rather than pure white.
- Inner ears and blush: soft salmon pink.
- Alert accents: restrained blue for sweat and red/orange only for issues indicators.

Use transparent PNG frames. Do not add a solid background.

## Animation Language

- Idle: quiet breathing, tail drift, occasional blink. The silhouette should barely move.
- Drag Hover: the cat leans forward like it is waiting to be fed an image.
- Eating: cheek and mouth motion should sell the compression metaphor; small image crumbs are acceptable if they stay readable.
- Done: use anticipation, jump, and settle. Confetti should support the cat, not cover it.
- Issues: avoid only using dead or crossed eyes. Prefer a confused tilt, sweat, and a small warning/question cue.
- Stretch and Yawn: the action must change the silhouette enough to be visible at Mini size.
- Petting: soft closed eyes, blush, and a faster tail wag.
- Sleep: static enough to feel low energy, with small "Z" marks if they remain readable.

## Frame Budget

- Canvas: 256 x 256 transparent PNG.
- Theme budget: under 3 MB.
- Per-animation budget: no more than 24 frames.
- P0 target: 8-12 fps. Hold frames are allowed for character acting, but the runtime should remain simple.

## Acceptance Checklist

- The idle frame reads as a cat at 64 points without relying on labels.
- Each core business state has a distinct silhouette: Ready, Drag Hover, Eating, Done, Issues.
- The cat does not clip in Mini or Full pet views.
- The resource test validates dimensions, frame counts, and total theme size.
- Asset generation is an explicit script, not a normal unit test side effect.
