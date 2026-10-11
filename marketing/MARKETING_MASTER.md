# FINAL TABLE — Marketing Master Document

*Single source of truth for generating marketing content. Feed this ENTIRE
file to the marketing agent with every request. Last updated: 2026-09-01.
Maintainers: update this file whenever a feature ships or changes; claims
here must always match the live app.*

---

## HOW TO USE THIS DOCUMENT (instructions to the marketing agent)

1. **The GUARDRAILS section is absolute.** Never produce content that
   violates it, regardless of what the request asks for.
2. **VERIFIED FACTS blocks are immutable.** Quote them verbatim or omit
   them. Never round, extrapolate, combine, or "improve" a number. If a
   fact you want isn't listed, do not invent it — write around it.
3. **Everything else (descriptions, angles, hooks) is raw material** — you
   may rephrase, shorten, and adapt it freely to the platform and format
   requested.
4. When asked for content about a specific feature, read that feature's
   section fully, plus GUARDRAILS, plus the AUDIENCES section.
5. Default call to action: download on Google Play. Default link target:
   finaltable.io.

---

## PRODUCT OVERVIEW

**Final Table** is a mobile poker tracking app for live (in-person) poker.
Its one-liner:

> **Final Table tracks every hand you play — not just your profit at the
> end of the night.**

Online poker players have had trackers for decades (HUDs, databases,
solvers). Live players have had... a notes app and a spreadsheet. Final
Table gives live players what online players take for granted: real
statistics calculated from their actual play, hand history, opponent
notes, bankroll tracking, and study tools — all from a phone at the table.

The 30-second pitch: Most poker apps tell you how much you won. Final
Table tells you *why*. Log actions street by street and watch your real
stats build from your actual play. After enough hands, the app tells you
what kind of player you are. Then it helps you fix it: AI hand review in
your language at your level, GTO training drills, and your personal range
grid.

**Platform status: Google Play (Android) only. iOS is NOT available.**

**Website:** finaltable.io

---

## GUARDRAILS (absolute — read before every generation)

### Banned claims — never say any of these
- ❌ **Free trials or introductory offers.** None are configured. Any
  "try Pro free" / "free trial" phrasing is banned (store-policy risk).
  The launch promo (free Pro month for new sign-ups) may ONLY be
  mentioned if the request explicitly says the promo is currently active.
- ❌ **Opponent statistics tracking.** Public copy may only claim opponent
  *profiles, notes, and playing-style tags*. Never "track your opponents'
  VPIP/stats/numbers" in any public post.
- ❌ **iOS / iPhone / App Store availability.** Android / Google Play
  only. Never say "coming soon to iOS" unless the request explicitly
  authorizes it.
- ❌ **Winning promises.** Never promise profit, win-rate improvement
  percentages, or "beat the game" outcomes. The app measures and teaches;
  it does not guarantee results.
- ❌ **Gambling framing.** Final Table is a tracking and study tool. It is
  not gambling, does not host games, takes no bets, moves no money. Avoid
  imagery/copy that reads as a gambling service.
- ❌ **Real-time assistance implication.** Never suggest the app helps you
  cheat at online poker or provides in-game solver advice for online play.

### Terminology rules
- Poker terms stay in **English in every language**: VPIP, PFR, 3-bet,
  c-bet, steal, check-raise, fold-to-3-bet, all-in, preflop, flop, turn,
  river, showdown, buy-in, rebuy, add-on, ITM, ROI, cash game, MTT,
  range, bankroll, TAG, LAG, Nit, Calling Station, Maniac.
- Tier names — **Free, Pro, Elite, Club** — are product names. Never
  translate them.
- The app name is **Final Table** — two words, both capitalized, never
  "FinalTable" in prose (the domain finaltable.io is the exception).

### Required disclosures
- Any post mentioning subscription prices must be consistent with the
  PRICING section below and, where the format allows, note that
  subscriptions auto-renew and can be canceled anytime.

### Voice
- Confident, specific, player-to-player. Poker players smell marketing
  fluff instantly — lead with the concrete thing the feature does.
- Numbers beat adjectives: "7 stats by position" > "powerful analytics".
- It's fine to be playful with poker culture (bad-beat humor, TAG vs
  Calling Station identity jokes). Never punch down at losing players —
  the product's promise is that everyone can study and improve.

