import { Hand, HandEvaluation } from '../models/Hand';
import { Card } from '../models/Card';

export interface GameSession {
  id: string;
  startTime: Date;
  endTime?: Date;
  hands: HandLog[];
}

export interface HandLog {
  id: string;
  timestamp: Date;
  hand: Hand;
  evaluation: HandEvaluation;
  playerName?: string;
  position?: string;
  action?: string;
  result?: 'win' | 'loss' | 'fold';
  potSize?: number;
  notes?: string;
}

export class GameLogger {
  private sessions: Map<string, GameSession> = new Map();
  private currentSessionId: string | null = null;

  startSession(sessionId?: string): string {
    const id = sessionId || this.generateSessionId();
    const session: GameSession = {
      id,
      startTime: new Date(),
      hands: []
    };
    
    this.sessions.set(id, session);
    this.currentSessionId = id;
    
    console.log(`Started new game session: ${id}`);
    return id;
  }

  endSession(sessionId?: string): void {
    const id = sessionId || this.currentSessionId;
    if (!id) {
      throw new Error('No active session to end');
    }

    const session = this.sessions.get(id);
    if (!session) {
      throw new Error(`Session ${id} not found`);
    }

    session.endTime = new Date();
    if (this.currentSessionId === id) {
      this.currentSessionId = null;
    }

    console.log(`Ended game session: ${id}`);
  }

  logHand(
    cards: Card[],
    options: Partial<Omit<HandLog, 'id' | 'timestamp' | 'hand' | 'evaluation'>> = {}
  ): string {
    if (!this.currentSessionId) {
      throw new Error('No active session. Start a session first.');
    }

    const hand = new Hand(cards);
    const evaluation = hand.evaluate();
    
    const handLog: HandLog = {
      id: this.generateHandId(),
      timestamp: new Date(),
      hand,
      evaluation,
      ...options
    };

    const session = this.sessions.get(this.currentSessionId)!;
    session.hands.push(handLog);

    console.log(`Logged hand: ${hand.toString()} - ${evaluation.description}`);
    return handLog.id;
  }

  getSession(sessionId: string): GameSession | undefined {
    return this.sessions.get(sessionId);
  }

  getCurrentSession(): GameSession | undefined {
    return this.currentSessionId ? this.sessions.get(this.currentSessionId) : undefined;
  }

  getAllSessions(): GameSession[] {
    return Array.from(this.sessions.values());
  }

  getHandStats(sessionId?: string): {
    totalHands: number;
    handTypeStats: Record<string, number>;
    winRate?: number;
  } {
    const session = sessionId ? 
      this.sessions.get(sessionId) : 
      this.getCurrentSession();

    if (!session) {
      throw new Error('Session not found');
    }

    const handTypeStats: Record<string, number> = {};
    let wins = 0;
    let totalWithResults = 0;

    for (const handLog of session.hands) {
      const type = handLog.evaluation.description;
      handTypeStats[type] = (handTypeStats[type] || 0) + 1;

      if (handLog.result) {
        totalWithResults++;
        if (handLog.result === 'win') {
          wins++;
        }
      }
    }

    return {
      totalHands: session.hands.length,
      handTypeStats,
      winRate: totalWithResults > 0 ? wins / totalWithResults : undefined
    };
  }

  exportSession(sessionId: string): string {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    return JSON.stringify(session, null, 2);
  }

  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private generateHandId(): string {
    return `hand_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}