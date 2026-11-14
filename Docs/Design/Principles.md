# Pip design principles

Pip sits in the wellbeing category: a mood tracker disguised as company. That places it under
two sets of obligations at once — Apple's platform conventions and the care owed to someone who
opens the app on a bad day. These are the rules every screen is judged against.

## Structure: native bones, calm skin, pet as hero

- **The pet lives in a room.** One world (`PetRoom`: sky, horizon, floor) lit by the time of
  day and tinted by the current mood, shared by the Pet tab, Sit With Pet, onboarding, the pet
  cards and the widget backgrounds. The pet's feet sit on the horizon. No circles, bubbles or
  badges around the character.
- **Native navigation.** Large titles, glass toolbar buttons, a floating tab bar that minimises
  on scroll, sheets with detents. Liquid Glass is used for controls that float *over* content
  (Sit With Pet's controls, today's faces), never for content itself.
- **The one action lives in the tab bar.** "How are you feeling?" is the prominent tab on iOS 27
  (`TabRole.prominent`, the separated circle) and the tab bar's bottom accessory on iOS 26 — on
  every tab, never a floating button in the middle of the pet's room.
- **The room keeps time.** Sky, sun/moon and stars follow the clock (dawn, day, dusk, night) and
  take a little of a fresh mood as a tint; dark mode is the same sky after dark, never brown.
- **One accent per screen.** The app tint is the calm teal. Mood colour appears only as a
  mark — the primary action once a mood is fresh, mood tokens, tints behind faces, calendar
  dots — and never as a slab of colour or a full-screen wash.
- **One type family.** SF Rounded for content (heavy titles, regular body); navigation titles
  stay SF Pro. No serif.
- **Every screen has one job.** Pet: see and greet your pet, log a mood. History: look back
  without being graded. You: choices, support, your data.

## Visual refinement: a quiet illustrated room

The primary task is seeing a companion and acknowledging a feeling. The pet remains the largest
and most expressive object; surrounding UI gives it space. Use SF Rounded content styles, calm
teal for actions/selection, semantic primary/secondary text, and existing spacing tokens.

- **Scene materials are illustration.** Soft floorboards and directional daylight establish a
  plane beneath the pet; potted foliage stays at the edges on larger surfaces. Stars appear only
  at night. Soap bubbles have a thin iridescent rim, transparent film and a brief dispersing pop;
  they never merge with navigation buttons. No per-bubble Liquid Glass.
- **Glass belongs to chrome.** Floating navigation controls may use glass. Mood choices use a
  softly tinted rounded square, one expressive face and a label; no competing glyph badge, ring
  or glass layer. Onboarding content uses regular material for readability over the room.
- **History reads like a journal.** A shared week strip uses proximity, with a subtle selected
  background and short underline. Daily prose is readable secondary text, not another colored
  panel. Keep timestamps, context and notes visible in the grouped entry list.
- **Motion communicates continuity.** Use short eased changes, not decorative entrance cascades.
  Reduce Motion removes the room-camera spring, button compression and widget pose interpolation;
  expression, selection and instructions remain available. A new interaction blends the previous
  event clip out over 220 ms; interrupted clips never resume after the newer clip ends.
- **Each companion has its own balance.** Pebble opens its flippers and shifts weight; Mochi uses
  asymmetric paws, head turns and ears; Biscuit leans eagerly and settles with floppy ears. Mood
  intensity scales these differences. Held props keep their grip at every intensity.
- **Every widget is composed for its context.** Home widgets prioritize the pet with separate
  petting and open-app actions; medium layout allocates pet space proportionally to width.
  Background-free contexts favor a large still companion and its name over mood shortcuts.
  Accessories use optically enlarged faces and brief supported state transitions. Watch corner
  and circular faces keep their existing family behavior. Do not assume scheduled entry changes
  are a continuous animation or that WidgetKit refreshes at an exact instant.
