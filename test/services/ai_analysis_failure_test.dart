import 'package:flutter_test/flutter_test.dart';
import 'package:poker_logger/services/ai_analyzer_service.dart';

void main() {
  final fallback = <String, dynamic>{
    'analysisId': 'x',
    'correct': null,
    'severity': 'unknown',
    'aiAnalysis': {
      'reasoning': 'Analysis could not be completed',
      'optimalAction': 'unknown',
      'learningPoint': '',
    },
    'streetBreakdown': null,
    'exploitativeTip': null,
  };
  final real = <String, dynamic>{
    'analysisId': 'y',
    'correct': true,
    'severity': 'minor',
    'aiAnalysis': {
      'reasoning': 'Calling is fine here given pot odds.',
      'optimalAction': 'call',
      'learningPoint': 'Mind your price.',
    },
    'streetBreakdown': [
      {'street': 'preflop', 'note': 'Standard open.'}
    ],
    'exploitativeTip': 'Villain over-folds.',
  };

  test('detects the backend fallback body', () {
    expect(AIAnalyzerService.isFailedAnalysis(fallback), isTrue);
  });

  test('detects fallback by shape when reasoning text differs', () {
    final m = Map<String, dynamic>.from(fallback)
      ..['aiAnalysis'] = {'reasoning': 'x', 'optimalAction': 'unknown', 'learningPoint': ''};
    expect(AIAnalyzerService.isFailedAnalysis(m), isTrue);
  });

  test('does not flag a real analysis', () {
    expect(AIAnalyzerService.isFailedAnalysis(real), isFalse);
  });

  test('does not flag unknown action that has a street breakdown', () {
    final m = Map<String, dynamic>.from(real)
      ..['aiAnalysis'] = {'reasoning': 'ok', 'optimalAction': 'unknown', 'learningPoint': ''};
    expect(AIAnalyzerService.isFailedAnalysis(m), isFalse);
  });

  test('null is a failure', () {
    expect(AIAnalyzerService.isFailedAnalysis(null), isTrue);
  });
}
