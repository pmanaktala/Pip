# Pip pets — the bible (v3)

Pip is a mood tracker that looks like company. You say how you feel; your pet sees it,
answers it, and stays with you in it. Everything the pet does serves that idea:
**it notices you, it answers you, it keeps you company.** It is never a chore (no hunger, no
guilt, no streaks), and it never performs at random.

v3 replaces every earlier pet (v1 blobs, v2 glossy "plush" rig). None of that code is used; the
v2 renderer lives in `Legacy/Pets-v2/` for reference only.

## 1. What we studied, and what we took

| Reference | What it does well | Rule we took |
|---|---|---|
| **Apple Watch Snoopy face** | 148 short, contextual clips (time, weather, activity) picked by a "decision engine" that avoids repeats; mostly still, plays when you raise your wrist. | **Vignettes, not loops.** Short clips chosen from context on a schedule, never back-to-back repeats. The pet *notices you arrive*. Between clips it is calm. |
| **Duolingo (Rive state machines)** | Separate state layers for body, head and mouth combine into 64+ idle variations; random blinks; clear success/failure reactions. | **Layered, additive animation.** Breath, blink, gaze, ears and tail are independent tracks on top of a pose; reactions are clips with an enter and exit. |
| **Finch** | The pet reacts to *your* actions; idle preening and looking around; soft, simple birb with a tiny beak and dot eyes. | **The log is the event.** The pet's biggest moment is reacting to the mood you tell it. Simple flat shapes, small features. |
| **Neko Atsume** | Life happens while you are away; you come back to see what they are up to. | **The pet has a day.** With no fresh mood it sleeps, wakes, reads, plays; widgets and the watch show the same thing. |
| **Pixel Pals** | One pet everywhere (Dynamic Island, Lock Screen, widgets); tiny art designed for tiny sizes. | **One pet, every surface, one clock.** A badge-size drawing designed for 20–30 pt, not a shrunken full-size one. |
| **How We Feel (Yale)** | Moods on pleasantness × energy; colour as a quiet mark. | Poses map to valence (up/down, open/closed) and energy (tension, tempo). Colour stays a mark. |
| **Pusheen / Sumikko Gurashi / Molang** | Minimal faces placed low on big heads; appeal from proportion and restraint. | Small dark eyes set wide and low, small mouth, no sparkle-eyes, no gradients. |
| **Disney's 12 principles** | Anticipation, follow-through, overlapping action, slow in/out, arcs, secondary action, appeal. | Every reaction has anticipation → action → follow-through. Ears and tail lag the head. Easing everywhere. |

## 2. The cast

Three companions, each a distinct silhouette at 24 pt. Fewer, finished.

| | Pebble — penguin (default, icon) | Mochi — cat | Biscuit — dog |
|---|---|---|---|
| Silhouette | Egg body, no ears, flippers, orange feet | Triangle ears, long curling tail | Soft scalloped outline, top-knot, long curly ears, fluffy plume tail |
| Palette | Charcoal, cream face and belly, apricot beak and feet | Warm ginger, cream muzzle and chest, soft stripes | Fluffy warm white (a Maltese-poodle sort), curly ears a shade deeper, rosy nose |
| Nature | Earnest and a bit clumsy. Flaps when happy. | Independent, secretly devoted. Slow-blinks at you. | Wholehearted. Whole back end wags. |
| Signatures | Flipper flap, waddle, belly-slide shuffle | Slow blink, paw groom, tail curl | Tail wag, head tilt, ear flop |

Old `capybara` and `redPanda` choices migrate to Pebble.

## 3. Drawing rules

- **Flat and graphic.** Each material is a base colour plus one form shadow (the same shape,
  offset down-right and clipped) and at most one small highlight. No gradients on the pet, no
  glossy eyes, no blur. One key light, from the upper left.
- **Soft rim.** Silhouettes carry a thin outline in a darker tone of their own colour (never
  black) so the pet reads on any sky, in light and dark.
- **Construction.** Head over body, joined by an overlap (the head can tilt, turn and nod
  independently). Arms are short capsules from the shoulder; feet are ovals on the floor; the tail
  comes from behind. Paired parts are written once and mirrored.
- **Face.** Eyes are dark vertical ovals with one small catchlight, set wide and a little below
  the middle of the head. Emotion comes from **lids**, not stickers: the upper lid drops and
  tilts (sleepy, sad, cross) along an arc; smiling eyes bend into a crescent. Closed eyes are strokes: `‿`
  asleep, `^` delighted. Brows only where a mood needs them. Mouths are small.
- **Canvas.** 200 × 200 units, floor at `y = 170`, centre line `x = 100`. Feet touch the floor.
- **Three detail levels.** `full` (≥ 90 pt), `face` (40–90 pt: head and shoulders, no props),
  `badge` (≤ 40 pt: head only, simplified features, thicker marks). Designed separately and
  checked at 24, 60 and 300 pt.

## 4. How the pet feels: mirror, then accompany

A mood is not a costume the pet wears for eight hours. When you log, the pet **mirrors** you for
a beat (so you feel seen), then settles into **keeping you company** in that mood.