- **Appearance follows the system and time.** Light/dark room palettes remain distinct from day/
  night lighting. Widget labels use semantic foregrounds; vibrant/accented faces keep the existing
  monochrome artwork. Verify actual StandBy night tint and Watch Always On on device.

PetLab `rooms` exports the actual shared stage across all three species at app/widget proportions.
`PetRenderTests.companionSurfaceSheetsRender` can export the real iOS widget layouts using
`TEST_RUNNER_PIP_SURFACE_OUTPUT=/tmp/pip-surfaces` (one appearance per invocation; select dark
with `TEST_RUNNER_PIP_SURFACE_SCHEME=dark`). Hosted feature captures use
`TEST_RUNNER_PIP_FEATURE_OUTPUT=/tmp/pip-feature` and
`TEST_RUNNER_PIP_FEATURE_SCREEN=home|picker|history|pets|onboarding|settings|play`, again one screen
per invocation. These renders verify composition; system
presentation, tactile quality, performance and continuous motion still require runtime checks.

## Character: professional, not kids-app

- One construction per species (`Docs/Pets/Bible.md`): flat colour with one form shadow, a rim in
  the coat's own darker tone, mirrored paired parts, emotion from the lids.
- **Mirror, then accompany.** The pet answers a log with a short reaction, then keeps you company
  in the mood: a blanket when you're sad, slow breaths when you're stressed, cocoa when you're calm.
  Verify at 24pt (badge), 60pt (face) and full screen.
- **Personality is behaviour.** Idle motion is layered and eased (breath, blinks, glances, sway)
  and each stance has a repertoire of short vignettes played one at a time and never back to back.
  Only the pet answers touch — a tap elsewhere in the room just draws its eyes. When you sit
  together it closes its eyes and breathes; with the guide on, its chest follows the guide.
- **The pet has its own day, but your mood comes first.** A fresh mood is always the mood. Once
  it has faded (8 hours) the pet gets on with its day (`PetDay`): asleep under a nightcap at night,
  a stretch at dawn, at a small laptop on weekday office hours, a book in the evening and at
  weekends. Props are drawn in the same canvas and follow the body. Widgets share the schedule.
- Reduce Motion stills everything and keeps the pose.

## Care: what a wellbeing app owes its user

- **No streaks, scores, averages or grades.** History describes ("Mostly calm this week, from
  sad on Saturday to excited today"); it never counts missed days.
- **Never a reminder to log.** Notifications are rare, optional, off by default, and always
  about the pet ("Pebble saved you a spot"), never about the user's compliance.
- **All feelings are equal.** Eight moods, same size, same weight, no "good" or "bad" grouping.
  Copy about the pet's reaction is descriptive, not judgemental.
- **Honest about what Pip is.** "A companion for noticing, not a substitute for care" appears
  at the end of onboarding and in Settings. The Support screen (Settings › Support and crisis
  resources) lists 988, Crisis Text Line and findahelpline.com and is two taps from anywhere.
- **Private by design, and portable.** No accounts, analytics or servers (enforced by
  `scripts/privacy-audit.sh` in CI). Apple Health sync is write-only and opt-in. Export My Data
  writes everything to JSON; Delete All App Data removes it from the device and private iCloud.
- **Apple Intelligence only on the device.** `PetWords` lets the on-device system model write the
  History sentences in the pet's voice from the real entries. Never Private Cloud Compute. The
  instructions forbid advice, judgement, numbers, streaks and clinical language; the output is
  sanitised again in code; every sentence is cached; the deterministic phrase is the fallback;
  Settings › Apple Intelligence turns it off.
- **Calm by default.** No autoplaying sound; ambient sound is opt-in and stops in the
  background. Motion is slow and eased; haptics are soft and can be turned off.

## Checking a change

Before showing a screen: screenshot the real simulator in light and dark, on iOS 26 and 27,
at the three pet sizes where relevant; run `xcodebuild test` (unit + UI); run the privacy
audit; and ask, of every element, which of the rules above it serves.
