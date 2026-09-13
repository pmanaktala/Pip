# Pip character spec

Every pet is drawn procedurally from the same construction. A painter that breaks a rule is a bug.
The style is flat and graphic: one solid silhouette, small features, no shading. Feeling comes
from pose and glyphs, charm from one prop per pet.

## Canvas and stance
- 200 × 200 design units. The floor is `y = 168`. Feet touch the floor; nothing sits below `y = 176`.
- Front view, sitting. Weight on the haunches, paws or feet at the bottom front.
- The centre line is `x = 100`. **Every paired part is drawn once for the right side and mirrored**
  (`PetDraw.mirrored` for drawing, `PetDraw.symmetric` for outline parts). Nothing is hand-placed twice.

## Construction (in drawing order)
1. **Silhouette** — `PetDraw.silhouette(p, extras:)`: torso ∪ tilted head ∪ outline parts (ears, snout),
   filled flat with `palette.base`. Head and body are one shape; there is no neck seam.
2. **Belly / front** — a lighter oval clipped to the silhouette (`palette.belly`).
3. **Limbs** — paws (`PetDraw.paws`), feet or flippers as simple flat shapes in `shade`, `belly` or `nose`.
4. **Species marks** — ear insides, muzzle, mask, patch, stripes, tail rings. Flat fills only.
5. **Face** — eyes, brows, blush (only when the mood asks), nose/beak, mouth.
6. **Prop** — exactly one per pet (`PetProps`): Pebble scarf, Mochi bell collar, Biscuit bandana,
   Rusty leaf, Juniper yuzu. Neck props also hide the head/body join.
7. **Glyphs** — sweat drop on the head; scene accessories (`!`, `zzz`, sparkles, rain cloud, steam) around it.

## Proportions (units)
| | cat | dog | red panda | penguin | capybara |
|---|---|---|---|---|---|
| hip width | 100 | 102 | 104 | 100 | 112 |
| head width | 96 | 98 | 98 | 84 | 100 |
| head overlap | 30 | 30 | 30 | 34 | 24 |
| eye radius (× head width) | 0.055 | 0.055 | 0.055 | 0.06 | 0.045 |

- Eyes on the line at 48 % of head height, 0.38 × head width apart. Small ink ovals with one top-left highlight.
- Nose / beak / mouth group centred at 70 % of head height. Beaks and noses are tiny: ≤ 15 % of head width.

## Colour
- Flat. No gradients, no cel shade, no rim light. `PetDraw.form` is a flat fill on purpose.
- Per species: `base`, `shade` (for limbs/flippers that must separate from the body), `belly`, `marking`,
  `earInner`, `nose`, `ink`, `blush`. Pebble is charcoal, not navy.
- Pets keep their colours in dark mode; the scene adapts, the pet does not.

## Line
- No outlines. Ink strokes only for mouth, brows and closed eyes: `p.inkWidth` (2.0 at full size,
  3.2 at `.small` detail so a 24 pt badge still reads).

## Expression
- A mood changes **pose** first — `lean`, `headDrop`, `armRaise`, `lying`, `tilt`, ears, tail — and the
  face second. Blush only on happy / excited. If a mood is only legible by the face, it is not done.
- Every mood has a default head `tilt` of a few degrees so the pet never stands like a mugshot.
- Read at three sizes before committing: 24 pt badge, 52 pt mood card, full screen; light and dark.

## Motion
- In the app: scheduled, eased gestures (breath, weight shift, hop with anticipation/landing, shiver bursts,
  sigh, nod, blink, glance) — never a raw sine. The floor shadow follows the body. One driver: `TimelineView`
  for time, `.smooth` on rig changes, no overshooting springs.
- Where nothing can animate (widgets, Live Activities): `PetPose` variations (blink, glance, wave, hop) that
  the app pushes as state updates; the system animates the change.
