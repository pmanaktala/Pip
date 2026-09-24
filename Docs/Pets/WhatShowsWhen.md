# What the pet shows, and when

The reference for pets v3. Everything here is read from the code (`PipCore/Pet`); the rules
behind it are in [Bible.md](Bible.md).

## 1. Which stance the pet is in

At any moment the pet is in exactly one **stance**. The same rule runs on the phone, the watch,
widgets and complications (`PetSnapshot.stance(at:)`).

1. **A mood logged in the last 8 hours** decides first. **Mood gates everything:**
   - After a **hard** feeling (sad, stressed, tired, frustrated) the pet only keeps you company in
     that mood — never cheerful work or play.
   - After an **easy** one (happy, excited, calm, neutral) it is with you in the mood for the first
     90 seconds, then gets on with its day *in that mood*: at its laptop in work hours ("working,
     humming along", "typing at top speed", "working quietly beside you"), getting ready for bed
     late in the evening. Otherwise it stays in the mood's own stance.
   - Late at night (after 22:30), an hour after your last log, it dozes off beside you.
2. **Otherwise, the pet's own day** (`PetDay`, local time):

| Time | Activity | Shows |
|---|---|---|
| 22:30 – 6:00 | Sleeping | Tucked under its blanket in a nightcap, eyes closed, `zzz` |
| 6:00 – 9:00 | Waking up | Heavy lids, slightly slumped |
| Weekdays 9:00 – 12:00 and 13:30 – 17:30 | Working | Peeks over a little laptop (a paw print on the lid), types, looks up at you |
| Other daytime (9:00 – 18:30) | Daydreaming / Playing / Reading | 90-minute blocks, picked per day, never the same twice in a row. Daydreaming looks up and smiles; Playing has a ball on the floor; Reading holds a book |
| 14:00 – 15:00 | Napping (about half the days) | Sitting nap, `zzz` |
| 18:30 – 21:30 | Reading | Book in both paws |
| 21:30 – 22:30 | Winding down | Mug of cocoa, heavy lids |

3. **Sit With Pet** → Meditating (eyes closed, paws in lap), whatever the mood.

Stance changes blend over 0.7 s. The Pet tab re-checks the stance on the minute, so the pet
moves on when a mood fades or the day turns over.

## 2. The eight moods

Each mood has a **reaction** (played once, right after you log: "mirror") and a **stance** it
settles into ("accompany"). Intensity scales the stance: slight ×0.55, moderate ×1, strong ×1.4.

| Mood | Reaction on log | Stance (holds / wears) | Vignettes it does on its own | Status line |
|---|---|---|---|---|
| Happy | Dip, hop with arms up, eyes `^ ^`, hearts (1.6 s) | Smiling eyes, blush, arms a little open | hum ♪, dance, look at you, clap, wiggle, + species signature | Happy for you |
| Excited | Crouch, big jump, sparkles, second bounce (2 s) | On its toes (light idle bounce), arms out, mouth open | bounce, fist pump, wiggle, clap, dance, + signature | Buzzing with you |
| Calm | Long breath in, eyes close, slow out (3 s) | Mug held at the chest, soft lids | sip, look at you, sigh, stretch (+ slow blink for Mochi) | Sipping something warm with you |
| Neutral | Ears up, double nod (1.6 s) | Upright, attentive | look around, curious tilt, look at you, stretch, + both signatures | Right here |
| Tired | Big yawn, arms stretch, slump (2.6 s) | Blanket round the shoulders, heavy lids | yawn, nod off and jerk awake, rub eye, sigh | Tucked in with you |
| Stressed | Flinch, sweat, then one deep breath (3.2 s) | Hugging itself, worried brows, ears back; breathes slowly and visibly | deep breath, shake it off, fidget, look at you | Taking slow breaths with you |
| Sad | Head sinks, two sniffs, a tear, a small look up (3 s) | Blanket, head low, worried brows | look up with a small smile, pat the spot beside it, sigh | Sitting close |
| Frustrated | Stomp, cheeks puff, steam, "pff" (2 s) | Arms folded, brows down, face turned a little away | huff, stomp, deep breath, shake it off | Huffing along with you |

Species signatures: **Pebble** flaps and waddles, **Mochi** slow-blinks and grooms,
**Biscuit** wags and tilts its head.

Life activities have their own vignettes: sleeping and napping (snore, ear twitch, stir), waking
(stretch, yawn, rub eye, look around), daydreaming (daydream, sigh, look around, hum),
playing (bat the ball, wiggle, bounce), reading (turn a page, chuckle, look at you),
winding down (sip, yawn, look at you).

### What it wears

At most one thing on its head, on top of at most one thing in its paws (`PetWear.choose`):

| Wears | When |
|---|---|
| Nightcap | From 21:30 until 6:00, over whatever else it is doing (a sad pet at midnight has its blanket *and* its nightcap), and always when asleep |
| Headphones | While another app is playing audio (music, a podcast) and the Pet tab is open. A good mood nods to the beat with a note or two; a hard one sways slowly with half-closed eyes. Asleep it never wears them |

**Held props:** mug (calm, winding down), blanket (tired, sad, asleep), book (reading), ball
(playing), laptop (working). Each is explained by the stance and sits in its paws.

## 3. What runs all the time (idle)

| Layer | Behaviour |
|---|---|
| Breathing | Rate and depth per stance (from 0.1 breaths/s meditating to 0.42 excited); the rate drifts ±10% so it never ticks. Stressed breathes deliberately slow and deep |
| Blinks | One in every 4 s window at a random moment; about 1 in 5 is a double blink. The eye closes toward the lower lid. None while asleep or meditating |
| Glances | A new spot every 2.3 s, reached quickly and held; about a third of the time it looks straight at you |
| Sway | A slow lean and head drift; bigger for happy and excited |
| Ears | A flick in about a third of 5.3 s windows (cat, dog) |
| Tail | Slow swish; a wag for happy (fast for Biscuit) and excited |
| Follow-through | Ears and tail lag hops and head turns |

## 4. Vignettes: how often

One slot at a time, on the wall clock, spaced by the stance's energy: every **9 s** (excited,
playing), **11 s** (happy, neutral, frustrated), **13 s** (calm, stressed, sad, waking,
daydreaming, reading, winding down) or **16 s** (tired, sleeping, napping). About 1 slot in 5 stays quiet. Within a stance's repertoire the order is
shuffled and never repeats back to back. Nothing plays while a reaction, a boop or petting is
happening.

