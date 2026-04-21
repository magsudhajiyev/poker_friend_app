# AI Hand Analysis — Cost Estimate

**Date**: 2026-04-21

## Current Setup

| Parameter | Value |
|-----------|-------|
| Model | Claude Sonnet 4.6 (`claude-sonnet-4-6`) |
| Thinking budget | 5,000 tokens |
| max_tokens | 9,096 (thinking + 4096) |
| Timeout | 90s (Flutter) / 90s (backend) |
| Prompt caching | Enabled (system blocks + few-shot examples cached) |

## Sonnet 4.6 Pricing

| Token Type | Cost |
|-----------|------|
| Input | $3 / 1M tokens |
| Input (cached) | $0.30 / 1M tokens (90% discount) |
| Output | $15 / 1M tokens |
| Extended thinking output | $15 / 1M tokens |

## Per-Call Token Estimate

| Component | Tokens | Notes |
|-----------|--------|-------|
| System blocks (card notation, rules, rubric, board textures) | ~1,500 | Cached after first call |
| Few-shot examples (3 user/assistant/tool_result pairs) | ~2,500 | Cached after first call |
| User hand prompt (context, actions, derived context) | ~400 | Varies by hand complexity |
| **Total input** | **~4,400** | ~4,000 cached + ~400 uncached |
| Extended thinking output | ~2,000–3,000 | Budget is 5,000 but rarely fully used |
| Tool response (reasoning + streets + verdict) | ~500 | Structured JSON output |
| **Total output** | **~3,000** | |

## Per-Call Cost Estimate

| Component | Calculation | Cost |
|-----------|------------|------|
| Uncached input (hand prompt) | 400 × $3/M | $0.001 |
| Cached input (system + few-shot) | 4,000 × $0.30/M | $0.001 |
| Output (thinking + tool response) | 3,000 × $15/M | $0.045 |
| **Total per analysis** | | **~$0.05–0.06** |

## Validation

- April 21, 2026: $0.72 total for ~12 analysis calls = **~$0.06/call** (matches estimate)

## Monthly Cost Projections

| Users | Hands analyzed/user/month | Monthly cost |
|-------|--------------------------|-------------|
| 10 | 50 | $30 |
| 50 | 50 | $150 |
| 100 | 50 | $300 |
| 500 | 50 | $1,500 |
| 1,000 | 50 | $3,000 |

## Cost Optimization Levers (if needed)

1. **Reduce thinking budget** (5000 → 3000): saves ~30% on output cost → ~$0.04/call
2. **Use Haiku for simple hands** (preflop-only folds): ~$0.005/call for trivial hands
3. **Cache hit rate**: prompt caching saves ~90% on system+few-shot input after first call in a session
4. **Rate limiting**: free tier limited to 5 hands/session already gates usage
5. **Batch analysis**: if analyzing multiple hands, amortize cached input across calls

## Break-Even with Subscription

- Pro subscription: $29.99/month
- At $0.06/call, a user can analyze **~500 hands/month** before AI costs exceed subscription revenue
- Typical usage expected: 20-100 hands/month per active user → healthy margin
