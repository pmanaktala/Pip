# The room

Pip is a quiet place to visit a companion and acknowledge a feeling. The character is the focal point; it lives in a room (`PetRoom`) lit by the time of day, and the interface floats over that room as native glass. The rules are in [Principles.md](Principles.md).

## Character direction

Three companions — Pebble, Mochi and Biscuit — drawn flat with one form shadow, a soft rim and lid-driven expressions. Expressions still come from the animatable rig, so mood changes, idle movement, waves, widgets and Live Activities use the same artwork. The illustration is native vector artwork, not a set of static image swaps.

`Characters.png` is rendered by PetLab (`tools/PetLab`, command `cast`) from the real renderer: every companion in every mood stance, with the badge faces used by tokens. `PetRenderTests` renders the same sheet on the simulator. The rules are in `../Pets/Bible.md`.

## Surfaces and interactions

- Pet tab: the room full-bleed, the name over the sky, glass toolbar buttons (Sit, Pets), one prominent capsule to log or update a mood, and today's moments in glass on the floor. Tap anywhere in the room to say hello.
- Room: sky, horizon and floor blended between dawn, day, evening and night keyframes, tinted by a fresh mood; foliage silhouettes at the edges on large surfaces only.
- Mood picker: eight round tokens (colour, glyph, word) at a 400pt detent; the pet rises above the sheet and reacts to the tap.
- Sit With Pet: the pet meditates (floats, eyes closed). Optional guide: four-second inhale, six-second exhale; the pet's chest, the ring and the words follow the same curve. Reduce Motion keeps the guide still while instructions change. Ambient sound stops in the background.
- Personality bits: every mood performs a signature gesture every so often (`PetBit`); the sad pet holds an umbrella under its cloud.
- Widgets: framed companions with readable names, mood controls and daily history.
- Live Activities: clear moment labels, accessible wave controls and deep links back to the relevant screen.
- Reliability: cancel stale reaction tasks, save notes when dismissing a check-in, route activity links to the pet tab, and use unique calendar weekday identifiers.

## Verification

Run the Pip scheme's unit and UI suites. For unsigned simulator builds, set `TEST_RUNNER_PIP_UITEST=1` so the app host starts with in-memory storage rather than an entitlement-dependent CloudKit store. Production CloudKit configuration is unchanged.

Optional render outputs: `TEST_RUNNER_PIP_ART_OUTPUT=/tmp/pip-characters.png` and `TEST_RUNNER_PIP_ICON_OUTPUT=/tmp/pip-icon.png`. The icon renderer also writes `/tmp/pip-icon-layer.png` for Icon Composer.

Review actual Lock Screen and Dynamic Island behavior on a physical device before release; the gallery verifies content layout but does not substitute for system presentation testing.