| Mood | Mirror (the reaction to the log) | Company (the stance it settles into) | Vignettes |
|---|---|---|---|
| Happy | Bounces up, eyes smile, arms open | Sways and hums (♪) | little dance, clap, smiles at you |
| Excited | Crouch → big jump, both arms up | On its toes, bright-eyed | bounces, spin, fist pump |
| Calm | Long exhale, eyes soften | Settled loaf with a warm mug | slow blink at you, sip, stretch |
| Neutral | Ears up, a nod | Upright, attentive | looks around, curious tilt, ear scratch |
| Tired | Big yawn, slumps | Wrapped in a blanket, heavy lids | yawn, nod off and jerk awake, rub eye |
| Stressed | Flinch, ears back | Breathes slowly and visibly — an invitation to breathe along | deep breath, shake it off, fidgety paws |
| Sad | Head sinks, a sniff | Sits close with a blanket, soft eyes | looks up at you with a small smile, pats the spot beside it, sigh |
| Frustrated | Stomp, puff of steam | Arms folded, cheeks puffed | huff, stomp, lets it go with a shake |

Intensity changes amplitude and tempo, never the story. A mood stays fresh for 8 hours.

**Mood gates activity.** After a hard feeling the pet only keeps you company; after an easy one it
can get on with its day in that mood (working at a laptop in work hours, getting ready for bed).
**Context** comes only from on-device signals with no permission: the clock, and whether other
audio is playing (headphones). No location, no accounts. Full table: [WhatShowsWhen.md](WhatShowsWhen.md).

**The pet's day** (no fresh mood): asleep 22:30–6:00 (curled, `zzz`), waking until 9 (stretch,
yawn, rub eyes), then daydreaming, playing, reading or napping by the hour, reading in the
evening, winding down from 21:30 (yawns, blanket). The same function drives every surface.

## 5. Motion system

- **Pose** (`PetPose`): every drawable degree of freedom as a number — root position and
  squash, lean, head tilt / turn / nod, both lids, gaze, brows, mouth, ears, arms, tail, blush,
  and effect glyphs. Animatable, so static surfaces can cross-fade poses as motion.
- **Stance** (`PetStance`): the resting pose, face, prop and repertoire for a mood or activity.
- **Clips** (`PetClip`): keyframed, eased, **additive** curves over the stance, with fade-in and
  fade-out weights. Vignettes and reactions are clips.
- **Idle layers**: breath (rate drifts slightly), blinks (irregular, sometimes double), saccades
  (small gaze jumps that hold), ear twitches, tail motion, weight shifts. Deterministic noise
  from wall-clock time.
- **Secondary motion**: ears, tail and cheeks follow the head and body with lag and a little
  overshoot, computed by sampling the primary motion slightly in the past (deterministic, no
  simulation state).
- **Director** (`PetDirector`): stance + idle layers + one vignette slot at a time (8–16 s apart,
  seeded by wall-clock slot, no immediate repeats) + event clips (arrival, log reaction, boop,
  petting) that pause vignettes while they play + attention (look at a finger, look at you).
  Stance changes blend over 0.6 s.
- **Pure function of time.** Given the same pet, mood and clock, the phone, the watch and the
  widgets compute the same pose. That is how the pet stays in sync across devices.

## 6. Interaction

- **Arrival**: when the Pet tab or the watch app comes to the front, the pet notices you (looks
  up, ears lift, a small wave or hop depending on mood). A sleeping pet stays asleep; an ear
  twitches.
- **Tap on the pet** = a boop: eyes squeeze, head bobs back, then a smile. Taps on the body
  tickle. Rapid taps get a flustered "okay, okay". **Taps elsewhere in the room do not animate
  the pet**; its eyes glance toward the tap, nothing more.
- **Hold or stroke on the pet** = petting: leans into your finger, eyes close, purr haptics,
  a heart drifts up.
- **Logging a mood**: while the picker is open the pet watches it and previews the choice; the
  log plays the mirror reaction, then settles into company.
- **Across devices**: a log or petting on one device is sent as a pet event; the other device
  plays the same reaction if it is on screen.

## 7. Surfaces

| Surface | What it shows |
|---|---|
| Pet tab | The room, the live pet, name, one status line that always matches what the pet is doing. |
| Mood picker | The pet above the sheet previews each mood; tokens use the badge face. |
| Sit with pet | Meditating stance; chest follows the breathing guide. |
| Widgets | A *hold pose* (a pose that looks right frozen: never mid-jump) for the entry's time, in the room. Timeline entries every 30 minutes cycle between the stance's hold poses; the system animates each change. |
| Lock Screen / watch complications | Badge art, designed for 20–30 pt, with the mood as a glyph. |
| Live Activity | **Keeping you company**, not a timer: starts when you log, shows the pet in its company stance in a slice of the room with one line in its voice and a *Pet* button. Petting from the Lock Screen updates the pet (eyes shut, heart) and settles back. It ends by itself after an hour (20 min for light moods) or on the next log. No countdowns anywhere. Also appears in the watch Smart Stack. |
| Watch app | The same live pet from the same director and clock; logging, arrival and petting as on the phone. |
| App icon | Pebble, head and shoulders, content, from the same renderer. |

## 8. Checks before shipping any pet change

1. Contact sheet at 300, 60 and 24 pt, light and dark, every stance, every species.
2. Filmstrips of every clip (arrival, eight reactions, vignettes, boop, petting).
3. The real simulator (iOS 27 phone, paired watch): Pet tab, picker, widgets, Live Activity.
4. Tests: poses stay in range, clips are finite and end at rest, the director is deterministic,
   no immediate vignette repeats, the phone and the watch compute identical poses for identical input.
