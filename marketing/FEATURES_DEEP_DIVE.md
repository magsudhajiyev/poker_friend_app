# Final Table: Features Deep Dive

**Daily Challenge · Leak Detector · Hand Logging (incl. Easy Hand Logging)**

---

## READ THIS FIRST (header for the marketing agent)

| Item | Value |
|---|---|
| **Purpose** | The single, complete source of truth about three features: what they do, why they exist, what is public, and what you may say about them. |
| **Audience** | (1) The co-founder who runs marketing. He is not technical and does not play poker. (2) His AI / coding agent, which drafts videos, posts, ads and emails from this file only. |
| **Status date** | **2026-11-02.** Every "status" in this file is true on this date. Statuses change. Check with the founder before you publish anything older than a few weeks. |
| **Companion files** | `marketing/MARKETING_MASTER.md` (all features, guardrails, personas), `marketing/feature-one-pager.md` (short form). This file goes deeper on three features. If this file and those files disagree, see section 12 ("Conflicts and unverified facts"). |

### The rules for the agent

1. **When unsure, say "not yet public".** Never promise a feature that is not LIVE for everyone. If a feature is "admin-only", "hidden" or "removed", do not show it, do not tease it, do not hint at it.
2. **Use the "Safe to promote now vs not yet" table (section 1).** It wins over every other sentence in this file.
3. **Numbers come from the facts block (section 14).** Quote them exactly. Do not round, combine or improve them.
4. **The coaches are original characters.** Duke, Prof. Vega and Nova are made up. They are never real poker players and never "inspired by" a named pro.
5. **Never promise winnings.** The app measures and teaches. It does not guarantee profit.
6. **Do not use code words in public copy.** Words like "flag", "admin_only", "Firestore", "solver tree JSON" are for internal use. Section 11 (glossary) tells you the public word to use.
7. **Items marked "unverified"** are not confirmed. Do not use them in public copy until the founder confirms them.

---

## Table of contents