## 5. What you can do to the pet

| You | The pet |
|---|---|
| Open the app / come back to the Pet tab | **Arrival:** looks up at you, ears lift, a wave with a small hop — or, in quieter stances (calm, tired, sad, reading, daydreaming, waking, winding down), a slower, lower wave. Asleep: just an ear twitch. At most once every 20 s |
| Tap its head | **Boop:** eyes squeeze `> <`, head bobs back, then a giggle with blush |
| Tap its body | **Tickle:** wiggles and giggles |
| Tap it 5 times quickly (each within 1.6 s) | **Flustered:** covers its eyes with both paws, peeks out with one, blushes |
| Hold a finger on it (0.4 s) or stroke it | **Petting:** eyes close happily, leans into you, blush, hearts; a soft haptic every 0.7 s |
| Let go after petting | **Afterglow:** content smile and a heart as it settles |
| Tap anywhere else in the room | Nothing but its eyes glancing toward the tap |
| Play music or a podcast in another app | Headphones go on within a few seconds while the Pet tab is open (a yes/no from iOS; no permission, nothing about *what* is playing) |
| Move a finger anywhere on the screen | Its eyes, and a little of its head, follow |
| Log a mood | The reaction (§2) plays, then it settles into the new stance |
| Open the mood picker | The camera tilts: the pet rises above the sheet so you see its reaction |

## 6. Where it appears

| Surface | What shows | Moves how |
|---|---|---|
| Pet tab | The room (sky by time of day, tinted by a fresh mood), the live pet, its name and a status line that always matches the stance, today's faces once there's more than one | Live, 60 fps (30 when the system asks) |
| Mood picker | Eight tokens, each the pet's turned-up face for that mood | Still |
| Sit With Pet | Meditating in the calm room; "Breathe together" drives the chest, a ring and the words (4 s in, 6 s out) | Live |
| History, Settings, tab-bar accessory | Mood token faces | Still |
| Home Screen widgets | Small: the pet in its room. Medium: pet, status, four faces to log. Large: pet over all eight faces | A new entry every 30 min, at each change in the pet's day and when a mood fades; each entry shows the next still pose, and the system animates the change |
| Lock Screen (circular, rectangular, inline) | Badge face (nightcap at night), name, what it's doing | Same timeline as widgets |
| Live Activity (Lock Screen, Dynamic Island, watch Smart Stack) | Starts when you log (if "Keep me company" is on). The pet in its company stance in a slice of the room, one line in its voice, "Here since 9:41", a Pet button. No timers | Pet button: leans in with a heart for 3.2 s, then settles on another still pose. Two-thirds of the way through it dozes off ("Pebble dozed off beside you"). It stays 60 min after sad, stressed, tired or frustrated, 20 min otherwise; a new log replaces it |
| Watch app | Same live pet, stance and clock as the phone; tap to boop, long-press to pet | Live, 30 fps |
| Watch complications | Badge face; corner, circular, rectangular (with what it's doing), inline | Same timeline as widgets |
| App icon | Pebble, head and shoulders, content | — |

## 7. What stays in sync between phone and watch

- **The stance and everything idle:** computed from the same snapshot and the same clock, so
  both show the same pet doing the same thing at the same second.
- **A mood logged on either device** arrives in about 2 s; the other device plays the reaction
  (if it happened in the last 20 s) and changes stance.
- **Boops, tickles, the flurry, petting (longer than 0.6 s) and waves** are sent live while both
  apps are open, and dropped otherwise (a boop from an hour ago means nothing).
- **Arrival** is per device: each greets you when you open it.