---

## AUDIENCES (three personas — target posts at ONE of them)

1. **The serious rec player.** Plays live cash weekly (casino or home
   game). Watches training content, knows what VPIP is, has never seen
   their own. Suspects they're better than their results. HOOK: identity
   and self-knowledge — "What kind of player are you, really?"
2. **The tournament grinder.** Plays local MTTs and series, tracks
   results in a spreadsheet today. Wants ROI, ITM%, hourly rate without
   the manual work. HOOK: automation and pro-level bookkeeping — "Your
   spreadsheet, retired."
3. **The home-game host / club owner.** Runs a regular game or a small
   club. Cares about smooth nights, fair seating, live standings, and
   the wow factor for guests. HOOK: "One subscription runs the whole
   club — everyone else plays free."

Hero features per persona:
- Serious rec → Play-style detection, 7 stats, range grid, AI review
- Grinder → Tournament analytics, session summary card, bankroll
- Host/owner → Clubs & events, dealer voice logging, live rankings/TV

---

## PRICING (quote exactly; never invent discounts)

| Tier | Monthly | Annual | What you get |
|------|---------|--------|--------------|
| **Free** | $0 | $0 | 10 hands/session, 5 opponents, 30-day history |
| **Pro** | $19.99 | $159.99 | 50 hands/session, 30 opponents, 90-day history, monthly AI analyses + exports |
| **Elite** | $24.99 | $189.99 | Unlimited hands, opponents, history; full AI access |
| **Club** | $59.99 | $449.99 | Everything in Elite + create and run your own poker club |

- Subscriptions auto-renew; cancel anytime in account settings.
- The Club model is a deliberate differentiator: **the owner pays, every
  member, dealer, and player in the club uses the app free** — no
  subscription required for them.

---

# FEATURES

Each feature below: what it is, the pain it solves, who it's for,
immutable facts, post angles, and what to show visually.

---

## 1. Full Hand Logging

**What it is.** Log a complete poker hand as it happens: every action by
every player, on every street. Tap through preflop raises, flop c-bets,
river shoves. Record board cards, your hole cards, and showdowns. The
app handles the hard poker math automatically — side pots when someone's
all-in for less, chopped pots with multiple winners, dead-button seating
scenarios. Made a mistake? Undo restores the exact previous state.

**Pain → payoff.** Live players lose the hand the moment the pot ships —
memory is unreliable and biased. Full logging turns a night of poker into
a permanent, reviewable dataset: every decision, every bet size, every
showdown, forever.

**Personas:** serious rec (primary), grinder.

**VERIFIED FACTS**
- Logs every action for every player across all four streets
- Supports fold, check, call, bet, raise, all-in
- Automatic side pots, chopped pots (multiple winners), and dead-button
  handling
- Undo with full state restoration
- Board cards, hero hole cards, and showdown cards recorded
- Tables up to 9 seats, empty seats handled correctly
- Works for cash games and tournaments, including blind level changes
  mid-tournament and BB ante formats
- Decimal blinds supported (e.g. $0.25/$0.50 home games)

**Post angles**
- "You remember the bad beat. Do you remember the three streets of
  decisions that led to it?"
- The permanence angle: your poker history as an asset you build every
  session.
- Speed demo: logging a full hand takes seconds per action — show it.

**Visuals:** screen recording of logging one hand start to finish; the
chip animation when the pot ships is the money shot.

---

## 2. Quick Session Logging

**What it is.** Don't want to log every hand? Start a quick session, enter
buy-in and cash-out, done. Works for cash and tournaments, with rebuys and
add-ons. All the financial stats (profit, hourly, ROI) still build — you
just skip the hand-level detail.

**Pain → payoff.** Zero-effort bookkeeping for nights when full logging is
too much. The spreadsheet, replaced by four taps.

**Personas:** grinder (primary), serious rec.

**VERIFIED FACTS**
- Records buy-in, cash-out, session length, game type
- Cash: direct add-on tracking. Tournaments: rebuys and add-ons
- Feeds all financial statistics (net profit, hourly rate, ROI, ITM%)
- Does NOT feed hand-based stats (VPIP etc.) — those need logged hands

**Post angles**
- "Four taps when you sit down, two when you stand up. Your whole poker
  year, accounted for."