0. [Read this first](#read-this-first-header-for-the-marketing-agent)
1. [Safe to promote now vs not yet](#1-safe-to-promote-now-vs-not-yet)
2. [Poker primer for non-players](#2-poker-primer-for-non-players)
3. [How the three features connect](#3-how-the-three-features-connect)
4. [Feature 1: Daily Challenge](#4-feature-1-daily-challenge)
5. [Feature 2: Leak Detector](#5-feature-2-leak-detector)
6. [Feature 3: Hand Logging](#6-feature-3-hand-logging)
7. [Feature 3b: Easy Hand Logging (admin-only)](#7-feature-3b-easy-hand-logging-admin-only)
8. [Pricing, plans and the free trial](#8-pricing-plans-and-the-free-trial)
9. [Audiences](#9-audiences)
10. [Timeline: what shipped when](#10-timeline-what-shipped-when)
11. [Glossary](#11-glossary)
12. [Conflicts and unverified facts](#12-conflicts-and-unverified-facts)
13. [Global do-not-say list](#13-global-do-not-say-list)
14. [Facts block (machine-readable)](#14-facts-block-machine-readable)

---

## 1. Safe to promote now vs not yet

**Status words used in this file:**

- **LIVE for everyone**: every user with access to the app has it today. Safe to promote.
- **Admin-only (not public yet)**: built, but only the founder's own test account sees it. Do NOT promote.
- **Hidden**: switched off for everyone. Do NOT promote.
- **Removed**: was built or tested, then taken out. Do NOT promote, ever.

| Feature / update | Status | Safe to promote now? | Notes |
|---|---|---|---|
| Daily Challenge (the daily 5-hand workout) | LIVE for everyone | **YES** | Say "up to 5 hands a day" or "a short daily set of hands". Some days have 4 hands. |
| Real solver hands, played street by street | LIVE for everyone | **YES** | Say "solver" or "game theory". Never name the data vendor. |
| Pot-weighted accuracy score (0–100%) | LIVE for everyone | **YES** | |
| Three coaches: Duke, Prof. Vega, Nova | LIVE for everyone | **YES** | Original characters only. |
| Coach VOICE (spoken lines) | LIVE, but **silent right now** | **Careful** | The voice provider quota is used up. It resets around **2026-11-13**. Until then the coach types but does not speak. Do not film "the coach talks" before the voice is back. |
| Coach tone adapts to your level | LIVE for everyone | **YES** | |
| AI coach feedback written from solver facts | LIVE for everyone | **YES** | Say "written ahead of time from the solver's numbers". Do not say "live AI chat". |
| "Show range" chart after each decision | LIVE for everyone | **YES** | |
| Streaks | LIVE for everyone | **YES** | |
| Global leaderboard (3 boards) | LIVE for everyone | **YES** | Participation is automatic. No opt-out. |
| Spoiler-safe share (emoji squares) | LIVE for everyone | **YES** | |
| Replays of past days (Pro 15 days, Elite/Club unlimited) | LIVE for everyone | **YES** | Replays are practice. They never count for streaks or the leaderboard. |
| Sound effects + haptics | LIVE for everyone | **YES** | |
| Engagement notifications (streak saver, coach-voiced pushes) | LIVE for everyone | **YES, softly** | Fine to say "a reminder from your coach before your streak ends". Do not describe the internal timing system. |
| Onboarding demo hand + "Your daily poker workout" screen | LIVE for everyone | **YES** | |
| Super-admin preview of future days | Admin-only | **NO** | Internal tool. |
| Leak Detector | **Admin-only (not public yet)** | **NO, not yet** | Opens to all users soon, after the release that hides Training Drills. Wait for the founder's "go". You may prepare content now. Do not publish it. |
| Leak Detector redesign (2026-10-30) | Admin-only (part of Leak Detector) | **NO, not yet** | |
| Training Drills (open-raise / 3-bet / blind-defense / push-fold) | **Hidden** | **NO** | Not ready. The Leak Detector no longer shows drill buttons. |
| Full hand logging | LIVE for everyone | **YES** | |
| Hand logging redesign (swipe gestures, card keyboard, raise snap, stack rings, live table) | LIVE for everyone | **YES** | |
| 7 core stats, play style, range grid | LIVE for everyone | **YES** | |
| Session summary card | LIVE for everyone | **YES** | |
| Stack chart | LIVE for everyone | **YES** | |
| Comma or dot decimals in money inputs | LIVE for everyone | **YES** | |
| Hand Details redesign (2026-10-30, in release 2.1.7) | LIVE in release 2.1.7 | **YES, once 2.1.7 is in the store** | Unverified: confirm 2.1.7 is live in the store before you post. |
| AI hand analysis | LIVE for everyone (subscription quotas) | **YES** | |
| **Easy hand logging** (fold tick, flag a hand, recall later, pending stack segments) | **Admin-only (not public yet)** | **NO** | Internal flag `easy_hand_logging`. |
| Live insights (villain line, one-line insight after a hand) | **Admin-only (not public yet)** | **NO** | Internal flag `live_insights`. |
| Pocket mode | **Removed** | **NO, never** | |
| "Type a hand" shorthand | **Removed** | **NO, never** | |
| "What's new" tour | **Removed** | **NO, never** | |
| Voice hand logging for players (talk to log your own hand) | Postponed (not in the app) | **NO** | Do not confuse it with Dealer Voice Logging, which is a club feature. |
| Free trial | LIVE (behind the hard paywall) | **YES, with care** | See section 8. Always say the trial length the store shows. Always say it auto-renews. |
| iOS / App Store | **Unverified** | **NO, until confirmed** | MARKETING_MASTER says Android only. iOS release notes for 2.1.7 exist, but launch on iOS is not confirmed. |

---

## 2. Poker primer for non-players

This section explains poker in plain words. You need it to understand every other section. Each idea has an everyday analogy.

### 2.1 The game in one paragraph

The app is about **Texas Hold'em**, the most popular poker game. Each player gets **two private cards** ("hole cards"). Then five **shared cards** ("the board") come out in three steps. Players bet in turns. You win the pot (all the money in the middle) in one of two ways: everyone else gives up ("folds"), or you have the best five-card hand at the end ("showdown").

> **Analogy:** a poker hand is like a short auction where you only partly see what you are bidding on. Every bid tells the others something about you.

### 2.2 A "hand"

One **hand** = one round of poker, from dealing the cards to giving the pot to the winner. A live table plays about **25–35 hands per hour**. The app uses 30 per hour as its estimate.

> **Analogy:** a hand is one point in tennis. A session is the whole match.

### 2.3 The four streets (betting rounds)

| Street | What happens | Cards on the board |
|---|---|---|
| **Preflop** | Players see only their own 2 cards and bet. | 0 |
| **Flop** | 3 shared cards appear. Betting. | 3 |
| **Turn** | A 4th shared card appears. Betting. | 4 |
| **River** | A 5th and last shared card appears. Last betting. | 5 |
| **Showdown** | If two or more players remain, they show cards. Best hand wins. | 5 |

> **Analogy:** the four streets are four chapters of a short story. Each chapter gives more information, and each one costs more to read.

### 2.4 Actions

| Action | Meaning | Analogy |
|---|---|---|
| **Fold** | Give up the hand. You lose what you already put in. | Leaving the auction. |
| **Check** | Pass, without betting. Only allowed when nobody has bet. | "No bid from me, your turn." |
| **Call** | Match the current bet. | "I'll pay the same." |
| **Bet** | Put the first chips in on a street. | Opening the bidding. |
| **Raise** | Increase a bet someone already made. | Out-bidding. |
| **All-in** | Put in every chip you have. | Betting the whole wallet. |
| **Limp** | Just call the minimum before the flop instead of raising. Usually weak. | Walking into a party without bringing anything. |

### 2.5 Blinds, and "BB" as a unit

Before cards are dealt, two players must post forced bets called **blinds**: the **small blind (SB)** and the **big blind (BB)**. They make sure there is always something to win.

Poker players measure everything in **big blinds (BB)**. "I have 100 BB" means "my stack is 100 times the big blind". This lets players compare a $1/$2 game with a $5/$10 game, or early and late tournament levels.

> **Analogy:** BB is like measuring a house in "rooms" instead of dollars. It works in every city, whatever the local prices.

An **ante** is an extra small forced bet, common in tournaments. "BB ante" means the big blind pays it for the table.

### 2.6 Positions

Seats around the table get names, based on where the **dealer button (BTN)** is. The button moves one seat every hand. Acting **last** is a big advantage, because you see what everyone else did first.

| Position | Full name | Acts | Comment |
|---|---|---|---|
| **UTG** | Under the Gun | First before the flop | Hardest seat. Play tight. |
| **UTG+1, UTG+2** | Next seats after UTG | Early | Also "early position" (EP). |
| **LJ** | Lojack | Middle | Also "middle position" (MP). |
| **HJ** | Hijack | Middle-late | |
| **CO** | Cutoff | Late | Seat to the right of the button. |
| **BTN** | Button / Dealer | Last after the flop | Best seat at the table. |
| **SB** | Small Blind | Posts the small blind | Acts first after the flop. Hard seat. |
| **BB** | Big Blind | Posts the big blind | Last to act before the flop. |

> **Analogy:** positions are like the order of speakers in a debate. The last speaker hears every argument first and can answer all of them.

### 2.7 Cash games vs tournaments

| | **Cash game** | **Tournament (MTT)** |
|---|---|---|
| Chips | Real money. Chips = cash. | Tournament chips. Not money. |
| Leave | Any time, with your chips. | When you lose all chips, or win. |
| Blinds | Stay the same. | Go up every level (e.g. every 20 minutes). |
| Result | Profit or loss in money. | Your finishing place and prize. |

**MTT** = multi-table tournament. **ITM** = "in the money" (you finished high enough to win a prize). **ROI** = return on investment.

> **Analogy:** a cash game is a pay-as-you-go gym. A tournament is a marathon with an entry fee and prizes for the top finishers.

### 2.8 Hand names (shorthand players use)

- **AKs** = Ace-King "suited" (both cards the same suit, e.g. both hearts). Suited hands are a bit stronger.
- **AKo** = Ace-King "offsuit" (different suits).
- **99** = a pair of nines ("pocket nines").
- **T** = ten. So "T♠9♣4♦" is a flop of ten of spades, nine of clubs, four of diamonds.
- There are **169** different starting-hand types. They fit in a **13 × 13 grid** (the "range grid").

### 2.9 Ranges

A **range** is the full set of hands a player would play a certain way in a certain spot. Good players think in ranges, not single hands: "From the button, I open about 40% of hands."

> **Analogy:** a range is a restaurant menu. A single hand is one dish. A good player plans the whole menu, not just one plate.

### 2.10 What a solver / GTO is

A **solver** is a computer program that calculates the mathematically strongest way to play a poker spot. Its answer is called **GTO** ("Game Theory Optimal"). GTO play is very hard to beat, because it does not have predictable weaknesses.

Solvers often answer with **frequencies**: "with this hand, bet 70% of the time and check 30%". That is normal. Mixing keeps the opponent guessing.

> **Analogy:** a solver is like a chess engine for poker. It does not get tired, and it shows the best move with numbers.

### 2.11 The core stats (what they mean)

The app calculates these from the hands a player logs.

| Stat | What it measures | Healthy rough range (common wisdom) | Everyday analogy |
|---|---|---|---|
| **VPIP** (Voluntarily Put money In Pot) | How often you choose to play a hand before the flop. | About 15–28% at a full table. | How often you say "yes" to party invitations. |
| **PFR** (Pre-Flop Raise) | How often you raise before the flop. | Close to VPIP, a few points lower. | How often you are the one who organises the party. |
| **3-Bet** | How often you re-raise someone who already raised before the flop. | About 6–10%. | Answering an offer with a bigger counter-offer. |
| **Fold to 3-Bet** | After you raised, and someone re-raised, how often you give up. | About half the time. | How often you back down when someone pushes back. |
| **C-Bet** (continuation bet) | You raised before the flop, then you bet again on the flop. | Often more than half the time. | Keeping the story going after you started it. |
| **Steal** | You raise from a late seat (CO, BTN, SB) when nobody else entered. Goal: take the blinds. | Fairly often. | Taking the last slice of cake when nobody else reaches for it. |
| **Check-Raise** | You check, the opponent bets, then you raise. | Low, but not zero. | Pretending to be quiet, then speaking up loudly. |
| **AF** (Aggression Factor) | How much you bet and raise compared with how much you only call. | About 2–3.5 for solid players. | Driver vs passenger. |
| **Win rate** | How often you win the hands you play. | Varies. | |

Important: the app shows VPIP, PFR and the others **by position**, because a good player plays differently on the button than under the gun.

### 2.12 Play styles (labels players use)

| Label | In plain words |
|---|---|
| **TAG** (Tight-Aggressive) | Plays few hands, but plays them hard. The classic winning style. |
| **LAG** (Loose-Aggressive) | Plays many hands, and plays them hard. |
| **Nit** | Plays very few hands. Very cautious. |
| **Calling Station** | Calls a lot, rarely raises. Easy to beat. |
| **Maniac** | Plays almost everything, very aggressively. |
| **Balanced** | A mix close to "correct" play. |

The app gives you a label after **50 logged hands**.

### 2.13 Two more words: "leak" and "variance"

- A **leak** is a repeated habit that loses money over time. Example: "always folds to a river bet". One bad hand is not a leak. A pattern is.
- **Variance** is luck over the short term. A good player can lose for weeks. That is why the app talks about **habits** (frequencies), not only results.

> **Analogy:** a leak is a dripping tap. One drop is nothing. A year of drops is a big water bill.

---

## 3. How the three features connect

```
  1. HAND LOGGING           2. LEAK DETECTOR             3. DAILY CHALLENGE
  ----------------          ----------------             ------------------
  You record the hands  ->  The app reads all your  ->   Every day you train
  you really play, at       hands and finds your         decisions on real
  the table.                repeated mistakes            solver hands, with a
                            ("leaks"), with proof        coach, a score and a
                            from your own hands.         streak.
        ^                                                         |
        |_________________________________________________________|
             Better decisions at the table -> new hands to log
```

**In plain words:**

1. **Log** your hands. This gives you your real stats (VPIP, PFR and the others).
2. The **Leak Detector** (not public yet) compares those stats with healthy ranges and tells you the one thing to fix first, and shows you the hands where it happened.
3. The **Daily Challenge** builds the habit of good decisions in a few minutes a day. It is like a gym: small reps, every day.

**Also connected:**

- The coach's tone in the Daily Challenge adapts to the player's level. When a player has logged enough hands (150+), the level comes from their real play. Before that, it comes from the answer they gave in onboarding.
- The session summary card (shown after every session) can show a one-line "leak check" under it. This chip is part of the Leak Detector, so it is also admin-only today.

**Marketing line for the whole system (safe now):** "Log the hands you play. Train the decisions you face." When the Leak Detector opens, extend it: "Log it. Find the leak. Train the fix."

---

## 4. Feature 1: Daily Challenge

### 4.0 Overview

**Plain English.** Every day, the app gives every player the **same short set of poker hands** (up to 5). You play each hand, decision by decision. After each decision, a cartoon coach tells you if your move was the **best move**, a **good** move, or a **leak** (a mistake), and explains why. At the end you get a score in percent, your streak grows, and you can see where you rank on a global leaderboard. It takes a few minutes. It is like Wordle or the chess.com daily puzzle, but for poker.

**The problem (a real scene).**
> Marco plays poker every Friday. On Tuesday night he watches a poker video on YouTube. He nods along, but on Friday he makes the same mistakes again. He never really practised. He just watched. He also has no idea if he is getting better, because the cards are different every week and luck hides everything.

**How we solved it (as the user sees it).**
1. Marco opens the app. The home screen shows a **Daily Challenge** card with today's challenge and his streak flame.
2. He taps it. He sees the intro: today's format, his streak, his coach, and buttons for the **Leaderboard** and **Past challenges**.
3. He taps **Play**. A poker table appears. He holds a real hand (for example a pair of nines on the Lojack seat).
4. Before each decision, his coach makes a short, casual comment about the situation ("The button 3-bets you. Ten, nine, four on the flop. You've got a set.") The coach never tells him the answer before he acts.
5. He taps an action: Fold, Check, Call, Bet/Raise or All-in.
6. The coach reacts: a badge pops up (**BEST MOVE** / **GOOD** / **LEAK**), the phone gives a small vibration, a sound plays, and the coach explains the move in his own style.
7. The opponent answers. The hand goes on to the next street. Marco's choices decide which way the hand goes.
8. After all hands, he sees his **day score in percent**, coloured dots for every decision, a breakdown per hand, his **streak**, and a **Share** button.

**Under the hood (simple words).** The hands come from a **solver** (a poker math program). Each hand is stored as a "game tree": every possible line the hand can take, with the solver's numbers for every choice. The app grades the player's choice against those numbers. Everyone gets the same hands on the same day, so scores are fair to compare.

**Why it matters to players.**
- Practice instead of watching. Reps build habits.
- Honest feedback, from real solver numbers.
- A few minutes a day. It fits on the bus or in a coffee break.
- A reason to come back every day (streak, leaderboard, coach).

**Marketing angles.**
- Hooks: "Wordle, but for poker." · "Five hands. One coach. Every day." · "Your daily poker workout." · "Would you call here? Duke would."
- One-line pitch: **"A few real solver hands every day, graded move by move by a coach with attitude."**
- Content ideas: daily "would you call?" posts with today's spot (only after the day is over, to stay spoiler-safe); coach personality reels; "my 30-day streak" user stories; leaderboard top-3 shout-outs (ask for consent before naming a user).
- Audience: **beginner** (learn by doing, friendly coach), **regular** (habit, streak), **grinder** (solver accuracy, leaderboard). Clubs: a club could run its own "who has the longest streak" game.

**Status.** LIVE for everyone (flag `daily_challenge` = on). First built 2026-10-14. Note: the whole app is behind the hard paywall, so "everyone" means every user with a subscription or a trial (see section 8).

**Do-not-say / accuracy notes.**
- Say "up to 5 hands a day" or "a short daily set". Some days have 4 hands.
- Never name the solver company or tool. Say "solver" or "game theory".
- The coaches are original characters. Never compare them to a real pro.
- The coach voice may be silent until about 2026-11-13 (see 4.4).
- Do not say "AI coach talks to you live". The feedback is written ahead of time (see 4.6).
- Do not say "the app tells you the GTO answer for your real games". The challenge uses its own prepared hands, not the player's own hands.

---

### 4.1 History: version 1 was random preflop drills (RNG)

**Plain English.** The first Daily Challenge (2026-10-14) gave **5 single preflop decisions** a day. "Preflop" means before any shared cards appear. Example: "You are on the button with A5 suited. Everyone folded to you. Raise or fold?"

**How it worked.**
- The day's 5 spots were created by a random generator ("RNG") that uses the **date as its seed**. Same date = same spots for everyone.
- Each weekday had a theme:

| Day | Theme | Stack | Table | Format |
|---|---|---|---|---|
| Mon | Deep Stack Monday | 100 BB | 6 players | cash |
| Tue | Full Ring Tuesday | 100 BB | 9 players | cash |
| Wed | Mid-Stack Wednesday | 40 BB | 8 players | tournament |
| Thu | Six-Max Thursday | 60 BB | 6 players | cash |
| Fri | Short Stack Friday | 25 BB | 8 players | tournament |
| Sat | Push-Fold Saturday | 15 BB | 9 players | tournament |
| Sun | Sunday Deep | 100 BB | 9 players | cash |

- The grades came from the app's preflop charts. On short-stack days (20 BB or less) the grading used "push-fold" charts (all-in or fold).
- Score was out of 5 (best = 1, good = 0.5, leak = 0).

**Why it changed.** Preflop-only spots are only a small part of poker. Most of the hard decisions come later, on the flop, turn and river. The team wanted real, full hands.

**Status today.** The random preflop day is now only a **backup**. Since the 2026-10-29 hardening, unscheduled days play a fixed rotation of real solver hands. In practice players see solver hands. (Unverified: whether any user still sees a random preflop day in an edge case.)

**Marketing note.** Do not market the old version. Market the solver hands.

---

### 4.2 Real solver hands, street by street (authored game trees)

**Plain English.** Since 2026-10-21, the challenge uses **real hands calculated by a solver**. You play a full hand, from before the flop to the end, street by street. You can choose **any legal action**. The hand changes direction based on what you choose. So two players can play the same hand in different ways and see different turns of the story.

**The problem (a real scene).**
> Priya has done preflop quizzes for months. She knows when to raise. But on the flop she freezes: "I have top pair, he bet half the pot... now what?" Quizzes never taught her that. Real hands have many decisions, and each one changes the next.

**How we solved it (as the user sees it).**
1. Priya sees "Hand 1/5" at the top. The table shows her seat, the opponent's seat, the stacks, and the pot.
2. She gets her two cards, for example K♦Q♦.
3. The coach sets the scene in a casual way.
4. She acts. The coach grades her. She taps **Next**.
5. The opponent answers (it fades in after she taps Next, so it never pops up while she reads the feedback).
6. A new card appears on the board. The coach reads the new board: "That turn card brings a third diamond. You now have a flush draw."
7. This repeats until the hand ends (fold, showdown, or the last decision).
8. Then "Hand 2/5" starts.

**Under the hood (simple words).**
- Each hand is a "tree": every node is a decision point. For each decision, the solver lists how often to fold, check, call, bet or raise **with this exact hand**.
- The opponent always plays the solver's most common answer. So the hand is the same for everyone who takes the same line.
- If the player picks an action the solver did not fully calculate (a rare side-line), the app still grades it honestly, then continues the hand along the solver's main line. Every hand reaches a real ending.
- **Fold always ends the hand.**
- The app also offers a **Bet** button where the solver only checks. This is a training choice: in real life you can always bet. That bet is sized at one third of the pot and is graded as a leak.
- Hands are prepared by the team, ahead of time, from solver data sheets. A tool turns each sheet into a tree and uploads it. A separate tool schedules which hands play on which day.

**Grading bands (exact).**

| What the solver does with your hand | Grade | Badge |
|---|---|---|
| Your action is chosen **65% of the time or more** | Correct | **BEST MOVE** (green) |
| Your action is chosen **15% to 65%** of the time | OK | **GOOD** (yellow) |
| Your action is chosen **less than 15%** of the time | Mistake | **LEAK** (red) |

**Softening rule:** if your move is rare for your exact hand, but the whole range often makes that move (25% or more), and it is not a fold, the app gives GOOD instead of LEAK. Reason: that move is a standard play, not a blunder.

**Close spots:** when your move is the solver's top choice but below 65% (for example 59%), you get GOOD and the coach **confirms** it was a valid play: "the most frequent choice, a close mix". It does not suggest a better move that does not exist.

**Why it matters to players.**
- Practice the hard parts of poker: flop, turn and river.
- Learn that poker is about mixes and frequencies, not one "correct" answer.
- Feel the consequences of a choice: the hand changes with you.

**Marketing angles.**
- Hooks: "Play the whole hand, not just the first click." · "Your choice changes the hand." · "Graded against real solver numbers."
- One-line pitch: **"Real solver hands that branch on your decisions, street by street."**
- Content: a split-screen video, two players, same hand, different choices, different endings.
- Audience: regular, grinder. For beginners, lead with the coach, not the solver.

**Status.** LIVE for everyone.

**Do-not-say.**
- Never name the data source or the solver product. Say "solver".
- Do not say "unlimited hands a day". It is one short set per day (plus replays for paid tiers).
- Do not say every day has exactly 5 hands.
- Do not show the solver's frequencies for TODAY in public posts. That spoils the puzzle for others.

---

### 4.3 The score: pot-weighted accuracy (0–100%)

**Plain English.** Your day score is a percentage. Big decisions count more than small ones. A mistake in a big pot costs you more than a mistake in a small pot. That is how real poker works.

**How it is calculated (exact).**
1. Each decision gets a value: **BEST = 1**, **GOOD = 0.5**, **LEAK = 0**.
2. Each decision has a weight: **the size of the pot in big blinds** at that moment (minimum 1).
3. **Hand accuracy** = the weighted average of the decision values in that hand.
4. **Day score** = the plain average of the hand accuracies, times 100. Every hand counts the same, whatever its length.
5. **Perfect day** = every decision was BEST.

**Example.** A hand has two decisions: a small preflop call (pot 3 BB, BEST = 1) and a big river call (pot 30 BB, LEAK = 0). Hand accuracy = (1×3 + 0×30) / 33 ≈ 9%. The river mistake dominates, because it was the expensive one.

**Under the hood.** The same formula runs on the player's phone and on the server. The server recomputes the score for the leaderboard, so a player cannot fake it.

**Why it matters.** It teaches a real truth: protect the big pots first.

**Marketing angles.** "Big pots count more. Just like real life." · Show the score screen with green, yellow and red dots.

**Status.** LIVE.

**Do-not-say.** Do not invent average scores or "top players score X%". No such statistics are published.

---

### 4.4 The coaches: Duke, Prof. Vega and Nova

**Plain English.** Before playing, the player picks a coach. The coach comments on each decision in their own style. The poker content is the same for every coach. Only the personality and delivery change.

All three are **original characters**, created for the app. They are **not** based on real poker players. (This protects against personality-rights problems.)

| | **Duke** | **Prof. Vega** | **Nova** |
|---|---|---|---|
| Tagline (in the app) | Old-school Vegas grinder | Dry GTO theorist | High-energy hype coach |
| Look (3D-style mascot) | Cowboy hat, mustache, amber colours | Round glasses, teal colours | Coral-pink ponytail, headset, gold star face paint |
| Greeting (in the app) | "Name's Duke. Forty years at the felt. Show me you can fold, kid." | "Professor Vega. We will proceed by equilibrium. Deviations will be noted." | "Nova here! Five spots, full focus — bring your A-game and let's make it a perfect day!" |
| On a best move | "Snap call, kid. Just like downtown." | "Optimal. Raise is indicated." | "BOOM! Raise was the play!" |
| On a mistake | "Nah, kid. Fold was the move." | "Deviation detected: call was correct." | "Shake it off — fold next time!" |
| Voice | Older American man, wise, a bit gravelly | British, warm storyteller | Young, energetic woman |
| Internal id | `grinder` | `professor` | `nova` |

**History of the cast.**
- 2026-10-14: the first cast was Duke, Prof. Vega and **Rocket** (a hype coach with a mohawk). The same day, after feedback, **Rocket was retired and replaced by Nova**. Never mention Rocket in public.
- Prof. Vega's first voice sounded robotic. It was recast to a warmer British voice the same day.
- First mascots were simple line drawings. The same day they were replaced by **3D-style rendered mascots** with four expressions each: idle, happy, OK, upset.

**How the mascot behaves.** On a best move the mascot looks happy and bounces once. On a mistake it frowns and shakes its head once. The mascot "stands" on top of the coach's speech box. Animations play once. Nothing loops forever.

**The voice (important for video).**
- The voice is a real-sounding neural voice (a text-to-speech service). There is **no robot fallback**: if the voice cannot load, the coach stays silent and the text still types out.
- The verdict waits for the voice: the badge, colour, vibration and text appear together when the coach starts to speak. This builds a small moment of suspense.
- Spoken lines say poker hands in words ("pocket nines", "ace five suited"), not in code ("99", "A5s").
- **Right now (2026-11-02) the voice is silent** for new lines. The voice provider's free quota ran out on 2026-10-21. It resets around **2026-11-13**, or when the plan is upgraded. Lines heard before may still play from the cache.
- The player can mute the voice. The mute is separate from the sound effects.

**When the coach's hand is mentioned.** When the coach names the player's hand, the hole cards glow for a moment, in time with the voice.

**Why it matters.** People remember characters. A coach with a personality makes a dry math lesson fun and sticky. Players pick the coach that fits them.

**Marketing angles.**
- Hooks: "Pick your coach." · "Duke has been at the felt for 40 years. He has opinions." · "Prof. Vega does not do small talk." · "Nova is your hype squad."
- One-line pitch: **"Three coaches, three personalities, one honest verdict."**
- Content ideas: "Which coach are you?" quiz; the same mistake told three ways; coach reaction compilations; mascot stickers.
- Audience: everyone. Nova for beginners and casual players, Duke for live regulars, Vega for study-minded grinders.

**Status.** LIVE (coaches, mascots, text). Voice: LIVE but silent until about 2026-11-13.

**Do-not-say.**
- Never say a coach is a real person, a real pro, or "based on" anyone.
- Do not use pronouns for Prof. Vega in public copy until the founder confirms (see section 12: one doc calls Vega "she", but the cast voice is male). Use "Prof. Vega" or "the Professor".
- Do not film or promise "the coach talks to you" before the voice is back.
- Do not mention Rocket.
- The coach lines are written in **English**. The app menus are in 11 languages, but do not promise the coach speaks other languages.

---

### 4.5 Coach tone adapts to your experience level

**Plain English.** The same coach talks differently to a beginner and to an expert. To a beginner, the coach is warm and explains simple ideas. To an advanced player, the coach is short and technical.

**The problem (a real scene).**
> Lena started poker three months ago. A training app tells her "your bluff-to-value ratio is off at this SPR". She closes the app. Meanwhile her friend Tom, who plays five nights a week, finds "betting is good when you have a strong hand" boring.

**How we solved it.**
- Three levels: **beginner**, **intermediate**, **advanced**.
- **Before** the player has 150 logged hands: the level comes from the onboarding question about their "poker journey" (beginner / just for fun → beginner; regular → intermediate; pro → advanced).
- **After** 150 logged hands: the level comes from how they really play (their play style).
- The coach lines exist in all three versions, for all three coaches.

**Why it matters.** Nobody is talked down to, and nobody is lost.

**Marketing angles.** "Coaching that meets you where you are." · "Beginner or pro, the coach speaks your language." (Careful: "language" here means level, not English vs German.)

**Status.** LIVE.

**Do-not-say.** Do not say the app "reads your mind" or "learns from your mistakes in real time". The level comes from onboarding and logged hands.

---

### 4.6 AI coach feedback, pre-generated from solver facts

**Plain English.** The coach's explanations are written by an AI, but **ahead of time**, not live. The team prepares a short fact sheet for every hand: the real solver numbers, what the hand is, what the opponent likely holds, the danger cards, the key idea. The AI writes the coach lines **only from those facts**, in each coach's voice, for each level. A check program rejects any line that invents numbers or breaks the rules.

**The problem.**
> Generic AI chat bots make things up about poker. They quote wrong numbers with confidence. A player cannot tell if the advice is right.

**How we solved it.**
1. For every hand, a fact block lists the solver facts and teaching points.
2. A batch job asks the AI for lines: one set per hand × decision point × action × coach × level, with **2 versions** each (so two friends do not always see the same sentence).
3. Every line is checked: numbers must match the facts, banned phrases are blocked, openings must vary. A failing line is retried once, then replaced by a safe fallback.
4. If any fact block fails its checks, the whole day is rejected and fixed before it goes live.
5. The app only reads the finished lines. **No AI call happens while the player plays.** That keeps it fast, cheap and consistent.

**Fixes worth knowing (for accuracy).**
- 2026-10-28: lines are stored per decision point. Before, a preflop call could show a flop sentence ("you made two pair") because the same action appeared on two streets. Fixed.
- 2026-10-28: dealt cards now match the fact sheet exactly.
- 2026-10-29: every coach line now has correct punctuation and capital letters, in text and in voice. Fallback lines always describe the action the player actually took.
- 2026-10-26: the coach says "You've flopped X" only for a real made hand. It says "bet" when nobody has bet yet, and "raise" when someone has.

**Under the hood.** A cost check runs before each batch. A full day costs a few dollars to generate.

**Why it matters.** The explanations are both readable and trustworthy. They come from real solver data, not from AI guesses.

**Marketing angles.**
- Hooks: "AI that only speaks solver truth." · "No made-up numbers."
- One-line pitch: **"Coach explanations written by AI, checked against the solver, before you ever see them."**
- Audience: grinders and skeptics who distrust AI advice.

**Status.** LIVE.

**Do-not-say.**
- Do not say "chat with your coach" or "ask the coach anything". There is no chat.
- Do not say "real-time AI analysis" for the Daily Challenge.
- Do not name the AI provider in public copy unless the founder approves.
- (The separate **AI Hand Analysis** feature, for the player's own logged hands, does call an AI when the player asks. That is a different feature.)

---

### 4.7 "Show range" after each decision

**Plain English.** After each graded decision, the player can tap **Show range**. A 13 × 13 colour chart opens. It shows how the solver plays every possible hand in that spot, and the player's own hand is circled. Colours: raise orange, all-in purple, call green, check teal, fold blue.

**Why it matters.** The player sees the whole picture, not only their own hand. This is how strong players study.

**Marketing angles.** "See the whole range, not just your hand." Good visual for a carousel post.

**Status.** LIVE.

---

### 4.8 Streaks

**Plain English.** Play the challenge on consecutive days to build a **streak** (shown with a flame 🔥). Miss a full day and the streak resets to zero.

**Exact rules.**
- The streak stays alive if you played yesterday and today is still open.
- A fully missed day breaks it. There is no "streak freeze" today.
- **One ranked attempt per day.** If you leave in the middle of a run, nothing is recorded, and you can play the day again.
- The app also counts your **best streak**, **perfect days** and **total days played**.
- A perfect day shows a special check animation and a strong vibration.
- Since 2026-10-29, streaks merge across devices: a new phone never lowers your streak.

**Why it matters.** Streaks are the strongest habit tool there is (see Duolingo, Wordle).

**Marketing angles.** "Don't break the chain." · User streak milestones (with consent). · "Day 1 starts today."

**Status.** LIVE.

**Do-not-say.** Do not promise streak freezes or "repair a missed day". They do not exist.

---

### 4.9 The global leaderboard

**Plain English.** Everyone who plays appears on a **global leaderboard** automatically. There are three boards, and you swipe between them:

| Board | Ranks players by |
|---|---|
| **Current streak** (headline board) | Longest active streak (players with a streak of 1 or more) |
| **Today** | Today's score; ties go to the faster player |
| **Best streak (all-time)** | Longest streak ever |

The board shows the **top 100** and **your own rank**, even if you are below 100.

**Names.** The board shows the player's **username**. When a player without a username finishes a challenge, the app asks them to pick one. They can skip. If they skip, the board shows their display name, or "Player" plus four digits as a last resort.

**Fair play.** The phone sends the player's answers. The server recomputes the score from those answers. If the phone sent a wrong score, the server corrects it. Since the 2026-10-29 hardening (see 4.14), an entry cannot be edited after it is made, and a stale streak (one that was not extended) is hidden and expired every night.

**Why it matters.** Friendly competition, a reason to come back, and proof of progress.

**Marketing angles.** "Climb the global board." · "Are you top 100 today?" · Weekly shout-out of top streaks (only with the player's permission).

**Status.** LIVE.

**Do-not-say / accuracy.**
- **Participation is automatic.** There is no opt-in, no opt-out and no anonymous mode. Do not say "optional" or "join the leaderboard if you want". (This was the founder's decision on 2026-10-15. He accepted the store / privacy risk.)
- There is no friends-only board and no weekly board.
- Do not publish other players' usernames without their permission.
- Replays never appear on the leaderboard.

---

### 4.10 The spoiler-safe share

**Plain English.** After the challenge, the player can tap **Share**. The app creates a short text with coloured squares, like Wordle. It shows how the player did, without revealing the hands.

**Example (format from the app):**
```
Final Table Daily #12 · 78.5%
H1 🟢🟢🟡
H2 🟢🔴
H3 🟢🟢🟢🟢
🔥6 day streak
```
- 🟢 = best move, 🟡 = good, 🔴 = leak.
- One row per hand ("H1", "H2"…). The streak line appears when the streak is more than 1.
- "Daily #1" was 2026-10-14. The number goes up by one each day.

**Why it matters.** Every share is free advertising. It works in group chats and social posts.

**Marketing angles.** Encourage players to post their squares with a hashtag. Run "post your daily squares" weekly threads.

**Status.** LIVE.

**Do-not-say.** Do not post a screenshot of today's actual hands. Posting the squares is fine.

---

### 4.11 Replays of past days (tier-based)

**Plain English.** A player can go back and replay a past day's challenge, for practice. A month calendar shows every day. Tap a past day to replay it. The hands are exactly the same as on that day.

| Plan | Replay window |
|---|---|
| Free | No replays (the day is locked and opens the paywall) |
| **Pro** | **Last 15 days** |
| **Elite** and **Club** | **Unlimited** (back to the first challenge, 2026-10-14) |

**Rules.**
- Replays are **practice only**. They never change the streak, the ranked score or the leaderboard.
- The calendar remembers your latest replay result for each day.
- Entry: the **Past challenges** button, on the challenge intro and on the results screen.
- A paid upgrade unlocks older days at once.

**The problem (scene).**
> Sam was travelling for a week and missed six challenges. He wants to play them. Or he got a LEAK on a river call yesterday and wants to try again.

**Why it matters.** Missed days are not lost. Mistakes can be retried. It also gives paid plans a clear extra value.

**Marketing angles.** "Missed a day? Replay it." · "Pro: last 15 days. Elite: every day since day one." · Good for paywall and upgrade emails.

**Status.** LIVE (since 2026-10-25).

**Do-not-say.** Do not say replays "save your streak". They do not.

---

### 4.12 Sound effects and haptics

**Plain English.** Each verdict plays a short sound (one for best, one for good, one for leak), and the challenge ends with a fanfare. The phone also vibrates: medium for a best move, light for good, strong for a leak. Sounds have their own on/off switch, separate from the coach voice. Default: on.

**Status.** LIVE (since 2026-10-15).

**Marketing angle.** Sound-on reels: the "ding" of a best move is satisfying.

---

### 4.13 Engagement notifications (streak saver and smart send time)

**Plain English.** The app sends friendly reminders, written in the voice of the player's chosen coach, to help them keep their streak. The push can show the coach's face as its icon (on Android; iOS shows text only for now).

**Types of message.**

| Type | When | Example (from the app) |
|---|---|---|
| **Streak saver** | The evening before a streak would end | Duke: "Clock's ticking. Your 6-day streak dies at midnight, kid. Five hands. Move." |
| **Today's challenge is ready** | Morning | (coach-voiced "today's challenge" message) |
| **Milestone** | After a new personal best streak or leaderboard milestone | Vega: "Statistically notable. A new best: 10-day streak. The trend line is favorable." |
| **Come back** (re-engage) | When a player has been away | Always neutral and kind. Never shaming. |

**How it works (simple words).**
1. When a player completes today's challenge, the phone schedules tomorrow's reminder for **19:00 local time**. This works even offline.
2. A server job also runs every hour. It sends at two windows per player: a **morning** window (10:00 local) and an **evening** window (one hour before the time the player is usually active).
3. Guardrails stop too many messages. About 10% of players get no server pushes, as a test group, so the team can measure if the pushes really help.
4. Players control it in Settings: master switch, separate switches for streak / leaderboard / come-back messages, and **quiet hours** (22:00–08:00 by default; the streak saver is allowed in quiet hours).
5. Muting streak messages also cancels any reminder that was already scheduled.

**Why it matters.** Reminders help habits stick. A coach-voiced message feels like a friend, not a robot.

**Marketing angles (keep soft).** "Your coach has your back, even at 11 p.m." · "Duke will remind you. Duke always reminds you."

**Status.** LIVE (flag `engagement_notifications` = on). Built 2026-10-16/17, send windows reworked 2026-10-21.

**Do-not-say.** Do not describe the hourly scheduler, the 10% test group, or analytics tracking in public copy. Do not promise a notification at an exact time.

---

### 4.14 The hardening fixes (2026-10-29)

These are behind-the-scenes fixes. They make the challenge fair and reliable. They are not exciting for ads, but they back up claims like "fair leaderboard".

| Area | What changed, in simple words |
|---|---|
| Leaderboard security | An entry can be created once and never edited. Time and score values must be realistic. Streak numbers are capped at what is possible since day one. |
| One ranked attempt per day | Checked on the server too, not only on the phone. |
| Time zones and daylight saving | "Today" is the player's local day. Streak and replay dates are correct when the clocks change. A run that starts at 23:58 is saved under the day it started. |
| Cross-device streak | A new phone never lowers your server streak. |
| Stale streaks | Hidden on the board; a nightly job expires them. |
| Offline | The day's schedule must come from the server. If the phone is offline, the app shows a Retry card instead of the hands. This stops "peeking" at answers offline. |
| Privacy | When a user deletes their account, their leaderboard entries are deleted too. |
| Content | The old test default ("serve one test hand every unscheduled day") was replaced by a fixed rotation of real hands. |
| Languages | Remaining English-only Daily Challenge screen texts were translated into all 11 app languages. |

**Status.** Code is in the app. **Unverified:** the matching server rules were marked "not deployed" on 2026-10-29. Do not make security claims ("cheat-proof") until the founder confirms the deploy.

**Marketing angle (careful).** "A fair board: the server checks every score." That much is true today. Avoid "cheat-proof".

---

### 4.15 Onboarding: the demo hand and "Your daily poker workout"

**Plain English.** New users meet the Daily Challenge during sign-up, before they see the paywall.

**What the new user sees (since 2026-10-29).**
1. **"Try today's challenge"**: an animated screen with the three coaches dropping in. The user can tap a coach to hear / see the greeting and pick a coach. A short "How it works" timeline explains the idea.
2. The user plays **one demo hand** (today's first hand). The last button says **Done**. The demo result is thrown away. It does not count for streak or leaderboard. The user can also **Skip**.
3. **"Your daily poker workout"**: an animated screen. A streak strip fills day by day with a flame. A sample leaderboard shows the user's own row climbing from 4th to 1st with a trophy.
4. Then the app continues to Home and the in-app tour, then the paywall.

**Other onboarding fixes.** The app now always asks new users for a username (a bug sometimes skipped it).

**Why it matters.** The user feels the product before paying. The demo is the "aha" moment.

**Marketing angles.** "Play a hand before you pay a cent." · Show the onboarding animation in an app-install ad.

**Status.** LIVE.

**Do-not-say.** Do not say "free forever" or "no card needed" (see section 8).

---

### 4.16 Admin-only Daily Challenge tools (internal only)

Do not market any of these.

- **Super-admin preview of upcoming days** (2026-10-30): the founder can play scheduled future days (up to 45 days ahead) from the calendar, as unranked replays, to check them.
- **Day shift and coach-level tester**: internal test tools. Results made with them never reach the leaderboard.
- **"Reset today (testing)"**: only for the founder.

Related public fix in release 2.1.7: the home screen card now switches to the new challenge at midnight, even if the app stayed open.

---

## 5. Feature 2: Leak Detector

> **STATUS: ADMIN-ONLY. NOT PUBLIC YET.** The flag `leak_detector` is set to admin-only. It opens to all users soon, after the release that hides Training Drills (release 2.1.7). You may prepare content. **Do not publish until the founder says "go".**

### 5.0 Overview

**Plain English.** The Leak Detector reads **every hand the player has logged** and finds their **leaks**: repeated habits that lose money. For each leak it explains what it saw, why it costs money, and how to fix it, and it shows the actual hands where it happened. It only gives a verdict when there are enough hands to be fair.

**The problem (a real scene).**
> Dave has lost a little every month for a year. He thinks it is bad luck. In truth, he folds to almost every bet on the river. Opponents have noticed. They bluff him at the end of every hand. Dave cannot see it, because each fold felt reasonable at the time.

**How we solved it (as the user sees it).**
1. Dave opens **Leak Detector** from the Menu screen.
2. At the top: a one-line verdict ("1 leak to fix · 6 solid"), the number of hands analysed, and when it was last updated.
3. The **Leaks** tab shows **"Fix first"**: one main leak card. Example: "Folding vs river bets: you 78% · healthy 30–62%".
4. He opens the card. It has clear blocks: **What we saw**, **What it costs**, **The fix**, **By position**, and **Your hands** (with card pictures).
5. He taps one of his hands. The full hand opens. He sees the exact moment.
6. He taps **Work on this**. The leak becomes his focus goal. Each visit shows his progress toward the healthy range.
7. Later, when the number moves back inside the band, the app celebrates and moves it to a **Fixed leaks** trophy shelf.

**Under the hood (simple words).** The app recomputes everything from the raw hands each time (no running totals). This avoids counting mistakes. Some hands are left out: walks (everyone folded to the big blind), scouted hands, tutorial hands, and quick sessions (which have no hand details).

**Why it matters.**
- It turns "I'm unlucky" into "here is the habit, here is the proof, here is the fix".
- It is honest: no verdict on too few hands.
- It points at the player's own hands, not generic theory.

**Marketing angles (for later, when it opens).**
- Hooks: "Bad luck, or a leak?" · "The app found my leak in 282 hands." (only with real data and permission) · "Your poker, audited."
- One-line pitch: **"The Leak Detector reads every hand you've logged and shows you the one habit costing you the most."**
- Content: "Is this a leak?" series, one detector per post; before/after "fixed leak" stories; a coach-style explainer video (an explainer video with Prof. Vega exists in `marketing/`, check it is up to date before use).
- Audience: **regular** (primary), **grinder**, also clubs (players can compare habits, but there is no club board).

**Status.** **Admin-only (not public yet).** First built 2026-09-02, shipped in code 2026-09-05 (behind the flag). Retention features 2026-10-12/13. Redesign 2026-10-30. Drill buttons hidden 2026-11-01.

**Do-not-say.**
- Do not promote yet.
- Do not say the bands come from a solver. They are **common-wisdom ranges**, from population norms, widened for live play.
- Do not promise money ("fix this leak and win $X").
- Do not mention Training Drills as a fix path (they are hidden).
- The detailed coaching text inside the cards is written in English. (Unverified: whether it was translated in the 2026-10-30 redesign. The screen labels are in 11 languages.)

---

### 5.1 What a leak is, and the healthy bands

**Plain English.** A leak is **not** "I lost this hand". A leak is a habit that sits **outside a healthy band**. For example, folding to river bets is fine between 30% and 62% of the time. Above 62%, opponents can bluff you. Below 30%, you pay off too many strong hands.

**Why bands, not money?** Live players log hundreds of hands, not millions. Money results swing wildly with luck. **Habits (frequencies) settle about ten times faster** than money results. So the Leak Detector judges habits.

**The eight detectors (exact numbers from the app).**

| # | Detector (app title) | Plain meaning | Healthy band | Min. spots for a verdict | Spots for "Confirmed" |
|---|---|---|---|---|---|
| 1 | Folding vs river bets | How often you fold when someone bets on the river | **30–62%** | 12 | 30 |
| 2 | Folding vs turn bets | How often you fold to a bet on the turn | **25–58%** | 15 | 35 |
| 3 | Folding vs flop bets | How often you fold to a bet on the flop | **25–55%** | 20 | 45 |
| 4 | Folding to 3-bets after opening | You raised first, someone re-raised, you gave up | **35–68%** | 10 | 25 |
| 5 | BB folds vs steals | In the big blind, how often you fold to a late-seat raise | **40–72%** | 12 | 30 |
| 6 | Open-limping | How often you enter a pot by just calling the blind | **0–12%** | 40 | 80 |
| 7 | Going to showdown | Of hands where you saw a flop, how often you went to the end | **20–34%** | 30 | 60 |
| 8 | Winning at showdown | Of showdowns, how often you won | **46–62%** | 15 | 35 |

Both sides of a band can be a leak. Example: winning almost every showdown sounds great, but it often means you only continue with very strong hands, and you fold too much on the way.

**Where the bands come from (say it honestly).** They are **conventional-wisdom ranges**: norms that online trackers and training material settled on over millions of online hands, then **widened** for live play and small samples, so the app flags less rather than more. They are not solver output, and not measured from Final Table users.

**Status.** Admin-only.

**Do-not-say.** Do not call the bands "GTO" or "solver-approved".

---

### 5.2 Minimum samples: sample honesty

**Plain English.** The Leak Detector refuses to judge on too few hands.

| Spots seen | What the app shows |
|---|---|
| Below the minimum | "Not enough data" plus a progress ring ("4 more spots for a verdict"). Never a verdict. |
| Between minimum and "confirmed" | **Emerging** (an early signal) |
| At or above "confirmed" | **Confirmed** |
| Inside the band | **Healthy** ("Looking solid") |

The "Unlock with more hands" section lists detectors that are close to a verdict. The nearest one is marked **Next**.

**Why it matters.** Players trust it, because it does not shout "LEAK!" after five hands.

**Marketing angle.** "No verdicts on tiny samples. Ever." This is a strong trust message for experienced players.

---

### 5.3 The coaching card

Every leak card answers five questions:

| Block (app label) | Content |
|---|---|
| **What we saw** | The habit, in one sentence. "When the last bet goes in on the river, you release your hand most of the time." |
| **What it costs** | How opponents exploit it. "Anyone who notices can bet any two cards at you and show a profit." |
| **The fix** | What to do. "Before folding a river, ask what worse hands could be betting…" |
| **By position** | The same number split by seat. |
| **Your hands** | Up to 5 example hands from the player's own history, with card faces. |

A gauge shows "You 78% · Healthy 30–62%". An info sheet explains where the band comes from.

---

### 5.4 Slices by board type and by position

**Plain English.** An average can hide a problem. The app also splits detectors by **position** and, for flop / turn / river, by **board type**:
- **Dry** board (cards far apart, different suits, e.g. K♠7♦2♣)
- **Wet** board (connected or two of a suit, e.g. 9♥8♥6♣)
- **Paired** board (two cards of the same rank)
- **Monotone** board (all three of one suit)

If a slice with at least 10 spots is outside the band, it becomes its own finding. Example: "Folding vs flop bets, on paired boards".

---

### 5.5 "Show me the hand"

**Plain English.** Every finding links to the player's **own hands** where the leak happened. Tap a hand to open the full hand replay. If there are two or more, **Review all** lets the player swipe through them, one after another, in a two-minute review.

**Why it matters.** Proof. The player sees the exact moment, not a vague number.

**Marketing angle.** "Not theory. Your hands." This is the most persuasive visual for the feature.

---

### 5.6 The three tabs: Leaks, Ranges, Health

Since 2026-10-13 the screen has three tabs. Each answers one question.

| Tab | Question it answers | What is on it |
|---|---|---|
| **Leaks** (default) | "What do I need to work on?" | "Since your last visit" news line, the main leak ("Fix first" or "Your focus"), other leaks ("Also detected") as short rows that expand, and "Unlock with more hands". |
| **Ranges** | "With which hands?" | Position chips (EP, MP, CO, BTN, SB) and one 13 × 13 "range shape" grid for the selected position (see 5.7). |
| **Health** | "How am I doing overall?" | "Looking solid" (healthy checks), "Fixed leaks" trophies, and "Money by position" (see 5.8). |

Above the tabs: a short line with the number of hands, leaks and solid checks.

---

### 5.7 Range shape (Ranges tab)

**Plain English.** The detectors say **how often**. Range shape says **with which hands**. The app compares the hands the player really opens (raises first) from each position with a standard opening chart (about 100 BB deep).

- **Amber cells**: hands the chart opens, but the player keeps folding (missed opens).
- **Red cells**: hands the chart folds, but the player keeps opening (loose opens).
- Chips list the worst cases: "A5s folded ×3", "Q5o opened ×2".
- Summary: "You open 31% of spots · chart ≈44%".
- A position needs **20 first-in spots** before its grid appears. A cell needs 2+ spots and a clear pattern (67%+ the wrong way) to be marked.
- The big blind is excluded (it never opens first).
- "Open in grid" opens the player's full range grid, filtered.

**The framing is directional, not a verdict.** The app says so on screen.

---

### 5.8 Money by position, in big blinds (Health tab)

**Plain English.** A chart shows how many big blinds the player won or lost from each seat, in total. It also lists the **worst spots** ("Worst spots · total BB lost").

**Rules that keep it honest.**
- Always in **big blinds**, never in chips or cash (blinds change, so chips cannot be compared).
- **Totals**, not per-hand rates (small samples make rates jump around).
- A spot needs at least 6 hands to appear.
- Labelled as **directional only**: "Live samples swing hard. Blinds include forced posts." (Everyone loses money from the blinds, so that alone is not a leak.)

**Marketing angle (later).** "Where do your big blinds go?" A strong visual, but always add "directional".

**Do-not-say.** Do not present the money view as proof of a leak.

---

### 5.9 Focus goal, "since your last visit", fixed-leaks shelf

| Piece | What the player sees |
|---|---|
| **Since your last visit** | One line: "3 changes since your last visit · +46 hands". Expand it to see: a leak unlocked, a leak back to healthy, improving, drifting. |
| **Work on this** (focus goal) | Makes a leak the player's goal. A strip shows "Day 5 · +12 spots · 18% → 24% · 6pt to the band". The focus leak stays at the top even if another leak becomes bigger. |
| **Celebration** | When the focus leak comes back into its band: a check animation and a strong vibration, then it moves to the trophy shelf. |
| **Fixed leaks** | Trophy rows: "18% → 41% · fixed in 23d". |

These are real-data rewards. No fake badges, no login streaks.

---

### 5.10 The session-end leak chip

**Plain English.** After a session ends, one short line can appear under the session summary card: a **leak check** for that session. Examples: "5 of 6 river spots folded, above your usual", "+2 spots toward BB vs steal, 4 more for a verdict", or for a very short session "2 hands analyzed · 1 leak spot banked". Tap it to open the Leak Detector.

The chip is **outside** the shareable image, so coaching never appears on a shared card.

**Status.** Part of the Leak Detector: admin-only.

---

### 5.11 The 2026-10-30 redesign

**What changed (simple words).**
- A clear **verdict header** at the top.
- **One** expandable leak card design for every leak (before, cards had different layouts).
- The detail is grouped into blocks: WHAT WE SAW / WHAT IT COSTS / THE FIX / BY POSITION / YOUR HANDS, with real card faces.
- At most two buttons per card.
- Proper empty and error screens ("No hands to analyze yet", "Couldn't load your report").
- Bigger tap targets (44 px), screen-reader labels, and less motion for users who ask for it.
- All screen labels translated into 11 languages.
- All colours and sizes now come from the app's design system.

**Marketing angle (later).** Screenshots are now clean enough for ads.

---

### 5.12 Hiding drills (2026-11-01)

**Plain English.** Some leak fixes used to say "Practice: Training Drills → 3-bet spots", and some cards had **Drill** / **Practice this spot** / **Practice opens** buttons. Training Drills are **not ready** and are switched off. So the drill hints and buttons now appear **only when Training Drills are on**. Today they are off, so users never see a button to a feature they cannot open.

This change is the reason the Leak Detector can open to everyone in the next release.

**Do-not-say.** Do not mention Training Drills, "practice this spot", or "drill your leak" in any Leak Detector content.

---

### 5.13 Tier and rollout

- **Tier gating:** not decided in the docs. Today the app has a hard paywall, so every user who passes it is a paying or trial user. (Unverified: whether the Leak Detector will be limited to some plans at launch. Ask the founder.)
- **Rollout:** admin-only now → all users after release 2.1.7 (the drill-hiding release). Wait for the founder's confirmation.

---

## 6. Feature 3: Hand Logging

### 6.0 Overview, and why logging live is hard

**Plain English.** Hand logging lets the player record a real poker hand **as it happens**, at a real table: who did what, on which street, for how much, the board cards, their own two cards, and who won. From these records the app builds the player's stats, range grid, charts, leak report and AI reviews.

**Why logging at a live table is hard.**
- **Speed.** A hand lasts about 1–2 minutes. Actions happen fast.
- **Attention.** Every second on the phone is a second not watching opponents.
- **Rules and manners.** Tournament rules (TDA Rule 5-C) say players with live cards may not use a phone. Some casinos ban phones on the table. In practice, players log **between hands**.
- **Poker maths.** Side pots, chopped pots, all-in for less, empty seats, moving blinds, ante formats. Getting this wrong ruins the stats.
- **Memory.** After a big hand, emotions blur the details.

> **Scene.** Ana is at a casino cash table. She wins a big pot on the river. While she stacks chips, the next hand is already dealt. If she logs the full hand now, she misses the next one. If she waits, she forgets the turn bet size.

**What the app does about it.** Fast one-thumb gestures, a card keyboard, a bet-size slider that snaps to common sizes, automatic pot and side-pot maths, a live table picture, and undo. The new **Easy hand logging** (section 7, admin-only) goes further: log less during the hand, finish later.

**Why it matters.** Without logged hands, there are no real stats. Online players have had trackers for 20 years. Live players had a notes app. Final Table gives live players their real numbers.

**Marketing angles.**
- Hooks: "You remember the bad beat. Do you remember the three streets before it?" · "Your real VPIP, from your real hands."
- One-line pitch: **"Track every hand you play, not just your profit at the end of the night."** (this is the brand one-liner)
- Audience: **regular** (primary), **grinder**, **club** (via dealer logging).

**Status.** LIVE for everyone.

**Do-not-say.** Do not say "log hands during the hand without anyone noticing", and do not encourage phone use while holding cards (it breaks casino and tournament rules). Say "between hands" or "after the hand".

---

### 6.1 Full tracking: what gets recorded

- Every action for every player, on all four streets: fold, check, call, bet, raise, all-in.
- Bet sizes and each player's stack at the time of each action.
- Board cards (flop, turn, river), the player's own hole cards, and shown cards at showdown.
- Side pots and chopped pots (several winners), all-in for less.
- 2 to 9 players, empty seats handled, blinds skip empty seats.
- Cash games and tournaments, blind level changes, BB ante.
- Decimal blinds (e.g. $0.25/$0.50).
- **Undo** with full state restore.
- A confirm dialog stops accidental exit in the middle of a hand.
- Every hand saves twice: on the phone and in the cloud. It works offline and syncs later.

**Optional extras:** "Record shown cards" after a hand (for an opponent who showed); star and tag a hand; notes.

**Live scouting mode** (opt-in setting): after the player folds preflop, they can keep logging what opponents do before the flop. (Unverified: this setting is gated behind the Training Drills flag in the code docs. With drills off, check whether scouting is visible before promoting it.)

---

### 6.2 The logging redesign (2026, first half)

The logging screen was rebuilt in steps between February and July 2026.

| Piece | What it does (plain words) |
|---|---|
| **Swipe gestures** (2026-04-23) | One gesture per action. **Tap** = check / call. **Swipe out** = fold. **Swipe up** = raise (opens the size slider). The old "draw a shape" gestures (circle = call, line = fold) were removed. |
| **Card keyboard** | A fast card picker used everywhere cards are entered. Three ways: drag from a rank to a suit; tap a rank then swipe (up ♠, right ♥, down ♦, left ♣); or tap rank then tap suit. Cards already used are blocked. |
| **Raise snap** | When you swipe up to raise, a slider appears with "snap points" at common sizes: multiples like 2.2x, 2.5x, 3x, "Pot", "Min", "All-In". Minimum re-raise maths is correct. If a player can only go all-in, the slider collapses to a single All-In. |
| **Stack range rings** | For opponents, you do not need an exact stack. Press and hold a seat, drag around a ring, pick a range (e.g. "~85bb"). The hero's stack stays exact. Rings lock after preflop to avoid accidental changes. |
| **Seat and table setup** | One unified session setup screen. Tap a seat to add a player, search saved opponents, "This is me" to move the hero, pick the dealer button. "Change table" works in cash and tournaments. |
| **Live table picture** (2026-05-29) | The top of the screen shows a real table: seats, names, stacks, who is to act (amber glow), FOLD / ALL-IN / bet pills, the pot and board in the middle. The dealer button can be dragged between hands. |
| **Blinds pill** | Tap the blinds pill to edit small and big blind side by side. |

**Why it matters.** Logging an action takes one thumb movement. Hands with many actions stay fast.

**Marketing angles.** Speed demo videos: "one swipe per action". Show the card keyboard swipe; it looks like a magic trick.

**Status.** LIVE.

---

### 6.3 The stats it feeds

Logged hands feed:
- **7 core stats**: VPIP, PFR, 3-Bet, Fold to 3-Bet, C-Bet, Steal, Check-Raise (see 2.11), plus win rate and aggression factor. Updated after every hand. Broken down by position.
- **Correct denominators**: a walk (everyone folds to the big blind) does not count as a chance to play. A 3-bet is counted as the second voluntary raise before the flop. All-ins count as raises.
- **Play style** (TAG, LAG, Nit, Calling Station, Maniac, Balanced) after 50 hands. Before that, the home tile shows "N/50".
- **Range grid** (13 × 13) of the hands the player really plays, by position and stack depth.
- **Leak Detector** (admin-only).
- **AI hand analysis** (per hand, on request, subscription quotas).
- **Opponent profiles** (public copy: profiles, notes, style tags only).

**Do-not-say.** Do not advertise opponent statistics tracking (see MARKETING_MASTER guardrails).

---

### 6.4 The session summary card

**Plain English.** When any session ends, the app shows a shareable card: session name, game type, duration, net profit or loss, hands played, biggest pot, best and worst hand. For tournaments: finishing place (e.g. "11th / 28"), prize, and net result. It can be shared as an image.

**Accuracy details.**
- Cash: profit = final stack − total buy-in. Tournament: profit = prize − total buy-in (never chips minus money).
- Tournament "biggest pot" is compared in big blinds, not chips (fixed 2026-08-05: a late 7 BB pot used to beat an early 317 BB pot because chip values grow during a tournament).
- Best / worst hand uses pot size compared with the player's stack, so different blind levels compare fairly.

**Marketing angle.** The viral loop. "Share your night." Encourage players to post their cards.

**Status.** LIVE.

---

### 6.5 The stack chart

**Plain English.** A line chart of the player's stack over the session. Teal when winning, red when losing. Tap a point to see the hand. It is inside Session details during a live session, and there is a full-screen landscape view with average growth, duration and P/L.

**Recent change.** Release 2.1.7 uses one shared chart for all screens. With Easy hand logging (admin-only) the chart can also show **dashed "pending" segments** for flagged hands (section 7.4).

**Status.** LIVE (pending segments: admin-only).

---

### 6.6 Comma decimals and decimal blinds

**Plain English.** Every money, chip or blind field accepts **both a comma and a dot** as the decimal mark. "50,00" and "50.00" both mean fifty.

**The bug behind it (2026-08-14).** A Romanian user typed blinds "25,00 / 50,00". The old field silently deleted the comma. The app read 2500 / 5000. Then it told him "minimum raise is 10000". Now fixed in every money field.

**Decimal blinds (2026-05-30).** Small cash games like $0.25 / $0.50 work.

**Marketing angle.** "European-friendly: comma or dot, your choice." Good for local posts in DE, FR, IT, RO, PL and others.

**Status.** LIVE.

---

### 6.7 Bugs fixed (proof of care)

Useful for "we listen" content. Do not list bugs in ads.

| When | Bug | Fix |
|---|---|---|
| 2026-04-24 | Undo after cancelling the board-card dialog left wrong pot amounts | Undo now fully restores the street and the pot |
| 2026-07-20 | 3-bets were counted one raise too late (counted 4-bets as 3-bets) | Fixed: 3-bet = the second voluntary raise |
| 2026-07-21/22 | Adding a seat before the big blind acted did not move UTG | Blinds and positions recompute |
| 2026-07-21/22 | A player seated mid-hand got the action | They now join next hand |
| 2026-07-21/22 | Changing table mid-hand had no confirmation | Confirm dialog, no silent corrupt save |
| 2026-07-21/22 | Side-pot indicator missing | Appears as soon as a bet exceeds an all-in |
| 2026-07-21/22 | All-in for less than the call showed as a limp | Labelled ALL-IN everywhere |
| 2026-07-21/22 | A short stack was offered raises it could not afford | Only All-In shown; numpad locks |
| 2026-08-05 | Play style showed "762/50" instead of a style | The detector always gives a style after 50 hands |
| 2026-08-05 | Tournament biggest pot compared chips across levels | Compared in big blinds |
| 2026-08-14 | Comma in money fields deleted (see 6.6) | Fixed in every field |
| 2026-08-28 | Crash when a short stack bet less than the minimum bet | Treated as all-in for less |
| Audit | Duplicate hand on save retry; busted-player dialog could be skipped | Save is now safe to retry; dialog waits for a choice |
| Known open | Undo of "call, then raise" in one round | Still open (deferred) |

---

### 6.8 Hand Details redesign (2026-10-30, release 2.1.7)

**Plain English.** The screen that shows a past hand was redesigned: bigger, readable text, a summary card at the top, all hand tools (share, AI analysis, etc.) in one strip, street pots aligned on the right, and street names translated. The big blind / money view choice is remembered between hands.

Also in 2.1.7: if AI hand analysis fails on the server, the app now shows a clear message instead of an empty result, and does not use up the player's analysis quota.

**Status.** In release 2.1.7. (Unverified: whether 2.1.7 is already live in the store.)

**Store text (English, from the release notes):** "Redesigned hand details: clearer text, a new summary card and all hand tools in one strip."

---

## 7. Feature 3b: Easy Hand Logging (admin-only)

> **STATUS: ADMIN-ONLY. NOT PUBLIC YET.** Internal flag `easy_hand_logging`. With the flag off, users get the normal logging flow, unchanged. Merged into the app on 2026-11-01. **Do not promote.** The extra "live insights" are behind a second admin-only flag, `live_insights`.

### 7.0 Overview

**Plain English.** Easy hand logging is a lighter way to log at a real table. The idea: **capture almost nothing during the hand, and add the detail later**. Folds take one tap. Interesting hands can be "flagged" with just your two cards and finished later, at a break or after the session. Stats stay correct.

**The problem (research, 2026-10-30).**
- Players do not log hands back to back in live sessions, because logging pulls their attention from the game.
- The player folds before the flop in **70–85% of hands**. Before, a folded hand either had to be logged at the table or was thrown away behind a confirm. That lost data.
- A full hand took an estimated 45–60 seconds and about 30 taps, with several pop-up windows.
- Tournament rules say no phone use with live cards. So "log between hands" is the only fair design.

> **Scene.** Jon plays a 6-hour tournament. Folds, folds, folds. Then a huge all-in hand at 21:10. He cannot log it now; the next hand is dealt. With Easy logging, he taps **Flag**, picks his two cards, and plays on. At the dinner break he finishes the hand from his session screen in two minutes.

### 7.1 Fold tick with a 4-second undo

**What the user sees.** When the player folded preflop and nothing else needs logging, tapping **Next hand** counts the hand as a fold at once. A toast says "Hand counted. Next hand ready." with an **Undo** button for **4 seconds**. No pop-up, no long animation. The pause between hands is shortened (about 0.8 s instead of 2.5 s).

**Why it matters.** The most common hand (a fold) costs one tap. Folded hands still count in the stats where they should (a fold tick adds +1 to total hands, which keeps VPIP and PFR honest).

### 7.2 Flag a hand, finish it later (recall)

**What the user sees.**
1. During or right after an interesting hand, the player taps **Flag**.
2. A sheet "Flag this hand" opens. The two hole cards are **required** ("Pick your two cards to save this hand"). Up to **3 optional tags**: Cooler, Bluff, Hero call, Big pot, Mistake, Review, Played. The app also stores a snapshot of the table (seats, stacks, positions).
3. A message confirms: "Flagged. Finish it later."
4. Later, from **Session details** (flagged hands list) or by tapping the pending point on the **stack chart**, the player taps **Finish**.
5. A **recall mode** opens the normal gesture logger with a banner: "Recall: finishing flagged hand #12". The table is set up as it was.
6. While the finished hand saves, the screen shows **"Saving hand…"**, then "Hand saved".
7. A recalled hand gets a **"Reconstructed"** badge in hand history.
8. Leaving recall mode keeps the hand flagged. Deleting a flag removes it and does not change stats.
9. If flags are still open at a rebuy, the app asks "Your stack before the rebuy" so the stack chart stays correct.

### 7.3 Hand completeness levels, and "stats only once"

**Plain English.** Each hand now has a level that says how complete it is. The app only uses a hand for what its data supports.

| Level (internal name) | Meaning | Counts in |
|---|---|---|
| Fold tick (`fold_tick`) | Hero folded preflop; one tap | Total hands only |
| Preflop (`preflop`) | Only the preflop actions | Preflop stats (VPIP, PFR, 3-bet, steal…) |
| Flagged (`flagged`) | A stub: cards, tags, table snapshot | **Nothing yet** |
| Reconstructed (`reconstructed`) | A flagged hand finished later | Stats (marked "Reconstructed") |
| Full (`full`) | Logged live, the normal way | Everything |

**Key rule:** a flagged hand's stats are applied **exactly once**, at the moment it is finished ("promoted"). A second save cannot count it twice. Only **full** hands feed the Leak Detector, AI analysis, exports, and the summary card's best/worst hand.

**Why it matters.** Easy does not mean sloppy. The numbers stay right.

### 7.4 Stack timeline: pending segments

**Plain English.** If a player flagged hands but has not finished them, the app does not know the exact stack in between. The stack chart now draws those parts as **dashed "pending" segments** ("2 hands pending"; "Unlogged +40"). Tap one: "Hand #12 pending. Tap to finish." Known stack values (start, manual updates, rebuys, final) stay solid "anchors".

### 7.5 Smaller helpers (all inside Easy logging)

| Helper | What it does |
|---|---|
| **Board "Add later"** | The board-card picker can be skipped. A bar says "Board not entered. Add it later." |
| **Winner preselect** | When only one player is left, that player is already selected as the winner. |
| **Learned bet sizes** | The raise slider highlights "Your usual" size and offers "Same as last". |
| **Flag step in the in-app tour** | When the flag is on, the guided first hand shows a Flag chip and a "Flag a hand" tip: "No time to log a hand? Tap Flag and enter your two cards. Finish it later from Session details (flagged hands) or the stack chart." The tour is unchanged when the flag is off. |

### 7.6 Live insights (second admin-only flag: `live_insights`)

**Plain English.** Small facts during the session, as a reward for logging:
- A line about an opponent when they act again, e.g. "Seat 4: folded to 3/3 c-bets tonight", "Seat 2: played 9 of 20 hands tonight".
- One line after a logged hand, e.g. "That is open number 6 from CO tonight.", "Biggest pot of the night.", "7 hands in a row without a flop."

**Status.** Admin-only. Do not promote. Note: these are tonight-only counts about opponents. Even later, public copy must follow the guardrail "no opponent stat tracking claims".

### 7.7 What was REMOVED, and why simplicity won

During the design of Easy logging, more ideas were built or tried, then **taken out** before the merge. They are not in the app. **Never mention them.**

| Removed | What it was |
|---|---|
| **Pocket mode** | A black screen with 3–4 big tap / swipe zones, to log without looking at the phone. |
| **"Type a hand" shorthand** | Type a hand as short text (e.g. "BTN 2.5, I 3b AKo…") and the app turns it into a full hand. |
| **"What's new" tour** | A tour that showed returning users the new logging features. |

**Why simplicity won (from the founder's brief).** Every extra mode is one more thing to learn at a busy table. The team kept one clear path: tap to fold, flag to save for later, finish with the same logger the player already knows. Fewer modes, fewer mistakes, less explaining. (The repository holds no written record of these removals. Details beyond this summary are unverified.)

Also not in the live UI: some prompts that exist as unused texts in the code (a "stack checkpoint", a "You won about X BB. Flag or log it?" prompt, a "Fold to seat X" button, an "Add your cards" chip at hand start, a "folds tonight" counter). **Do not promote these.** They are not visible to users.

### 7.8 Marketing angles (for later, when it opens)

- Hooks: "Fold in one tap." · "Flag it now. Log it later." · "Built for the table rules: log between hands, not during them."
- One-line pitch: **"Log the hands that matter, in seconds, and finish them at the break."**
- Audience: **tournament players** (breaks), **casino cash regulars** (many folds), **busy beginners**.

**Status summary.** Admin-only. Not public.

---

## 8. Pricing, plans and the free trial

| Plan | Monthly | Yearly | Main limits |
|---|---|---|---|
| **Free** | $0 | $0 | 10 hands per session, 5 opponents, 30-day history, no Daily Challenge replays |
| **Pro** | **$19.99** | **$159.99** | 50 hands per session, 30 opponents, 90-day history, monthly AI analyses + exports, **Daily Challenge replays: last 15 days** |
| **Elite** | **$24.99** | **$189.99** | Unlimited hands, opponents, history; full AI access; **unlimited replays** |
| **Club** | **$59.99** | **$449.99** | Everything in Elite + create and run a club; the owner pays, members, dealers and players use the app free |

**The hard paywall and the trial.**
- The `hard_paywall` flag is **on**. New users go through sign-up and onboarding (including the Daily Challenge demo), then they must choose a plan to continue.
- There is a **free trial** through the app stores: **7 days** on monthly plans. (The docs say yearly plans were set up with **1 month**. Unverified; the app always reads the trial length from the store, so check the store before quoting a yearly trial.)
- Before the purchase, a screen "How Does the Free Trial Work?" explains the timeline (Today → reminder → charge day), how to cancel, and "No payment today". The app sends its own reminder before the trial ends.
- A card is needed. The trial auto-renews into a paid plan unless cancelled.
- In the paywall, the user can still Restore purchases, Sign out or Delete account.

**What this means for marketing.**
- You may say "start with a free trial" or "7-day free trial on monthly plans", **only** together with "auto-renews; cancel anytime in your store account".
- Do not say "free forever", "free plan" or "no card needed". With the hard paywall on, a user needs a paid plan or a trial to use the app. (The Free tier still exists in the code. Unverified: whether any user group, such as older free users, still uses it. A 30-day grace month for older users was planned but is not built.)
- The Daily Challenge is in every paid plan. Replays differ by plan.
- Club members of a paying club: planned to pass the paywall. Unverified; not built in the gate code yet.

---

## 9. Audiences

| Audience | Who they are | Lead with |
|---|---|---|
| **Beginner** | Plays for fun, learning the basics, maybe a home game | Daily Challenge with Nova, coach tone for beginners, onboarding demo |
| **Regular (serious rec player)** | Plays live weekly, knows VPIP exists, never saw their own | Hand logging + stats + play style; Daily Challenge streak; later the Leak Detector |
| **Grinder** | Plays a lot, cash or tournaments, studies with solvers | Solver hands, pot-weighted accuracy, leaderboard, replays (Elite), tournament stats |
| **Club / home-game host** | Runs a game or club | Club tier (one subscription, everyone free), dealer voice logging, live rankings; Daily Challenge as a club ritual |

---

## 10. Timeline: what shipped when

Dates are from git commits and diary entries. "Shipped" means merged into the main code. A store release can come later.

| Date | What | Feature |
|---|---|---|
| 2026-02-02 | Hand logging screen redesign plan starts (new design system) | Hand logging |
| 2026-03-25 | Leave-hand confirm dialog; preflop raise gesture fix; river winner dialog fix | Hand logging |
| 2026-04-23 | Swipe gestures become the only gesture mode; card keyboard everywhere; raise snap improvements; table management | Hand logging |
| 2026-04-24 | Undo after board-dialog cancel fixed | Hand logging |
| 2026-04-26 | Stack chart in Session details + full-screen chart | Hand logging |
| 2026-05-29 | Live table picture on the logging screen | Hand logging |
| 2026-05-30 | Decimal blinds ($0.25/$0.50) | Hand logging |
| 2026-07-20 | 3-bet counting fixed (second voluntary raise) | Stats |
| 2026-07-21/22 | Hand-logging bug batch HL-1 to HL-8b | Hand logging |
| **2026-07-24** | **Launch: v2.1.0+14 submitted to Google Play** | App |
| 2026-08-05 | Play style "762/50" fix; tournament biggest pot in BB; Billing 8 | Stats / summary card |
| 2026-08-14 | Comma decimal fix (v2.1.1+15) | Hand logging |
| 2026-08-28 | Short-stack bet crash fix | Hand logging |
| 2026-09-02 / 09-05 | **Leak Detector** built (8 detectors, coach report, money view), behind admin-only flag (v2.1.3+17) | Leak Detector |
| 2026-10-07 | Range grid shows all-in separately | Stats |
| 2026-10-12 / 13 | Leak Detector: session-end chip, focus goal, fixed shelf, range shape, Leaks/Ranges/Health tabs | Leak Detector |
| **2026-10-14** | **Daily Challenge v1** (random preflop, 5 decisions); coaches Duke / Prof. Vega / Nova (Rocket retired same day); neural voices; 3D mascots; Show range; coach level by experience | Daily Challenge |
| 2026-10-15 | Sound effects + global leaderboard (v2.1.4+18) | Daily Challenge |
| 2026-10-16 / 17 | Engagement notifications: coach-voiced streak saver + send-time scheduler (v2.1.5+19) | Daily Challenge |
| 2026-10-21 | **Real solver hands** (street by street, pot-weighted accuracy); two send windows for pushes; Daily Challenge translated to 11 languages. Voice quota runs out. | Daily Challenge |
| 2026-10-22 | Hard paywall + free trial + onboarding demo hand | App / Daily Challenge |
| 2026-10-25 | **Replays of past days** (Pro 15 days, Elite/Club unlimited); "How the free trial works" screen; "Your daily poker workout" step; username always asked (v2.1.5+20) | Daily Challenge |
| 2026-10-26 | Grading, coach text and position-label fixes | Daily Challenge |
| 2026-10-28 | **AI coach feedback**, pre-generated from solver facts, per decision and level | Daily Challenge |
| 2026-10-29 | **Hardening** (leaderboard, time zones, cross-device streaks, offline block); redesigned onboarding teaser; coach text punctuation | Daily Challenge |
| 2026-10-30 | **Leak Detector redesign**; Hand Details redesign; AI analysis failure message; super-admin preview; home card midnight switch; flags load right after sign-in | Leak Detector / Hand logging / DC |
| **2026-11-01** | **Easy hand logging** (admin-only); Leak Detector hides drill buttons; v2.1.7+22 | Hand logging / Leak Detector |
| 2026-11-02 | v2.1.7+23 build | App |
| ~2026-11-13 | Expected: coach voice quota resets (voice returns) | Daily Challenge |
| Soon (not dated) | Leak Detector opens to all users, after 2.1.7 | Leak Detector |

---

## 11. Glossary

Public word first. Internal word in brackets, when different. Do not use the internal word in public copy.

| Term | Meaning |
|---|---|
| **3-Bet** | A re-raise over someone's first raise before the flop. |
| **Admin-only** | (internal `admin_only`) Only the founder's test account sees it. Not public. |
| **AF (Aggression Factor)** | How much a player bets/raises compared with calling. |
| **All-in** | Betting all your chips. |
| **Ante / BB ante** | An extra small forced bet, usually in tournaments. |
| **Authored hand / solver hand** | (internal "authored tree") A Daily Challenge hand prepared by the team from solver data. Public: "real solver hand". |
| **Band (healthy band)** | The healthy range for a habit in the Leak Detector, e.g. 30–62%. |
| **BB (big blind)** | The bigger forced bet. Also the unit for measuring stacks and pots. |
| **Best move / Good / Leak** | The three Daily Challenge verdicts (green / yellow / red). |
| **Board** | The shared cards in the middle. |
| **BTN (button)** | The dealer seat; acts last after the flop. |
| **C-Bet** | Continuation bet: the preflop raiser bets again on the flop. |
| **Cash game** | Poker for real money chips; leave any time. |
| **Check-Raise** | Check, then raise after the opponent bets. |
| **Coach** | Duke, Prof. Vega or Nova. Original characters. |
| **Completeness level** | (internal) How complete a logged hand is: fold tick, preflop, flagged, reconstructed, full. |
| **Confirmed / Emerging** | Leak Detector verdict strength: enough spots for a strong verdict / an early signal. |
| **CO (cutoff)** | The seat right of the button. |
| **Fixed leaks shelf** | Trophy list of leaks the player brought back into the healthy band. |
| **Flag a hand** | Easy logging: save the hand's cards now, finish it later. Admin-only. |
| **Flag (feature flag)** | (internal) A remote on/off switch for a feature. Never say this word to the public. |
| **Flop / Turn / River** | Flop = the first 3 shared cards. Turn = the 4th shared card. River = the 5th and last shared card. |
| **Fold** | Give up the hand. |
| **Fold tick** | Easy logging: one tap counts a preflop fold, with a 4-second undo. Admin-only. |
| **GTO (Game Theory Optimal)** | The mathematically strongest strategy, as computed by a solver. |
| **Hand** | One round of poker. |
| **Hard paywall** | Users must pick a plan (or start a trial) to use the app. |
| **Hole cards** | A player's two private cards. |
| **ITM** | "In the money": finishing high enough in a tournament to win a prize. |
| **Leak** | A repeated habit that loses money over time. |
| **Leaderboard** | Global ranking: current streak, today, best streak. Automatic. |
| **Limp** | Just calling the big blind before the flop instead of raising. |
| **MTT** | Multi-table tournament. |
| **Perfect day** | Every Daily Challenge decision was a best move. |
| **Position** | Your seat relative to the button (UTG, LJ, HJ, CO, BTN, SB, BB). |
| **Pot-weighted accuracy** | The Daily Challenge score: big-pot decisions count more. |
| **PFR** | Pre-flop raise percentage. |
| **Range** | The set of hands a player plays a certain way. |
| **Range grid** | 13 × 13 chart of all 169 starting hands. |
| **Range shape** | Leak Detector: your opens vs a standard opening chart, cell by cell. |
| **Recall mode** | Easy logging: finishing a flagged hand later in the normal logger. Admin-only. |
| **Reconstructed** | Badge for a flagged hand that was finished later. |
| **Replay** | Playing a past Daily Challenge day for practice. Unranked. |
| **RNG** | Random number generator. The first Daily Challenge version used random preflop spots. |
| **ROI** | Return on investment. |
| **Showdown** | Players show cards at the end; best hand wins. |
| **Solver** | A computer program that calculates GTO poker play. Never name the brand. |
| **Spot** | One decision situation. |
| **Stack** | The chips a player has. |
| **Steal** | A raise from a late seat to win the blinds. |
| **Streak** | Consecutive days of playing the Daily Challenge. |
| **Street** | One betting round (preflop, flop, turn, river). |
| **TAG / LAG / Nit / Calling Station / Maniac / Balanced** | Play-style labels (see 2.12). |
| **Training Drills** | Preflop chart practice. **Hidden** today. |
| **UTG** | Under the Gun: first to act before the flop. |
| **Variance** | Short-term luck. |
| **VPIP** | How often a player chooses to put money in before the flop. |
| **Walk** | Everyone folds to the big blind, who wins without acting. |

---

## 12. Conflicts and unverified facts

These points disagree between sources, or are not confirmed. **The agent must not use them in public copy until the founder decides.** The founder should resolve them and then update MARKETING_MASTER.md (this file does not change it).

### Conflicts

| # | Topic | Source A | Source B | Rule until resolved |
|---|---|---|---|---|
| C1 | **Free trial** | MARKETING_MASTER (2026-09-01) and the one-pager ban all free-trial claims. | Hard paywall with store trials is ON (flag `hard_paywall` = on; trial built 2026-10-22). | Trial claims are true now, but always with "auto-renews, cancel anytime". Ask the founder to update MARKETING_MASTER. |
| C2 | **Training Drills** | MARKETING_MASTER and one-pager promote "GTO training drills". | Flag `training_drills` = off. Leak Detector hides drill buttons. | Do not promote drills. |
| C3 | **Daily Challenge status** | Several docs (daily-challenge.md, CLAUDE.md, diary 2026-10-28) say "admin-only". | Prod flag `daily_challenge` = on (given by the founder, 2026-11-02). | Treat as LIVE. |
| C4 | **Leaderboard server rules deployed?** | CLAUDE.md and ROADMAP say the scoring function and rules for solver days are "not deployed". | Diary 2026-10-26 says they were "verified live". The 2026-10-29 hardening rules are marked "not deployed". | Say only "the server checks every score". No "cheat-proof" claims. |
| C5 | **Prof. Vega's gender** | daily-challenge.md says "she is blunt and technical". | Vega's voice was recast to a male British voice ("warm British storyteller"). | Use no pronouns for Vega. |
| C6 | **Hands per day** | Many docs say "5 hands/day". | Some days have 4 hands (2026-10-24, 2026-10-26); the bundled fallback rotation has 4 hands. | Say "up to 5". |
| C7 | **Coach count / names** | Early docs list "Rocket". | Rocket was retired 2026-10-14 for Nova. | Only Duke, Prof. Vega, Nova. |
| C8 | **iOS availability** | MARKETING_MASTER: Android only. | `release-plan/ios-release-notes-2.1.7.txt` exists (store text in 11 languages). | Do not claim iOS until confirmed. |
| C9 | **Live scouting** | MARKETING_MASTER promotes it as a feature. | CLAUDE.md says the scouting setting is gated behind the `training_drills` flag, which is off. | Check before promoting scouting. |

### Unverified

| # | Fact | Why unverified |
|---|---|---|
| U1 | Yearly plan trial = 1 month | From docs; the app reads the length from the store. Check the store. |
| U2 | Release 2.1.7 is live in the stores | Build 2.1.7+23 was made 2026-11-02. Store status not confirmed. |
| U3 | Leak Detector tier gating at launch | Not decided in the docs. |
| U4 | Leak Detector coaching text translated | Screen labels are in 11 languages; the long coaching texts in the code are English. |
| U5 | Free tier still reachable by any user | With `hard_paywall` on, access requires a paid plan or trial (or an admin partner grant). Grace month and club-member bypass are planned, not built. |
| U6 | Removed items (pocket mode, "Type a hand", "What's new" tour) | Stated by the founder. No written record in the repository. |
| U7 | Random preflop days still appear for some users | Since 2026-10-29 unscheduled days use a rotation of solver hands; edge cases unknown. |
| U8 | iOS push notifications show the coach image | Docs say iOS shows text only until an extra app extension is added. |

---

## 13. Global do-not-say list

1. Do not promote anything that is admin-only, hidden or removed (section 1).
2. Do not name the solver vendor or data source. Say "solver".
3. Do not say the coaches are real people, real pros, or based on anyone.
4. Do not mention Rocket.
5. Do not promise the coach voice until it is back (about 2026-11-13).
6. Do not say leaderboard participation is optional. It is automatic.
7. Do not say replays save or repair streaks.
8. Do not promise streak freezes.
9. Do not say "live AI coach", "chat with your coach", or "ask anything".
10. Do not post today's Daily Challenge hands (spoilers).
11. Do not call the Leak Detector bands "GTO" or "solver".
12. Do not mention Training Drills.
13. Do not promise profit or a win-rate increase.
14. Do not encourage phone use while holding cards at a table.
15. Do not claim opponent statistics tracking (profiles, notes and style tags only).
16. Do not say "free forever", "free plan" or "no card needed".
17. Do not claim iOS availability until confirmed.
18. Do not use internal words: flag, admin_only, Firestore, tree JSON, node, stub, promotion, CF.
19. Do not publish usernames from the leaderboard without permission.
20. Do not say the coach speaks languages other than English.

---

## 14. Facts block (machine-readable)

```yaml
# Final Table — Features Deep Dive facts block
# Status date: 2026-11-02. Quote values exactly. If a value is "unverified", do not use it publicly.
meta:
  app_name: "Final Table"
  website: "finaltable.io"
  status_date: "2026-11-02"
  current_build: "2.1.7+23"
  launch: { platform: "Google Play", version: "2.1.0+14", date: "2026-07-24" }
  ios_available: "unverified"
  rule_when_unsure: "say not yet public"

feature_flags_prod:
  daily_challenge: "on"
  ai_hand_analysis: "on"
  engagement_notifications: "on"
  hard_paywall: "on"
  leak_detector: "admin_only"   # opens to all users after the release that hides drills (2.1.7)
  training_drills: "off"
  easy_hand_logging: "admin_only"
  live_insights: "admin_only"

status_words: ["LIVE for everyone", "admin-only (not public yet)", "hidden", "removed"]

plans:
  trial:
    monthly_plans_days: 7
    annual_plans: "1 month (unverified; read from store)"
    auto_renews: true
    card_required: true
  free:  { price_monthly: 0,     price_yearly: 0,      hands_per_session: 10,  opponents: 5,   history_days: 30,  dc_replay_days: 0 }
  pro:   { price_monthly: 19.99, price_yearly: 159.99, hands_per_session: 50,  opponents: 30,  history_days: 90,  dc_replay_days: 15 }
  elite: { price_monthly: 24.99, price_yearly: 189.99, hands_per_session: "unlimited", opponents: "unlimited", history_days: "unlimited", dc_replay_days: "unlimited" }
  club:  { price_monthly: 59.99, price_yearly: 449.99, includes: "everything in Elite + create and run a club; members, dealers and players use the app free", dc_replay_days: "unlimited" }
  currency: "USD"
  disclosure: "Subscriptions auto-renew; cancel anytime in the store account."

daily_challenge:
  status: "LIVE for everyone"
  first_day: "2026-10-14"          # "Daily #1"
  hands_per_day: "up to 5"         # some days have 4
  max_hands_per_day: 5
  decisions_per_hand: "1 to 10 (varies with the line taken)"
  same_hands_for_everyone_each_day: true
  history:
    v1: { date: "2026-10-14", type: "random (RNG) preflop decisions", decisions_per_day: 5, score: "0..5" }
    v2: { date: "2026-10-21", type: "real solver hands, street by street, branching" }
  grading_bands:
    best_move: "solver frequency >= 0.65"
    good: "solver frequency >= 0.15 and < 0.65"
    leak: "solver frequency < 0.15"
    range_softening: "LEAK becomes GOOD if the whole range takes the action >= 0.25 and it is not fold"
  verdict_values: { best: 1.0, good: 0.5, leak: 0.0 }
  scoring:
    decision_weight: "pot size in BB at the decision, minimum 1"
    hand_accuracy: "pot-weighted mean of decision values"
    day_score: "plain mean of hand accuracies x 100 (0-100%)"
    perfect_day: "every decision is BEST"
    server_recomputes_score: true
  coaches:
    - { name: "Duke", id: "grinder", tagline: "Old-school Vegas grinder", look: "cowboy hat, mustache, amber", voice: "older American man" }
    - { name: "Prof. Vega", id: "professor", tagline: "Dry GTO theorist", look: "round glasses, teal", voice: "warm British storyteller", pronouns: "unverified - do not use" }
    - { name: "Nova", id: "nova", tagline: "High-energy hype coach", look: "coral-pink ponytail, headset, gold star face paint", voice: "young energetic woman" }
    original_characters: true
    retired: ["Rocket (replaced by Nova on 2026-10-14)"]
  coach_voice:
    type: "neural text-to-speech, no robot fallback"
    status: "silent for new lines; provider quota exhausted 2026-10-21"
    expected_return: "around 2026-11-13"
  coach_levels: ["beginner", "intermediate", "advanced"]
  coach_level_source: "onboarding answer until 150 logged hands, then real play style"
  coach_line_language: "English"
  ai_feedback:
    generated: "ahead of time, in batch, from solver facts"
    variants_per_line: 2
    llm_calls_during_play: 0
  show_range: { grid: "13x13", colors: { raise: "orange", allin: "purple", call: "green", check: "teal", fold: "blue" } }
  streaks:
    rule: "alive if yesterday was played and today is open; a missed day resets it"
    one_ranked_attempt_per_day: true
    abandoned_run_records_nothing: true
    streak_freeze: false
    cross_device_merge: true
  leaderboard:
    boards: ["current streak", "today", "best streak (all-time)"]
    today_tiebreak: "faster completion time"
    shows: "top 100 + your rank"
    participation: "automatic (no opt-in, no opt-out, no anonymous mode)"
    name_shown: "username; skip -> display name; last resort 'Player' + 4 digits"
  share:
    format: "Final Table Daily #N · XX.X% / one emoji row per hand / 🔥N day streak"
    emoji: { best: "🟢", good: "🟡", leak: "🔴" }
    spoiler_safe: true
  replays:
    free: "none"
    pro_days: 15
    elite_club: "unlimited (back to 2026-10-14)"
    ranked: false
    affects_streak_or_leaderboard: false
    shipped: "2026-10-25"
  sound_effects: { per_verdict: true, completion_fanfare: true, default: "on", separate_from_voice_mute: true, shipped: "2026-10-15" }
  haptics: { best: "medium", good: "light", leak: "strong" }
  notifications:
    status: "LIVE"
    streak_saver_local_time: "19:00"
    server_windows: ["morning 10:00 local", "evening: 1 hour before the user's usual active hour"]
    types: ["streak risk", "today's challenge ready", "milestone", "re-engage (always neutral)"]
    quiet_hours_default: "22:00-08:00 (streak saver exempt)"
    holdout_group: "about 10% (internal, do not mention)"
  onboarding:
    demo_hand: "today's first hand, before the paywall, skippable, result not saved"
    info_step: "Your daily poker workout"
  admin_only_tools: ["super-admin preview of future days (45-day horizon)", "day shift tester", "coach level tester", "reset today"]

leak_detector:
  status: "admin-only (not public yet)"
  opens_to_all: "after release 2.1.7 (drill hiding); wait for founder confirmation"
  entry_points: ["Menu screen", "session-end leak chip (also admin-only)"]
  tabs: ["Leaks", "Ranges", "Health"]
  detectors:
    - { title: "Folding vs river bets",            band: "30-62%", min_spots: 12, confirmed_spots: 30 }
    - { title: "Folding vs turn bets",             band: "25-58%", min_spots: 15, confirmed_spots: 35 }
    - { title: "Folding vs flop bets",             band: "25-55%", min_spots: 20, confirmed_spots: 45 }
    - { title: "Folding to 3-bets after opening",  band: "35-68%", min_spots: 10, confirmed_spots: 25 }
    - { title: "BB folds vs steals",               band: "40-72%", min_spots: 12, confirmed_spots: 30 }
    - { title: "Open-limping",                     band: "0-12%",  min_spots: 40, confirmed_spots: 80 }
    - { title: "Going to showdown",                band: "20-34%", min_spots: 30, confirmed_spots: 60 }
    - { title: "Winning at showdown",              band: "46-62%", min_spots: 15, confirmed_spots: 35 }
  band_origin: "conventional-wisdom population norms, widened for live play; NOT solver output"
  verdicts: ["not enough data", "emerging", "confirmed", "healthy"]
  slice_min_spots_for_verdict: 10
  slices: ["position", "board texture: dry, wet, paired, monotone"]
  example_hands_per_leak: 5
  range_shape: { baseline: "opening charts, about 100BB", min_first_in_spots_per_position: 20, positions: ["EP","MP","CO","BTN","SB"], bb_excluded: true }
  money_view: { unit: "big blinds", type: "totals, directional only", min_hands_per_spot: 6 }
  excluded_hands: ["walks", "scouted hands", "tutorial sessions", "quick sessions", "non-full (easy logging) hands"]
  redesign_date: "2026-10-30"
  drills_hidden_date: "2026-11-01"
  tier_gating: "unverified / undecided"

hand_logging:
  status: "LIVE for everyone"
  actions: ["fold", "check", "call", "bet", "raise", "all-in"]
  streets: ["preflop", "flop", "turn", "river"]
  seats: "2 to 9"
  gestures: { tap: "check/call", swipe_out: "fold", swipe_up: "raise (size slider)" }
  card_keyboard_swipe: { up: "♠", right: "♥", down: "♦", left: "♣" }
  raise_snap_points: ["Min", "2.2x", "2.5x", "3x", "Pot", "All-In"]
  stats: ["VPIP", "PFR", "3-Bet", "Fold to 3-Bet", "C-Bet", "Steal", "Check-Raise", "Win rate", "AF"]
  vpip_pfr_denominator: "total hands minus walks"
  three_bet_definition: "second voluntary raise preflop"
  play_style_min_hands: 50
  play_styles: ["TAG", "LAG", "Nit", "Calling Station", "Maniac", "Balanced"]
  decimals: "comma or dot accepted in all money/chip/blind inputs"
  decimal_blinds_example: "$0.25/$0.50"
  session_summary_card: ["session name", "game type", "duration", "net P/L", "hands played", "biggest pot", "best/worst hand", "tournament: place, field size, prize"]
  tournament_biggest_pot: "compared in big blinds"
  offline: "saves locally, syncs later"
  live_hands_per_hour_estimate: 30
  languages: 11

easy_hand_logging:
  status: "admin-only (not public yet)"
  merged: "2026-11-01"
  fold_tick_undo_seconds: 4
  settle_pause_seconds: { easy: 0.8, classic: 2.5 }
  flag:
    required: "hero's two hole cards"
    optional_tags_max: 3
    tags: ["Cooler", "Bluff", "Hero call", "Big pot", "Mistake", "Review", "Played"]
    finish_from: ["Session details (flagged hands)", "stack chart pending point"]
    saving_state_text: "Saving hand…"
    finished_badge: "Reconstructed"
  completeness_levels: ["fold_tick", "preflop", "flagged", "reconstructed", "full"]
  stats_applied: "exactly once, at promotion"
  only_full_hands_feed: ["Leak Detector", "AI analysis", "exports", "summary best/worst hand"]
  stack_chart: "dashed pending segments for open flags; solid anchors for known stacks"
  helpers: ["board Add later", "winner preselect", "learned sizes: Your usual / Same as last", "flag step in in-app tour (flag on only)"]
  live_insights: { flag: "live_insights", status: "admin-only" }
  removed: ["pocket mode", "Type a hand shorthand", "What's new tour"]
  not_in_ui: ["stack checkpoint prompt", "won/lost about X BB prompt", "Fold to seat X", "Add your cards chip", "folds tonight counter"]

training_drills:
  status: "hidden"
  flag: "training_drills = off"

guardrails:
  - "Never promote admin-only, hidden or removed features."
  - "Never name the solver vendor."
  - "Coaches are original characters, never real players."
  - "Leaderboard participation is automatic."
  - "Coach voice may be silent until about 2026-11-13."
  - "Drills are hidden."
  - "No profit promises."
  - "No opponent-stat-tracking claims."
  - "Trial claims only with auto-renew disclosure."
  - "iOS availability unverified."
```
