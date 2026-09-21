# A little company

Pip is a quiet place to visit a companion and acknowledge a feeling. The character is the focal point; the interface frames it with warm paper tones, generous space and a serif headline.

## Character direction

All five companions retain their identities and signature accessories. Rounder heads, soft directional shading, glossy eyes and front paws give them more presence. Expressions still come from the animatable rig, so mood changes, idle movement, waves, widgets and Live Activities use the same artwork. The illustration is native vector artwork, not a set of static image swaps.

`Characters.png` is generated from the real renderer by `CharacterRenderTests`. It shows neutral, happy, sad, excited and stressed at moderate intensity. Resolver tests cover every mood, intensity and species. See `../CharacterSpec.md` for geometry and rendering rules.

## Surfaces and interactions

- Home: sanctuary alcove, one-tap check-in, companion selection, breathing and a ribbon of today's recorded moods.
- Sanctuary: shared vector hills, light and botanical silhouettes; colors respond to mood and system appearance.
- Breathing: optional four-second inhale and six-second exhale; Reduce Motion keeps the guide still while instructions change. Ambient sound stops in the background.
- Widgets: framed companions with readable names, mood controls and daily history.
- Live Activities: clear moment labels, accessible wave controls and deep links back to the relevant screen.
- Reliability: cancel stale reaction tasks, save notes when dismissing a check-in, route activity links to the pet tab, and use unique calendar weekday identifiers.

## Verification

Run the Pip scheme's unit and UI suites. For unsigned simulator builds, set `TEST_RUNNER_PIP_UITEST=1` so the app host starts with in-memory storage rather than an entitlement-dependent CloudKit store. Production CloudKit configuration is unchanged.

Optional render outputs: `TEST_RUNNER_PIP_ART_OUTPUT=/tmp/pip-characters.png` and `TEST_RUNNER_PIP_ICON_OUTPUT=/tmp/pip-icon.png`. The icon renderer also writes `/tmp/pip-icon-layer.png` for Icon Composer.

Review actual Lock Screen and Dynamic Island behavior on a physical device before release; the gallery verifies content layout but does not substitute for system presentation testing.