- Contrast post: quick session for busy nights, full logging for study
  nights — one app does both.

**Visuals:** the quick session flow, then the statistics screen showing
accumulated results.

---

## 3. The 7 Core Statistics

**What it is.** Final Table calculates the same professional statistics
online trackers show — from your live play: VPIP, PFR, 3-bet%, fold-to-
3-bet, c-bet%, steal%, and check-raise%. Each with correct opportunity-
based denominators (the app knows a walk in the BB isn't a VPIP
opportunity), broken down by position. Plus win rate and aggression
factor.

**Pain → payoff.** Every serious player knows these numbers matter —
online players study them obsessively. Live players have literally never
seen their own. This is the app's core promise: your real numbers, from
your real hands.

**Personas:** serious rec (primary), grinder.

**VERIFIED FACTS**
- 7 stats: VPIP, PFR, 3-bet%, fold-to-3-bet%, c-bet%, steal%,
  check-raise% — plus win rate and aggression factor
- Position-specific breakdowns (hands, VPIP, PFR, 3-bet by position)
- Stats update in real time as hands are logged
- Calculated with correct opportunity denominators (walks excluded,
  3-bet counted as the second voluntary raise, all-ins counted correctly)

**Post angles**
- "Online players have known their VPIP for 20 years. When did live
  players get theirs? Now."
- Education series: one post per stat — what it is, what good looks like,
  how the app measures it. (Seven posts, free content calendar.)
- "Your VPIP by position" screenshot posts perform — concrete and
  scannable.

**Visuals:** statistics screen scroll; position breakdown table.

---

## 4. Play-Style Detection

**What it is.** After 50 logged hands, the app classifies your game:
TAG, LAG, Nit, Calling Station, Maniac, or Balanced — computed from your
VPIP, PFR, 3-bet% and aggression factor. The labels every poker player
uses about *others*, finally applied to yourself, by math instead of ego.

**Pain → payoff.** Every player has a self-image; almost nobody's matches
their stats. This is the app's identity hook and strongest conversation
starter.

**Personas:** serious rec (primary) — but universally shareable.

**VERIFIED FACTS**
- Six classifications: TAG, LAG, Nit, Calling Station, Maniac, Balanced
- Requires 50 logged hands (progress shown as N/50 until then)
- Based on VPIP, PFR, 3-bet%, and aggression factor thresholds

**Post angles**
- "You think you're TAG. Your 50 hands say Calling Station." (The
  identity-confrontation angle — strongest hook in the product.)
- Interactive: "Guess your style in the comments, then log 50 hands and
  come back."
- Meme-format friendly: the six styles as personality types.

**Visuals:** the play-style reveal moment; the home-screen tile.

---

## 5. Personal Range Grid (13×13)

**What it is.** Every logged hand with known hole cards feeds a personal
13×13 range grid — the same 169-cell matrix solvers and training sites
use — showing which hands you actually play, from which positions, at
which stack depths, with action frequencies (raise/call/check/fold) per
cell. Filter by position, stack depth, and scenario (unopened pot vs
facing a raise).

**Pain → payoff.** Everyone *thinks* they know their preflop game. The
grid shows the truth: that "occasional" J7s limp is right there in
teal. It's the difference between believing you're disciplined and
seeing it.

**Personas:** serious rec (primary), grinder.

**VERIFIED FACTS**
- 13×13 grid, 169 hand classes (pairs, suited, offsuit)
- Per-cell action frequencies: raise / call / check / fold, rendered as
  proportional color splits (like a solver chart)
- Filters: cash/tournament, position group, stack depth, scenario
  (unopened / vs raise)
- Tap any cell to see the actual hands behind it
- Builds automatically from logged hands — no manual entry

**Post angles**
- "This is a solver chart. Except it's not a solver — it's YOU." 
- Side-by-side: "how you think you play the button" vs the actual grid.
- The self-audit angle: find your leak in 10 seconds of scrolling.

**Visuals:** the grid filling in over time; a filtered BTN view; cell
tap-through to real hands.

---

## 6. Dealer Voice Logging

**What it is.** A dealer (or host) runs the whole table hands-free: they
just narrate the game — "seat 3 raises to twelve, seat 5 calls, flop ace
of spades king of hearts queen of diamonds" — and the app logs it with
speech recognition. Voice and manual buttons work together; recognition
mistakes can be rolled back. Every player at the table can follow the
live hand from their own phone.

