# Pip character spec

Every pet is drawn procedurally from the same rules. A painter that breaks a rule is a bug.

## Canvas and stance
- 200 × 200 design units. The floor is `y = 168`. Feet touch the floor; nothing sits below `y = 176`.
- Front view, sitting. Weight on the haunches, front paws on the floor.
- The pet's centre line is `x = 100`. **Every paired part is drawn once for the right side and mirrored** through `PetDraw.mirrored`. Nothing is hand-placed twice.

## Proportions (units)
| | cat | dog | red panda | penguin | capybara |
|---|---|---|---|---|---|
| hip width | 104 | 106 | 108 | 96 | 118 |
| head width | 90 | 92 | 92 | 78 | 96 |
| head height | 76 | 78 | 76 | 70 | 66 |
| eye radius | 7.5 | 7.5 | 7.5 | 7 | 5.5 |

- Head sits *on* the torso with a 12–18 unit overlap; there is always a contact shadow where they meet.
- Eyes on the horizontal line at 48 % of head height. Eye spacing 0.42 × head width, centre to centre.
- Muzzle / beak group centred at 72 % of head height.

## Light
- One key light, top-left. Every form gets, in this order: base fill → soft core shadow (bottom-right, 10 %) → rim highlight (top-left, 8 %). All through `PetDraw.form`. Nothing is shaded any other way.
- Contact shadows: under the head on the torso, under the paws on the floor, under the tail where it crosses the body.

## Line
- No outlines. Ink strokes only for mouth, brows and closed eyes: width `2.2` at full size, scaled up at small sizes so they never drop under 1.5 px.
- Facial ink is `palette.ink` (near-black, species tinted), never pure black.

## Colour
- Three tones per part from one palette: `base`, `shade`, `light`. Belly / mask use `belly`. Accents (`nose`, `earInner`, `marking`) are the only saturated colours.
- The pet keeps its colours in dark mode. The *scene* changes, the pet does not.

## Silhouette test
- Filled solid black at 24 pt the species must be recognisable. Penguin: bowling pin + flippers + feet. Cat: triangular ears + curled tail. Dog: floppy ears. Red panda: round ears + ringed tail. Capybara: barrel + boxy head.

## Expression
- A mood changes the **pose** first (lean, crouch, head drop, head turn, arms/flippers, ears, tail) and the face second. If a mood is only legible by the face, it is not done.
- Read at three sizes before committing: 24 pt badge, 110 pt gallery cell, full screen.

## Motion
- Idle motion is composed of eased, scheduled gestures (breath, weight shift, glance, blink, hop, shiver, sigh) — never a raw sine. Hops have anticipation, a parabolic arc and a landing squash. The floor shadow always follows the body.
- One animation driver: `TimelineView` provides time; rig changes interpolate with `.smooth` (no overshoot).
