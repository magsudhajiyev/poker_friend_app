# Seedance 2.0 Prompts — "Player using Final Table at a live game"

*Created 2026-08-02. Key constraint: AI video garbles UI text — keep the phone screen angled/stylized ("dark UI, teal-green glow, no readable text"). For a legible screen, generate with a plain dark phone screen and corner-pin the real app screenshot in post.*

## Primary (8–10s, over-the-shoulder push-in)

Cinematic realistic footage of a poker home game at night. A man in his early 30s sits at a green felt poker table, warm overhead lamp, chips stacked in front of him, two face-down cards under his fingertips. He lifts the corner of his hole cards, glances at them, then picks up his smartphone showing a sleek dark poker-tracking app with glowing teal-green accents and a circular table diagram. With quick confident thumb taps he logs the action on the phone, sets it down beside his chips, then smoothly pushes a stack of chips forward into the pot. Other players' hands and chips are visible around the table, slightly out of focus. Handheld camera, slow push-in from across the table to an over-the-shoulder angle, shallow depth of field, moody low-key lighting with soft green felt bounce, photorealistic, 4K, subtle film grain. The phone screen stays at a slight angle, glowing dark UI with green highlights, no readable text.

## Alternative (check-tap + chip riffle gestures, orbiting camera)

Close-up cinematic shot at a casino poker table. A focused player taps the felt twice with two fingers to check, then riffles a stack of chips with one hand while his other hand gives a single quick tap on his phone lying flat next to his cards — the screen shows a dark poker app with a glowing circular table diagram and green action buttons, mirroring the live hand. As an opponent across the table pushes chips in, the player calmly taps the phone once more, logging the action without taking his eyes off the table. Warm tungsten key light from above, neon ambience in the background bokeh, over-the-shoulder handheld camera slowly orbiting left, shallow depth of field, photorealistic skin texture, film grain. Phone screen visible only at an angle, stylized dark interface, no legible text.

## Usage

- Aspect via param (9:16 social / 16:9 YouTube), not in the prompt text
- Higgsfield CLI: `higgsfield generate create seedance_2_0 --prompt "..." --aspect_ratio 9:16 --wait`
- Free testing: same prompt on klingai.com (66 credits/day) before spending Higgsfield credits
- If screen garbles: add "phone screen turned slightly away from camera", or composite the real screenshot in post