**Pain → payoff.** This is the wow feature. Logging every hand yourself
is work; a dealer speaking naturally while the app does the bookkeeping
is magic — and it captures the WHOLE table's hands, not just yours.

**Personas:** host/owner (primary), serious rec home games.

**VERIFIED FACTS**
- Real-time speech recognition tuned for poker vocabulary
- Voice and manual action buttons work simultaneously
- Rollback/undo for misrecognitions
- Players and spectators follow the hand live on their own phones
- Auto-starts listening on the first hand; pause/resume anytime

**Post angles**
- "The dealer just talks. The app does the rest." (Show, don't tell —
  this is a video-first feature.)
- Home-game upgrade angle: your Tuesday game, running like a TV table.

**Visuals:** THE hero video — real audio of a dealer narrating while
actions appear on screen; cut to a player's phone showing the same hand
live. Sound on.

---

## 7. Live Scouting Mode

**What it is.** Folded preflop and out of the hand? Scouting mode lets
you keep logging what your *opponents* do — who raised, who called, who
showed down what — building your opponent book even in hands you're not
playing. Your own stats stay clean (scouted hands don't distort your
postflop numbers).

**Pain → payoff.** You fold 75% of hands. That's 75% of the night's
information most players throw away.

**Personas:** serious rec.

**VERIFIED FACTS**
- Opt-in setting; activates when the hero folds preflop
- Logs opponents' preflop actions (action type only) and winner
- Feeds opponent profiles without distorting your own postflop stats

**Post angles**
- "You fold. They keep playing. Keep watching."
- The discipline angle: folding is boring; scouting makes folded hands
  productive.

**Visuals:** the scouting takeover UI after a preflop fold.

---

## 8. Opponent Book

**What it is.** Every named player you face gets a profile: notes, a
color tag, and a playing-style label — your private book on the regulars
in your game. Profiles build automatically from logged hands.

**Pain → payoff.** "How does Mike play river bets again?" Stop relying on
memory for reads you paid real money to learn.

**IMPORTANT (guardrail):** public copy for this feature is **profiles,
notes, and style tags only** — never claim opponent *statistics*
tracking.

**Personas:** serious rec (primary), host.

**VERIFIED FACTS**
- Opponent profiles with notes, color coding, and playing-style tags
- Profiles created automatically from logged hands
- Free tier: 5 opponents; Pro: 30; Elite/Club: unlimited

**Post angles**
- "Your reads are worth money. Write them down."
- The regulars angle: same faces every Friday — you should know more
  about them every week.

**Visuals:** opponent list; a profile with notes and style tag.

---

## 9. Tournament Analytics

**What it is.** Full tournament bookkeeping: buy-ins, rebuys, add-ons,
prize money, finishing position, field size. Computed for you: ITM%, ROI,
average finish, best finish, final-table count, hourly rate, average
buy-in, average field size — split cleanly from your cash-game results.

**Pain → payoff.** The grinder's spreadsheet, automated. Numbers pros
track, without the data entry ritual after every session.

**Personas:** grinder (primary).

**VERIFIED FACTS**
- Tracks buy-in, rebuys, add-ons, prize won, finishing place, field size
- Computed: ITM%, ROI, average finish, best finish, final tables count,
  hourly rate, average buy-in, average field size
- Cash and tournament statistics are separated
- Tournament-aware math throughout (e.g. biggest pot compared in big
  blinds, not chips, because blinds grow through an MTT)

**Post angles**
- "ITM%, ROI, hourly — without the spreadsheet."
- The honesty angle: hourly rate is the stat that tells you if the
  weekly $150 tournament is a hobby or a habit.

**Visuals:** tournament stats section; a filled session history.

---

## 10. Bankroll Management

**What it is.** Set a bankroll goal, track progress with an animated
bar, and view your earnings over time on a pinch-to-zoom landscape
chart with cash and tournament results split out.

**Pain → payoff.** Bankroll discipline is the #1 practical skill in
poker, and most live players track it nowhere.

**Personas:** grinder, serious rec.

**VERIFIED FACTS**
- Bankroll goal with visual progress
- Landscape earnings chart with pinch-to-zoom, cumulative over time
- Cash / tournament breakdown

