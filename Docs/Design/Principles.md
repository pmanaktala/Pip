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
