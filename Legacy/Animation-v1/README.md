# Animation v1 (backup, 21 Sep 2026)

The motion system as it was before the v2 rebuild. Kept for reference only — this folder is
not part of any target, so nothing here compiles.

What v2 changed and why (see `Docs/CharacterSpec.md` › Motion for the current rules):

- **Lean was a rigid rotation about the feet.** A 34° "keel over" rotated the whole pet like a
  sprite. v2 leans by shearing the body over planted feet (`PetDraw.bodyTransform`), with only a
  small rotational share, and slumps come from `lying` / `headDrop` / `tilt` instead of rotation.
- **Bits were chosen per cycle but scheduled per bit.** `chosenBit` picked e.g. `tada` for a cycle
  while the filmstrip (and often the app) looked for `wiggle`'s window — cycles regularly played
  nothing. v2 schedules one slot per cycle (`PetAnimator.bitWindow`) and the chosen bit fills it.
- **`armRaise` always meant "wave one paw".** So stomps, cheers and umbrella-holding all read
  as waving. v2 adds `armSymmetric`, `armForward`, `armHold` and `armToFace` so arms can cheer,
  type, hold a book or wipe an eye.
- **Props were not held.** The umbrella's stick ran down the face; the laptop screen faced the
  viewer; the book floated in front of the belly. v2 anchors held props to the hand
  (`PetDraw.handPoint`) and draws the laptop with its lid toward the pet.
