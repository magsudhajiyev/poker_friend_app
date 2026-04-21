# AI Hand Analyzer — Accuracy & Quality Improvements

**Date**: 2026-04-21
**Status**: Resolved

## Summary

Multiple rounds of debugging and prompt engineering to improve the per-hand AI analysis quality. Session analysis was removed entirely due to inconsistent results.

---

## Issues Fixed

### 1. Session Analysis Removed
**Problem**: Session-level analysis gave inconsistent results vs individual hand analysis — wrong gameType, missing opponent context, AI hallucinations (e.g., reading Q8 as "QQ88 two pair", calling 92o fold "conservative").
**Fix**: Deleted entire session analysis flow:
- Backend: `session_analyzer.py`, `analytics.py` route, `COACHING_REVIEW_PROMPT` from rubric
- Flutter: `session_analysis_report_screen.dart`, `session_analytics_service.dart`, AI Report button from session analytics screen
- Kept only per-hand AI analysis

### 2. Player Misattribution
**Problem**: AI attributed Player 1's 4-bet to a different player (Nicolson) because action lines didn't include position labels.
**Fix**: Added position labels to action lines in `_format_actions_by_street()`:
```
Nicolson (UTG+2): raise 160  →  instead of  →  Nicolson: raise 160
```

### 3. GameType Bug (Tournament → Cash)
**Problem**: `isCashGame` field defaulted to `true` when missing, causing tournament hands to be analyzed as cash games.
**Fix**: Added `gameType` field fallback in `ai_analyzer_service.dart`:
```dart
final isCashGame = hand['isCashGame'] as bool?
    ?? (gameTypeField != 'tournament' && gameTypeField != 'mtt' && gameTypeField != 'sng');
```

### 4. All-In Detection
**Problem**: All-in actions logged as "raise"/"call", so AI suggested re-raising when hero was already all-in.
**Fix**: Detect all-in when `amount >= playerStack` in `_format_actions_by_street()`. Added system prompt rule: don't grade streets after hero goes all-in.

### 5. Effective Stack Calculation (Short-Stack Bug)
**Problem**: `effective_stack_bb` used the shortest stack at the entire table (including players who folded preflop). A 1550-chip villain who folded made a 116BB hero hand classified as `mtt_short` (15-25BB).
**Fix**: Changed `_find_villain_stacks()` → `_find_active_villain_stacks()` — only considers villains who didn't fold preflop.

### 6. Double BB Division in Pot Calculation
**Problem**: `_compute_street_pots()` divided amounts by BB when storing in `street_bets`, then divided by BB again in `pots[street]`. SPR showed 1518.7 instead of ~15.
**Fix**: Removed second division: `pots[street] = current_pot` (already in BB).

### 7. Suited/Offsuit Misidentification
**Problem**: AI said "suited K7" for Kh 7s (different suits = offsuit). Also, few-shot example #3 showed `Ad 7s` (offsuit) but analysis text called it "A7s".
**Fix**:
- Added CARD NOTATION guide to system prompt with suited/offsuit examples
- Added explicit `(suited)` / `(offsuit)` label to hero line in prompt
- Fixed few-shot example #3: changed "A7s" references to "A7o", grade A → B
- Added global rubric rule: "Suited vs offsuit always matters"

### 8. Grading Too Lenient (All A Grades)
**Problem**: Tool-use format constrained output, making AI default to A grades. Claude web with same prompt gave more nuanced C/D grades.
**Fix**:
- Added "CRITICAL GRADING STANDARDS" to system prompt (be tough, A is rare, look for missed value bets/sizing errors)
- Increased thinking budget: 2000 → 5000 tokens
- Expanded tool schema `reasoning` field: "5-10 sentences, identify every imperfection"
- Expanded `street.analysis` field: "2-3 sentences, state what was optimal and what would have been better"

### 9. Trash Hand Grading
**Problem**: AI called folding 92o "conservative".
**Fix**: Added AUTOMATIC GRADES section to rubric — trash hands always grade A, folding AA/KK always grade F.

---

## Architecture After Changes

### Model & Thinking
- Model: Sonnet 4.6 for all hand analysis (was Haiku for 1-2 street hands)
- Thinking budget: 5000 tokens
- max_tokens: automatically set to `thinking_budget + 4096`

### Prompt Structure
1. **System blocks**: Role → Card Notation → Rules + Grading Standards → Grade Rubric → Board Textures
2. **Few-shot examples**: 3 calibration examples (optimal play, mixed grades, short-stack offsuit shove)
3. **User prompt**: Hand context + opponent profiles + derived context + actions by street + winner

### Key Files Modified
- `poker_friend_engine/app/api/routes/analyze.py` — prompt builder, action formatting, system blocks
- `poker_friend_engine/app/core/rubric.py` — rubric text, few-shot examples
- `poker_friend_engine/app/core/model_router.py` — all Sonnet, 5000 thinking budget
- `poker_friend_engine/app/core/claude_client.py` — max_tokens auto-adjustment, 90s timeout
- `poker_friend_engine/app/core/derived_context.py` — effective stack fix, pot calculation fix
- `poker_friend_engine/app/core/tool_schemas.py` — expanded reasoning/analysis descriptions
- `poker_friend_app/lib/services/ai_analyzer_service.dart` — gameType fix, 90s timeout, production URL
- `poker_friend_app/lib/screens/hand_actions_screen.dart` — "(beta)" label, disable after analysis
- `poker_friend_app/lib/screens/session_analytics_screen.dart` — removed AI Report button

### Deleted Files
- `poker_friend_engine/app/core/session_analyzer.py`
- `poker_friend_engine/app/api/routes/analytics.py`
- `poker_friend_app/lib/screens/session_analysis_report_screen.dart`
- `poker_friend_app/lib/services/session_analytics_service.dart`
