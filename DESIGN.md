# ImagePet Design System

Product: ImagePet
Platform: macOS
Personality: cute, lightweight, fast, trustworthy

## Design Direction

ImagePet is a native macOS image compression app built around a simple metaphor:

```text
a small desktop pet eats big images and outputs smaller files
```

The interface should feel soft and playful without becoming childish. ImagePet is still a utility: the app should make file status, savings, and next actions obvious, while the pet adds personality and feedback.

## Principles

- Native first: follow macOS interaction patterns, spacing, controls, menus, sheets, settings, and window behavior.
- Lightweight: keep the main workflow focused on adding images, choosing output behavior, compressing, and reviewing results.
- Fast: make progress, completion, and errors feel immediate. Avoid ornamental UI that slows scanning.
- Trustworthy: make file access, output location, overwrite behavior, and failures clear before destructive actions happen.
- Playful restraint: use the pet, warm color, soft motion, and friendly copy for delight, not noise.

## Visual Language

### Overall Feel

ImagePet should look like a polished macOS utility with a soft companion layer:

- warm cream surfaces
- mint green primary accents
- soft orange secondary accents
- rounded but not toy-like forms
- subtle depth and translucent materials where they fit native macOS
- clear hierarchy for queue status, output settings, and result summaries

The app should not look like a dense analytics dashboard or a corporate SaaS admin screen.

### Color

Use color to clarify state and make the app feel warm:

- Background: warm cream, off-white, and native macOS material surfaces.
- Primary accent: mint green for success, ready states, active controls, and pet-positive moments.
- Secondary accent: soft orange for savings, compression energy, and friendly highlights.
- Error accent: restrained red only for real failures or destructive confirmation.
- Warning accent: warm amber for recoverable or attention-needed states.
- Text: native macOS label colors first; avoid custom low-contrast text colors.

Avoid fake AI glow, neon gradients, and heavy purple or blue SaaS palettes.

### Typography

Use SF Pro as the default typeface. Prefer native macOS text styles and dynamic type behavior where possible.

Use a rounded feeling sparingly:

- Pet-related labels
- empty states
- completion moments
- friendly short captions

Do not make the whole app feel like a toy through oversized rounded type or bubbly display fonts.

### Shape And Layout

- Keep controls compact and predictable.
- Use 8px or smaller corner radii for standard cards and panels unless a native control defines otherwise.
- Reserve larger rounded shapes for pet surfaces, drop targets, and celebratory completion states.
- Prefer clear groups over nested cards.
- Preserve generous breathing room in empty and completion states, but keep active queue views dense enough to scan.

## Core Surfaces

### Main Window

The main window should be a focused compression workspace:

- Add images through drag and drop or native file picking.
- Show selected output behavior and compression options without hiding the primary action.
- Make per-file state readable at a glance.
- Show total savings as a friendly result, not a heavy metrics dashboard.
- Keep recovery actions close to the failed item or batch summary.

The first screen should communicate readiness immediately: ImagePet is waiting to be fed images.

### Desktop Pet

The desktop pet is the signature interaction. It should stay small, useful, and state-driven:

- Idle: subtle breathing, relaxed presence.
- Drag hover: anticipates receiving files.
- Processing: eats or chews images.
- Complete: small bounce and satisfied completion pose.
- Issues: confused or concerned, never alarming.

The pet should not duplicate complex app controls. It should surface the current state and route deeper decisions back to the main app.

### Settings

Settings should feel native and quiet:

- Use macOS settings conventions.
- Keep desktop pet options, shortcuts, output behavior, folder watching, notifications, and help clearly separated.
- Avoid promotional language.
- Make risky options explicit, especially overwrite and file-access behavior.

### Help

Help should be short, practical, and local-first:

- explain what ImagePet does
- explain safe file access and output behavior
- explain desktop pet states
- explain recovery paths for permission, failed files, and missing output folders

## Components

### Drop Target

The drop target should be warm, inviting, and obviously interactive. It may use the pet metaphor, but it must still read as a standard macOS drag-and-drop area.

Use mint accent for active drag hover. Use soft orange for compression energy or pending work.

### Queue Rows

Queue rows should prioritize:

- file name
- status
- input size
- output size
- savings
- recovery action when needed

Rows should be scannable and stable during updates. Avoid animated layout shifts.

### Summary

The summary should answer:

- how many files were compressed
- how much space was saved
- whether anything needs attention
- what the user can do next

Use friendly language, but keep numbers precise.

### Buttons

Use native button styles where possible. Primary actions should be clear and limited:

- Add Images
- Compress
- Reveal in Finder
- Retry Failed
- Clear List

Do not create many competing primary buttons.

## Motion

Motion should be small, legible, and respectful of Reduce Motion:

- Pet idle: subtle breathing.
- Drag hover: small anticipation movement.
- Processing: simple loop that conveys eating or work.
- Completion: small bounce or settle.
- Errors: gentle shake, tilt, or concerned pose, not aggressive vibration.

Motion should communicate state. It should not exist only for decoration.

## Copy Tone

ImagePet copy should be short, warm, and concrete.

Good:

- Ready for images
- Eating 4 images
- Saved 2.4 MB
- Output folder unavailable
- Retry Failed

Avoid:

- enterprise workflow language
- fake AI claims
- childish baby talk
- vague success messages with no file outcome

## Accessibility

- Preserve native keyboard navigation.
- Respect Reduce Motion.
- Keep text contrast aligned with macOS system colors.
- Do not rely on color alone for status.
- Provide clear labels for pet controls and state changes.
- Keep small pet states visually distinct by silhouette, not only by expression.

## Anti-Patterns

Do not use:

- busy dashboard layouts
- corporate SaaS cards everywhere
- fake AI glow or magical automation language
- childish toy UI
- decorative gradients as the main identity
- dense settings that obscure the core compression flow
- pet UI that owns destructive actions independently from the main app
- unclear overwrite behavior
- vague output-location messaging

## Implementation Notes

- Keep ImagePetCore free of UI and pet concerns.
- Keep the desktop pet state-driven and thin.
- Keep file access and overwrite confirmation explicit.
- Preserve native macOS controls unless a custom control directly improves the compression workflow.
- Treat this document as the design baseline for the `DesignSpike` redesign branch.
