# Pip character spec

Every pet is drawn procedurally from the same construction. The visual direction is a small,
sculptural companion: rounded cheeks, a soft upper-left light, glossy eyes, and tactile paws.
Feeling comes from pose first, expression second. One signature prop identifies each pet.

## Canvas and stance
- 200 × 200 design units. The floor is `y = 168`. Feet touch the floor; nothing sits below `y = 176`.
- Front view, sitting. Weight on the haunches, paws or feet at the bottom front.
- The centre line is `x = 100`. **Every paired part is drawn once for the right side and mirrored**
  (`PetDraw.mirrored` for drawing, `PetDraw.symmetric` for outline parts). Nothing is hand-placed twice.

## Construction (in drawing order)
1. **Silhouette** — `PetDraw.silhouette(p, extras:)`: torso ∪ tilted head ∪ outline parts (ears, snout),
   filled through `PetDraw.plush`. Head and body are one shape; there is no neck seam.
2. **Belly / front** — a lighter oval clipped to the silhouette (`palette.belly`).
3. **Limbs** — front arms (`PetDraw.arms`), paws (`PetDraw.paws`), feet or flippers as simple shapes in `shade`, `belly` or `nose`.
4. **Species marks** — ear insides, muzzle, mask, patch, stripes, tail rings. Keep markings simple and readable.
5. **Face** — eyes, brows, blush (only when the mood asks), nose/beak, mouth.
6. **Prop** — exactly one per pet (`PetProps`): Pebble scarf, Mochi bell collar, Biscuit bandana,
   Rusty leaf, Juniper yuzu. Neck props also hide the head/body join.
7. **Glyphs** — sweat drop on the head; scene accessories (`!`, `zzz`, sparkles, rain cloud, steam) around it.

## Proportions (units)
| | cat | dog | red panda | penguin | capybara |
|---|---|---|---|---|---|
| hip width | 100 | 102 | 104 | 108 | 120 |
| head width | 108 | 106 | 110 | 94 | 108 |
| head overlap | 33 | 32 | 34 | 38 | 26 |
| eye radius (× head width) | 0.072 | 0.072 | 0.072 | 0.075 | 0.052 |

- Eyes on the line at 48 % of head height, 0.38 × head width apart. Glossy ink ovals with a top-left key light and a smaller bounce light.
- Nose / beak / mouth group centred at 70 % of head height. Beaks and noses are tiny: ≤ 15 % of head width.

## Colour
- `PetDraw.plush` shades the silhouette from light → base → shade, with a soft head highlight.
- Keep face markings graphic; do not add bitmap textures or expensive per-frame blur.
- Per species: `base`, `shade` (for limbs/flippers that must separate from the body), `belly`, `marking`,
  `earInner`, `nose`, `ink`, `blush`. Pebble is charcoal, not navy.
- Pets keep their colours in dark mode; the scene adapts, the pet does not.

## Line
- No outlines. Ink strokes only for mouth, brows and closed eyes: `p.inkWidth` (2.0 at full size,
  3.2 at `.small` detail so a 24 pt badge still reads).

## Expression
- A mood changes **pose** first — `lean`, `headDrop`, `armRaise`, `armCross`, `armOut`, `lying`, `tilt`, ears,
  tail — and the face second. Blush only on happy / excited. If a mood is only legible by the face, it is not
  done; `PetReactionTests.signaturePosesAreDistinct` enforces a minimum body-pose distance between moods.
- Signature poses: happy = arms open (`armOut`), chest up; excited = arms up, tall; calm = a loaf, paws tucked
  (`armCross` 0.55), eyes soft; neutral = upright and alert; tired = slumped sideways (`lean`, `lying`), lids
  heavy; stressed = hugging itself (`armCross` 0.9), hunched, ears back; sad = small, head hung, holding the
  umbrella (`armRaise` 0.55); frustrated = arms folded, face turned away (`headTurn`), brows down.
- Every mood has a default head `tilt` of a few degrees so the pet never stands like a mugshot.
- Read at three sizes before committing: 24 pt badge, 52 pt mood card, full screen; light and dark.

## Motion
- In the app: scheduled, eased gestures (breath, weight shift, hop with anticipation, stretch in flight and a
  landing squash, shiver bursts, sigh, nod, blink, glance) — never a raw sine. Amplitudes are tuned for phone
  size: sway ±2°, breath 3%, a big hop squashes 16% on landing. One driver: `TimelineView` for time,
  `.smooth` on rig changes, no overshooting springs.
- Follow-through: the head lags the body's lean (`LiveMotion.headLag`, up to 8°) so nothing moves as one
  rigid piece.
- **Bits** (`PetBit`, `PetAnimator.performBit`): each mood performs a signature piece of business every
  `bitInterval` seconds — wiggle (happy), zoomies (excited), stretch-and-yawn (calm), curious tilt (neutral),
  nod-off / keel over 34° / jerk awake (tired), pace-and-fidget (stressed), leap-slam-shake-hmph (frustrated),
  sniffle-shake-wipe (sad), and a continuous float with paws together for meditation. Durations live on
  `PetBit.duration`. A freshly logged mood plays its bit back to back for a few seconds (`AppState.react`).
- Held props ride the body: the umbrella follows hop, lean and shiver through `AccessoryOverlay(live:)`.
- **Touch** (`PetInteraction.swift`): a tap gets a hello in character (`PetReaction.tap`); taps within 2.5 s
  escalate — giggle from the second, dizzy on the sixth, then reset. A finger held 0.45 s (or a stroke) is
  petting: eyes shut, leaning in, purring breath, hearts, a soft haptic every 0.7 s. While a finger is on the
  room the eyes and a little of the head follow it (`lookOverlay`). Everything layers on the mood, never
  replaces it.
- Where nothing can animate (widgets, Live Activities): `PetPose` variations (blink, glance, wave, hop) that
  the app pushes as state updates; the system animates the change.
- Review motion with `AnimationFilmstripTests` (`PIP_FILM_OUTPUT=<dir>`): one strip per bit for every species,
  the transitions between moods, the tap repertoire and the rest matrix. Bounds are enforced by
  `PetAnimatorTests` and `PetBitTests` (hop ≤ 22, lean ≤ 36°, squash 0.72–1.3, no NaNs).

## Room
- The pet lives in `PetRoom`: sky, horizon and floor blended between dawn/day/evening/night keyframes and
  tinted by a fresh mood; the feet sit on the horizon (`PetSceneView` derives it from the floor line).
- Scenes adapt to mood, time and appearance; pet colours stay consistent.
- Widgets use static artwork. Reduce Motion removes the character clock.
- Regenerate character contact sheets with `CharacterRenderTests` and `TEST_RUNNER_PIP_ART_OUTPUT`.
