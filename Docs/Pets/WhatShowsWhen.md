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
| 22:30 – 6:00 (weekends until 7:30) | Sleeping | Tucked under its blanket in a nightcap, eyes closed, `zzz` |
| 6:00 – 9:00 (weekends 7:30 – 10:30) | Waking up | Heavy lids, slightly slumped |
| Weekdays 9:30 – 11:30 and 14:30 – 16:30 | Working | Peeks over a little laptop (a paw print on the lid), types, looks up at you |
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

### Doing it, visibly

The activity is in its constant motion, not only in the occasional clip, so the status line is
always visibly true: **reading** eyes travel along a line and flick back to the next;
**working** paws type in bursts with pauses to read the screen; **playing** the ball rolls back
and forth and its eyes follow; **daydreaming** a little thought cloud with a heart floats up.

### What it has on (`PetDressing.choose`)

One thing on its head, one round its neck, one on the floor beside it, one small sign, on top
of at most one thing in its paws. Nothing celebratory after a hard mood.

| Where | What | When |
|---|---|---|
| Head | Nightcap | Always when asleep; otherwise from 21:30 until 6:00 |
| Head | Headphones | Another app is playing audio, or headphones/AirPods are connected (beats the nightcap while awake). A good mood nods to the beat; a hard one sways slowly |
| Head | Party hat | New Year's Eve evening and New Year's Day, and the anniversary of the day you met (not after a hard mood) |
| Neck | Travel pillow | No network at all (flight mode) |
| Neck | Scarf | Winter (by date and your region's hemisphere) |
| Floor | Suitcase | Your time zone changed in the last day |
| Floor | Cake with a candle | The anniversary of the day you met (not after a hard mood) |
| Floor | Jack-o'-lantern | Halloween, 25–31 Oct (US, CA, GB, IE) |
| Floor | A lit diya | Diwali: two days before the Kartika new moon to the day after (IN, NP, MU, FJ, SG, MY, LK, TT, GY, SR) |
| Floor | Red paper lantern | The first five days of Lunar New Year (CN, TW, HK, MO, SG, MY, VN, KR) |
| Floor | Small tree with a star | 18–26 Dec, where Christmas is widely kept |
| Sign | Battery filling, with a bolt | Charging |
| Sign | Battery nearly empty | Low Power Mode, or under 15% |

Festivals come from the date and the phone's region setting, never location; the suitcase and
the cake come first, and none show after a hard mood.

**Seasons** drift through the room on about three days in seven (the same days on every
device), so a season stays a small treat rather than months of the same leaves: snow in winter,
leaves in autumn, blossom in spring, fireflies on summer evenings. They fade out before reaching
the name and status; **confetti** on New Year and its birthday.

**Gentle hello:** if yesterday was rough (it ended on a hard feeling, or half of it was hard)
and nothing is logged yet today, arriving gets a soft lean toward you, a kind face and one small
heart instead of the wave and hop, and the bouncy vignettes (bounce, fist pump, dance, wiggle,
clap) sit out until you log something.

**Missed you:** opening Pip after three or more days away gets a double hop, arms up, a hug
and hearts. **At night**, opening the app while it sleeps gets a sleepy hello: it half wakes,
waves drowsily, yawns and settles back down.

Every signal is a yes/no the phone gives any app without asking: nothing is stored beyond your
last visit and last time zone (both on the device), and nothing leaves it. Only while the app is
open; widgets show the date-based things (seasons, New Year, birthday) but not the rest. Weather
would need your location, so there is none.

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

**The week:** on Monday mornings (6–12) a big stretch-and-yawn joins the repertoire; on Friday
evenings (17–23) a happy wiggle with sparkles. **Its favourite toy:** once one toy in Play has
been used at least five times and two more than any other, it joins too: the ball (it fetches
it and holds it out to you), bubbles (it blows one and watches it rise) or the treat (big
hopeful eyes and a little bounce). These only join good or neutral stances, while it is awake,
and the ball only when its paws are free.

## 5. What you can do to the pet

| You | The pet |
|---|---|
| Open the app / come back to the Pet tab | **Arrival:** looks up at you, ears lift, a wave with a small hop — or, in quieter stances (calm, tired, sad, reading, daydreaming, waking, winding down), a slower, lower wave. Asleep: just an ear twitch. At most once every 20 s |
| Tap it | Answered in keeping with what it's doing, and never the same way twice running (`PetPokes`). **Asleep:** one grumpy eye opens with a puff of steam; or it grumbles and rolls over; or mumbles in its sleep. **Sleepy:** nuzzles, yawns into a smile, rubs an eye. **Sad / stressed:** leans into your finger, reaches a paw up, a brave little smile, or a startle then one long breath out (never giggles). **Frustrated:** "hmph", turns away and peeks back softened; a grumbly stomp. **Calm:** slow blink with a heart; hums and sways. **Meditating:** opens one eye, smiles, closes it. **Working:** looks up from the laptop and waves; notices you with a "!". **Reading:** peeks over the book and winks. **Happy / playful:** boop (`> <` and a giggle), wink, a hop with paws up, "oh!" then a laugh, heart eyes; tapping its body tickles |
| Tap a sleeping pet 3 times quickly | **Woken up:** both eyes half open, paws folded, pout and steam, then it flops straight back to sleep |
| Tap it 5 times quickly (each within 1.6 s) | **Flustered:** covers its eyes with both paws, peeks out with one, blushes (not in a hard mood) |
| Hold a finger on it (0.4 s) or stroke it | **Petting:** eyes close happily, leans into you, blush, hearts; a soft haptic every 0.7 s. Asleep it smiles in its sleep and snuggles in without waking; in a hard mood it leans in quietly with fewer hearts |
| Let go after petting | **Afterglow:** content smile and a heart as it settles |
| Tap anywhere else in the room | Nothing but its eyes glancing toward the tap |
| Play music or a podcast in another app | Headphones go on within a few seconds while the Pet tab is open (a yes/no from iOS; no permission, nothing about *what* is playing) |
| Move a finger anywhere on the screen | Its eyes, and a little of its head, follow |
| Log a mood | The reaction (§2) plays, then it settles into the new stance |
| Write a note while logging | It leans in, ears up, and nods now and then — listening |
| Open the mood picker | The camera tilts: the pet rises above the sheet so you see its reaction |

## 6. Where it appears

| Surface | What shows | Moves how |
|---|---|---|
| Pet tab | The room (sky by time of day, tinted by a fresh mood), the live pet, its name and a status line that always matches the stance, today's faces once there's more than one | Live, 60 fps (30 when the system asks) |
| Mood picker | Eight tokens, each the pet's turned-up face for that mood | Still |
| Play (the tennis-ball button on the Pet tab) | The pet in its room with a tray: toss its **snack** (a little fish for Pebble, a fish biscuit for Mochi, a bone biscuit for Biscuit): it hops, catches it, holds it up in both paws and eats it in three bites with crumbs, then licks its lips, wiggles and a heart pops up, throw the **ball** (it hops over, carries it back in its paws, drops it, and it rolls back to the tray) or blow **bubbles** (five wobble up toward it; it watches the nearest and swats any within reach, and you can tap one to pop it). With music playing in another app it **dances** on the beat (after a hard mood it only sways). Tilt the phone and it leans and flails to keep its balance; shake it and it goes dizzy | Live |
| Meditate (the button next to close, in Play) | Sitting cross-legged, paws on its knees, floating a little; "Breathe together" drives the chest, a ring and the words (4 s in, 6 s out) | Live |
| History, Settings, tab-bar accessory | Mood token faces | Still |
| Goodnight card (Pet tab, from 21:30, once you've logged today) | "Goodnight from Pebble", one plain sentence about your day (on-device words, or "Today: calm, then happy. Sleep well."), and today's faces | Still |
| Home Screen widgets | Tap the pet to pet it: it leans into your hand with hearts for a few seconds, then settles. Small: the pet in its room. Medium: pet, status, four faces to log. Large: pet over all eight faces | A new entry every 30 min, at each change in the pet's day and when a mood fades; each entry shows the next still pose, and the system animates the change |
| Lock Screen (circular, rectangular, inline) | Badge face (nightcap at night), name, what it's doing | Same timeline as widgets, stepping through the stance's *complication moments* (below) |
| Live Activity (Lock Screen, Dynamic Island, watch Smart Stack) | Starts when you log (if "Keep me company" is on). The pet in its company stance in a slice of the room, one line in its voice, "Here since 9:41", a Pet button. No timers | Pet button: leans in with a heart for 3.2 s, then settles on another still pose. Two-thirds of the way through it dozes off ("Pebble dozed off beside you"). It stays 60 min after sad, stressed, tired or frustrated, 20 min otherwise; a new log replaces it |
| Watch app | Same live pet, stance and clock as the phone; tap to boop, long-press to pet | Live, 30 fps |
| Watch complications | Badge face; corner, circular, rectangular (with what it's doing), inline. A tap opens straight to "How are you?" | A new *complication moment* every 5 minutes: bold, mood-true faces designed for 30 pt (happy: a beam, a wink, a grin with sparkles, a tilt with a heart; sad: a tear, a brave little smile, a sigh; asleep: `zzz`, rolled over, one eye peeking). On tinted faces it switches to a monochrome palette so the silhouette and the expression survive the tint |
| App icon | Pebble, head and shoulders, content | — |

## 7. What stays in sync between phone and watch

- **The stance and everything idle:** computed from the same snapshot and the same clock, so
  both show the same pet doing the same thing at the same second.
- **A mood logged on either device** arrives in about 2 s; the other device plays the reaction
  (if it happened in the last 20 s) and changes stance.
- **Boops, tickles, the flurry, petting (longer than 0.6 s) and waves** are sent live while both
  apps are open, and dropped otherwise (a boop from an hour ago means nothing).
- **Arrival** is per device: each greets you when you open it.