**Post angles**
- "Your bankroll is your career. Chart it."
- Goal-progress screenshots are naturally shareable milestones.

**Visuals:** the earnings chart (landscape, zoomed).

---

## 11. AI Hand Review

**What it is.** Get a street-by-street written analysis of any logged
hand: preflop decision, bet sizing, missed value, questionable bluffs.
The analysis is written in the app's language (all 11) and matched to
your experience level — beginners get concepts explained plainly,
experienced players get the dense version. Analyses are saved forever.

**Pain → payoff.** A coach charges $100+/hour. This reviews the exact
hand you just played, in your language, at your level, immediately.

**Personas:** serious rec (primary).

**VERIFIED FACTS**
- Street-by-street analysis of logged hands
- Written in the app's language (11 languages) and adapted to the
  user's experience level
- Results saved and reviewable anytime
- Monthly analysis quotas by tier (Pro and Elite; Elite gets more)

**Post angles**
- "Played it. Logged it. Got it reviewed. Same hand, same hour."
- Post a real (anonymized) analysis excerpt — the concrete output sells
  it better than any description.

**Visuals:** analysis screen on a real hand.

---

## 12. GTO Training Drills

**What it is.** Practice preflop like a workout: open-raise charts,
3-bet charts, blind-defense charts, and Nash push-fold drills against
bots. Instant grading, so range knowledge becomes muscle memory.

**Pain → payoff.** Watching training videos isn't studying. Reps are
studying.

**Personas:** serious rec, grinder.

**VERIFIED FACTS**
- Drill types: open-raise, 3-bet, blind defense, Nash push-fold
- Instant per-decision grading against the charts
- Practice against bots, configurable positions/stacks

**Post angles**
- "Five minutes of push-fold drills on the bus beats an hour of poker
  YouTube on the couch."
- Streak/gym framing: poker fitness.

**Visuals:** drill table mid-session with grading feedback.

---

## 13. Clubs & Events

**What it is.** Create a poker club, invite players and dealers, and
host real events — cash games and multi-table tournaments. QR codes
handle seat assignments (scan, sit, play). Live rankings update on every
phone in real time, and a full-screen leaderboard view runs on the venue
TV. The club owner pays for one Club subscription; **every member,
dealer, and player uses the app completely free.**

**Pain → payoff.** Home games and small clubs run on group chats,
paper, and arguments. This is tournament-director software in every
pocket — with a business model that means only ONE person ever pays.

**Personas:** host/owner (primary) — this is their hero feature.

**VERIFIED FACTS**
- Club roles: owner, admin, dealer, player
- Member invitations via email and in-app notifications
- Multi-table events with live, real-time rankings
- QR-code seat assignments (per-seat and per-table)
- Full-screen leaderboard display for a venue TV
- One Club subscription covers the entire club — members, dealers, and
  players pay nothing

