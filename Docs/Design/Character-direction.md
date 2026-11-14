# Character direction — reference study, 14 November 2026

Status: concept development. The user rejected both the incremental construction changes and the
bean/loaf/puppy silhouette study. Neither is an accepted final character direction. The requested
direction is plush-like, appealing and expressive; simply increasing body width is not sufficient.

## References inspected visually

- [Hamilton Júnior, Cute 3d Penguin](https://www.behance.net/gallery/137402361/Cute-3d-Penguin).
  The dimensional face, sculpted cheeks, tiny beak and eye depth carry its appeal. Transfer the
  deliberate face-to-body proportions and material definition. The sleepy lids and costume are
  specific to this image; Pip's awake default should be curious and engaged.
- [Bashful Kitten photography](https://www.trotters.co.uk/products/bashful-kitten).
  The head and muzzle remain identifiable over a lighter torso with articulated limbs. Softness
  comes from material and construction, not an oversized belly. Transfer the readable ears and
  muzzle, head/body separation and relaxed paws; do not copy the toy's design.
- [Maltese puppy illustration reference](https://maltesesa.co.za/potty-training-your-maltese-puppy/).
  Eye highlights, a small dark nose, layered cheek fluff, a modest body and an open playful mouth
  create an engaged expression. Transfer these relationships into an original Biscuit, preserving
  a clear silhouette and expression at miniature sizes.
- [Jellycat Little Pup](https://de.jellycat.com/little-pup/).
  Texture and a small body provide softness without inflating the torso. The side-view reference
  establishes material/volume; it is not sufficient evidence for front-facing facial design.

## Next concept criteria

Create a cohesive original cast with lighter bodies, intentional head/face proportions, lively
neutral expressions and distinct species anatomy. Explore dimensional concept artwork before
forcing it into the existing Canvas rig. The next artwork is a design study, not a production
sprite, animation system or a promise of identical 3D fidelity from the current vector renderer.

Check full-body appeal first, then face crops at 24/60 pt and eight emotional states. The default
must look awake and approachable. Tired/sad states remain valid expressions, rather than leaking
into every baseline face. No decorative costume or prop should compensate for weak anatomy.

## World rules remain independent of style

All objects need a support: a paw, body contact, or a surface. The carrying contact checkpoint
anchors mug/book to one supporting paw, preserves two-handed grips where required, and draws
food in the paws' coordinate space. The remaining reach/grasp/release/set-down lifecycle must be
authored explicitly. Disappearing/reappearing objects are not a substitute for it.

## Original dimensional concept

An original image-generation concept sheet was produced after the reference study. It explores
expressive eye depth, lighter animal bodies, modest muzzles/beak and sculpted plush fur for the
whole cast. It is preview artwork only, not an installed app asset. The earlier Canvas blob/loaf
studies were rejected and their uncommitted implementation was removed.

Production evaluation must choose an asset/rig pipeline that can retain the accepted appeal
across poses, expressions, props and miniature surfaces. A generated still does not establish
animation quality or parity with the current parametric Canvas renderer.

## Illustrated middle ground — complete articulated renderer

The user requested a middle ground between flat cartoons and realistic plush renders,
authorized implementation and a push with the original artwork preserved, then explicitly
required a complete animated style rather than a static-art preview with fallback.

Settings → Appearance → Illustrated pets selects the new renderer for the whole cast (on by
default). Turning it off restores the original artwork immediately. Both renderers retain all
pose channels, eight moods at all intensities, daily activities, expressive eyes and mouths,
head turns, ears, arms, tails, breathing, touch reactions, meditation, props and costumes.
There is no switch to the original artwork during a mood change or interaction.

The new cast uses larger readable eyes, soft cheek shapes, balanced torsos, grounded forepaws,
matte shading and species-specific ears/tails. The generated PNGs below are design references;
the shipped characters are articulated Canvas drawings in `IllustratedPetArt.swift`, not
smiling PNGs. `PetPaint.style` dispatches to the selected cast while retaining shared world
transforms, contact constraints, floor-prop placement, costume anchors and effect channels.
Held-prop keyframes retain the original paw coordinates; resting forelegs have their own arc.

The selection is stored in the App Group, updates widgets, and travels from the phone to the
watch through the existing application context. Home/Lock Screen/StandBy widgets, Live
Activities and watch complications use the same illustrated renderer and its monochrome mode.
Reduce Motion and reduced-resource timing continue using the existing live-view policy.
Pip/Pebble has a fuller pear-shaped body to balance the expressive head. Sleeping and napping
recline onto the floor with striped pajamas, cuffs, a supporting pillow and the signature
nightcap. A continuous `recline` pose channel interpolates the body, feet, arms and head into
the floor pose; breath expands the chest without lifting the sleeping pet. Face crops remain
centered on the closed-eye face. The original style retains its original sleeping artwork.

No original asset or renderer source was removed. The earlier generated studies are retained
as references/test resources. A physical-device review of widget tint and watch presentation
is still required; simulator captures establish renderer/layout evidence, not device parity.

The broader world-lifecycle issue (#89: reach/grasp/release/set-down) remains open. This
artwork increment preserves the existing contact constraints and does not claim to finish that
independent audit finding. #88 remains the acceptance tracker for the cast's acting quality.

### Asset provenance and prompt

Built-in image-generation tool, style-transfer edits of the previous original concept PNGs.
No existing artwork was overwritten. Three prompts used the following exact template, replacing
`{species}` with penguin, cat and dog:

> Use case: style-transfer. Edit target: the supplied {species} pet PNG. Create a noticeably simpler illustrated 2.5D mobile-app companion, midway between flat vector illustration and a dimensional cartoon, NOT a realistic plush toy. Preserve this character's identity, palette, friendly expression, pose, overall silhouette, scale and placement exactly. Keep full body, centered on same square transparent canvas, feet at 86% canvas height. Replace photographic fur and complex 3D material with clean matte color shapes and only 2 or 3 broad soft shading regions. Simplify eyes into dark warm oval shapes with a single small highlight, remove realistic irises and eye socket rendering. Keep delightful facial proportions and small anatomical details, but drawn/illustrated rather than airbrushed CGI. No shiny nose, no rim lights, no tiny hairs, no plastic reflections, no painted ground shadow, no text, no props. Maintain transparency. The result must visibly read as a premium animated-app character illustration, not a studio render.

Saved design references: `Docs/Design/ArtworkStudies/Illustrated-v1/IllustratedPet-{penguin,cat,dog}.imageset/illustrated-v1.png`. These are not release resources.
Earlier dimensional studies: `PipTests/PreviewArtwork/PetConcept-{penguin,cat,dog}.png`.

## Verification for this checkpoint

- 65 unit/render tests pass, including held-prop grip compatibility for both styles,
  all mood intensities and activities, and continuous sleep/wake interpolation.
- All five UI flow tests pass: mood logging, refinement, history/support, accessible pet
  description and breathing start/stop.
- Release build passes for iOS/watchOS apps and widget extensions; privacy audit and
  whitespace checks pass.
- Actual app screenshots were inspected for every pet, the original-style switch, nighttime
  pajamas and the fuller penguin body. Multi-size character and shared widget-view sheets
  and live simulator galleries were reviewed. Only the dedicated Pip Visual Redesign
  simulator was operated; no other simulator was changed.
- Actual system widget/watch presentation and end-to-end paired-device appearance delivery
  still require device verification. One unsigned test-host screenshot launch hit a CloudKit
  setup trap before connecting; direct in-memory app captures and the repeated unit suite
  succeeded. The renderer was not in that crash's stack.
