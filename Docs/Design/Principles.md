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
  (the Pet tab's actions, Sit With Pet's controls), never for content itself.
- **One accent per screen.** The app tint is the calm teal. Mood colour appears only as a
  mark — the primary action once a mood is fresh, mood tokens, tints behind faces, calendar
  dots — and never as a slab of colour or a full-screen wash.
- **One type family.** SF Rounded for content (heavy titles, regular body); navigation titles
  stay SF Pro. No serif.
- **Every screen has one job.** Pet: see and greet your pet, log a mood. History: look back
  without being graded. You: choices, support, your data.

## Character: professional, not kids-app

- One construction per species (`Docs/CharacterSpec.md`): mirrored paired parts, one upper-left
  key light, one line weight, a single prop that carries the species.
- **Moods change the pose before the face.** A sad pet sinks and holds an umbrella; a tired one
  lies down and nods off. Verify at 24pt (badge), 40–120pt (face) and full screen.
- **Personality is behaviour.** Idle motion is scheduled and eased (breath, blink, weight
  shifts) and every mood has a signature *bit* — the wiggle, the zoomies, the flop, the stomp —
  performed every so often. When you sit together the pet meditates with you; with the guide
  on, its breathing follows yours.
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
- **Calm by default.** No autoplaying sound; ambient sound is opt-in and stops in the
  background. Motion is slow and eased; haptics are soft and can be turned off.

## Checking a change

Before showing a screen: screenshot the real simulator in light and dark, on iOS 26 and 27,
at the three pet sizes where relevant; run `xcodebuild test` (unit + UI); run the privacy
audit; and ask, of every element, which of the rules above it serves.