**Post angles**
- "One subscription. The whole club plays free." (Lead with the model —
  it's disarming and unique.)
- The transformation angle: your kitchen-table game with live standings
  on the TV like a series final table.
- Target home-game-host communities directly with this one.

**Visuals:** TV leaderboard in a real room; QR scan → seat assignment;
live ranking updates on multiple phones.

---

## 14. Session Summary Card

**What it is.** End any session and get a shareable summary card:
duration, net profit/loss, hands played, biggest pot, best and worst
hand — for tournaments also your finish (e.g. "11th / 28") and prize.
Share it as an image anywhere.

**Pain → payoff.** The "how'd you run tonight?" answer, designed. Every
share is organic marketing with the app's name on it.

**Personas:** all three — this is the viral loop.

**VERIFIED FACTS**
- Card shows: session name, game type, duration, net P/L, hands played,
  biggest pot, best/worst hand
- Tournaments: finishing place, field size, prize won
- Exports as a shareable image

**Post angles**
- Repost-bait: encourage users to share their cards with a hashtag.
- The trophy angle for wins; the honesty angle for losses ("we log the
  red nights too — that's the point").

**Visuals:** the card itself — it IS the visual.

---

## 15. Hand Exports & Sharing

**What it is.** Your data is yours. Export full sessions as
PokerStars-format hand histories (readable by standard poker study
tools) or CSV, email exports to yourself, or share a single hand as a
link anyone can open — no app required.

**Pain → payoff.** No lock-in, and your live hands become study
material in the same tools online players use.

**Personas:** serious rec, grinder.

**VERIFIED FACTS**
- Export formats: PokerStars-format hand history, CSV
- Email export supported
- Single-hand share links that open for anyone
- Monthly export quotas by tier (Pro has monthly quota; Elite unlimited)

**Post angles**
- "Your live hands, in the study tools online players use."
- The data-ownership angle plays well with the anti-lock-in crowd.

**Visuals:** an exported hand history opened in a study tool.

---

## 16. Live Session Following

**What it is.** During dealer-run live sessions, every player and
spectator sees the hand in real time on their own phone — actions,
board, pot — synchronized across the table.

**Pain → payoff.** The table becomes a shared screen; nobody asks
"what's the action?" twice.

**Personas:** host/owner, home games.

**VERIFIED FACTS**
- Real-time action/board/pot sync to all participants' phones during
  dealer sessions
- Spectator mode for watching without playing

**Post angles**
- Rail-your-friend angle; works best inside the club story (see #13).

**Visuals:** two phones side by side showing the same live hand.

---

## 17. Eleven Languages

**What it is.** Full app localization in 11 languages: English, German,
Spanish, French, Italian, Polish, Portuguese, Romanian, Russian, Slovak,
and Ukrainian. Poker terms stay in English everywhere — the way real
players actually speak. AI hand analysis is also written in your
language.

**Pain → payoff.** Poker is global; poker software is stubbornly
English. Home games in Kraków, Bucharest, and Kyiv get the app in their
own language.

**Personas:** all, per-market.

**VERIFIED FACTS**
- 11 languages: EN, DE, ES, FR, IT, PL, PT, RO, RU, SK, UK
- Poker terminology remains in English in all locales
- AI analysis output localized too

**Post angles**
- Per-market posts in the local language (respecting the English poker
  terms rule).
- "Your whole home game, in your language."

**Visuals:** same screen in 3–4 languages side by side.

---

## 18. Offline-First

**What it is.** Everything saves locally on the phone and syncs to the
cloud when you're back online. Basement card rooms and casino dead
zones don't lose hands.

**Pain → payoff.** Live poker happens in places with bad reception. The
app is built for exactly those places.

**Personas:** all.

**VERIFIED FACTS**
- All data saves locally and syncs when connectivity returns
- Hands, stats, and session history preserved through outages

**Post angles**
- "Built for the basement game with one bar of signal."

**Visuals:** airplane-mode demo — log a hand offline, watch it sync.

---

## 19. Guided First Hand (Onboarding)

**What it is.** New users log their first hand inside a guided,
scripted walkthrough — the app teaches its own workflow in one hand,
and the tutorial hand never pollutes real stats.

**Pain → payoff.** Nobody reads manuals at a poker table. One guided
hand and you're live.

**Personas:** all (acquisition-stage content).

**VERIFIED FACTS**
- Interactive guided tour through logging a full first hand
- Tutorial hands are excluded from real statistics

**Post angles**
- "From install to first logged hand: about two minutes." (Only claim
  the duration if a real recording backs it.)

**Visuals:** speedrun-style clip of the tour.

---

## MISC PROOF POINTS (usable anywhere, verbatim)

- The app supports 2–9 handed tables with empty seats handled correctly.
- Money inputs accept both comma and dot decimals (European-friendly).
- Session history has cash/tournament tabs with a calendar view.
- Errors never show raw technical messages — everything is localized,
  human-readable.

## FACTS THAT ARE TRUE BUT OFF-LIMITS OR CAREFUL

- The app internally computes opponent statistics — **never advertise**
  (see GUARDRAILS). Public framing: profiles/notes/tags.
- A launch promo (free Pro month) exists as an admin-controlled toggle —
  only reference when explicitly told it's active.
- Anything not in this document (unreleased experiments, roadmap
  features) does not exist for marketing purposes. Do not tease
  unannounced features under any circumstances.

---

*Maintainer note (not for the agent): unreleased features are
deliberately absent — social feed, hardware experiments, GTOW import,
iOS. Add them here only when they ship. Cross-references for humans:
`marketing/feature-one-pager.md` (short form), `marketing/
demo-video-scripts.md` (shot lists), `release-plan/store-listing.md`
(store copy source of truth).*
