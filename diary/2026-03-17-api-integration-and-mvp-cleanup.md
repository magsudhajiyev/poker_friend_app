# API Integration and MVP Cleanup

**Date:** 2026-03-17

## Changes Made

### 1. Integrated Deployed Poker Analysis API

**Problem:** AI analyzer and session analytics services were using localhost endpoint which doesn't work in production.

**Solution:** Updated both services to use the deployed API endpoint with authentication.

**Files Modified:**
- `lib/services/ai_analyzer_service.dart`
- `lib/services/session_analytics_service.dart`

**Changes:**
- Base URL: `http://localhost:8080/api/v1` → `https://poker-friend-engine.onrender.com/api/v1`
- Added API key constant: `_apiKey`
- Added `X-API-Key` header to all HTTP requests (1 POST + 6 GET in session_analytics_service)

### 2. Commented Out "Request Full GTO Analysis" for MVP

**Problem:** The `/api/v1/analytics/sessions` endpoint is not deployed yet, causing 404 errors when users try to request full session analysis.

**Solution:** Commented out the entire "Request Full GTO Analysis" feature until the backend endpoint is deployed.

**File:** `lib/screens/session_analytics_screen.dart`

**Commented out:**
- Imports: `session_analytics_service.dart`, `auth_service.dart`
- State variables: `_isRequestingAnalysis`, `_analysisJobId`, `_analysisSessionId`, `_analysisStatus`, `_analysisProgress`, `_analysisError`
- Methods: `_buildFullAnalysisButton()`, `_requestFullAnalysis()`, `_pollJobProgress()`, `_viewAnalysisResults()`
- UI: Button removed from build method

**Still Working:**
- Per-hand AI analysis (`AIAnalyzerService.analyzeHand()`) - uses `/api/v1/analyze-hand` endpoint which IS deployed
- Session analytics screen shows: overview, stack chart, "View Logged Hands" button

## API Endpoints Status

| Endpoint | Status | Used By |
|----------|--------|---------|
| `/api/v1/analyze-hand` | Deployed | AIAnalyzerService (per-hand analysis) |
| `/api/v1/analytics/sessions` | NOT deployed | SessionAnalyticsService (commented out) |

## Testing

1. Open a completed session → View session analytics
2. Verify "Request Full GTO Analysis" button is NOT visible
3. Tap "View Logged Hands" → Open a hand → Tap AI analyzer
4. Verify per-hand analysis works correctly
