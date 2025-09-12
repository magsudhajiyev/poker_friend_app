import { Card, Rank } from './Card';

export enum HandRank {
  HIGH_CARD = 1,
  PAIR = 2,
  TWO_PAIR = 3,
  THREE_OF_A_KIND = 4,
  STRAIGHT = 5,
  FLUSH = 6,
  FULL_HOUSE = 7,
  FOUR_OF_A_KIND = 8,
  STRAIGHT_FLUSH = 9,
  ROYAL_FLUSH = 10
}

export interface HandEvaluation {
  rank: HandRank;
  description: string;
  kickers: Rank[];
}

export class Hand {
  constructor(public readonly cards: Card[]) {
    if (cards.length !== 5) {
      throw new Error('A poker hand must contain exactly 5 cards');
    }
  }

  evaluate(): HandEvaluation {
    const sortedCards = [...this.cards].sort((a, b) => b.rank - a.rank);
    
    const isFlush = this.isFlush();
    const isStraight = this.isStraight();
    const rankCounts = this.getRankCounts();
    const counts = Object.values(rankCounts).sort((a, b) => b - a);
    
    if (isFlush && isStraight) {
      if (sortedCards[0].rank === Rank.ACE && sortedCards[1].rank === Rank.KING) {
        return {
          rank: HandRank.ROYAL_FLUSH,
          description: 'Royal Flush',
          kickers: []
        };
      }
      return {
        rank: HandRank.STRAIGHT_FLUSH,
        description: 'Straight Flush',
        kickers: [sortedCards[0].rank]
      };
    }
    
    if (counts[0] === 4) {
      const fourOfAKindRank = this.getRankWithCount(rankCounts, 4);
      const kicker = this.getRankWithCount(rankCounts, 1);
      return {
        rank: HandRank.FOUR_OF_A_KIND,
        description: 'Four of a Kind',
        kickers: [fourOfAKindRank, kicker]
      };
    }
    
    if (counts[0] === 3 && counts[1] === 2) {
      const threeOfAKindRank = this.getRankWithCount(rankCounts, 3);
      const pairRank = this.getRankWithCount(rankCounts, 2);
      return {
        rank: HandRank.FULL_HOUSE,
        description: 'Full House',
        kickers: [threeOfAKindRank, pairRank]
      };
    }
    
    if (isFlush) {
      return {
        rank: HandRank.FLUSH,
        description: 'Flush',
        kickers: sortedCards.map(c => c.rank)
      };
    }
    
    if (isStraight) {
      return {
        rank: HandRank.STRAIGHT,
        description: 'Straight',
        kickers: [sortedCards[0].rank]
      };
    }
    
    if (counts[0] === 3) {
      const threeOfAKindRank = this.getRankWithCount(rankCounts, 3);
      const kickers = sortedCards
        .filter(c => c.rank !== threeOfAKindRank)
        .map(c => c.rank);
      return {
        rank: HandRank.THREE_OF_A_KIND,
        description: 'Three of a Kind',
        kickers: [threeOfAKindRank, ...kickers]
      };
    }
    
    if (counts[0] === 2 && counts[1] === 2) {
      const pairs = Object.entries(rankCounts)
        .filter(([, count]) => count === 2)
        .map(([rank]) => parseInt(rank) as Rank)
        .sort((a, b) => b - a);
      const kicker = this.getRankWithCount(rankCounts, 1);
      return {
        rank: HandRank.TWO_PAIR,
        description: 'Two Pair',
        kickers: [...pairs, kicker]
      };
    }
    
    if (counts[0] === 2) {
      const pairRank = this.getRankWithCount(rankCounts, 2);
      const kickers = sortedCards
        .filter(c => c.rank !== pairRank)
        .map(c => c.rank);
      return {
        rank: HandRank.PAIR,
        description: 'Pair',
        kickers: [pairRank, ...kickers]
      };
    }
    
    return {
      rank: HandRank.HIGH_CARD,
      description: 'High Card',
      kickers: sortedCards.map(c => c.rank)
    };
  }

  private isFlush(): boolean {
    const firstSuit = this.cards[0].suit;
    return this.cards.every(card => card.suit === firstSuit);
  }

  private isStraight(): boolean {
    const sortedRanks = [...this.cards].map(c => c.rank).sort((a, b) => a - b);
    
    for (let i = 1; i < sortedRanks.length; i++) {
      if (sortedRanks[i] !== sortedRanks[i - 1] + 1) {
        if (sortedRanks[0] === Rank.TWO && sortedRanks[4] === Rank.ACE && 
            sortedRanks[1] === Rank.THREE && sortedRanks[2] === Rank.FOUR && 
            sortedRanks[3] === Rank.FIVE) {
          return true;
        }
        return false;
      }
    }
    return true;
  }

  private getRankCounts(): Record<number, number> {
    const counts: Record<number, number> = {};
    for (const card of this.cards) {
      counts[card.rank] = (counts[card.rank] || 0) + 1;
    }
    return counts;
  }

  private getRankWithCount(rankCounts: Record<number, number>, count: number): Rank {
    for (const [rank, c] of Object.entries(rankCounts)) {
      if (c === count) {
        return parseInt(rank) as Rank;
      }
    }
    throw new Error(`No rank found with count ${count}`);
  }

  toString(): string {
    return this.cards.map(c => c.toString()).join(' ');
  }
}