export enum Suit {
  HEARTS = 'H',
  DIAMONDS = 'D',
  CLUBS = 'C',
  SPADES = 'S'
}

export enum Rank {
  TWO = 2,
  THREE = 3,
  FOUR = 4,
  FIVE = 5,
  SIX = 6,
  SEVEN = 7,
  EIGHT = 8,
  NINE = 9,
  TEN = 10,
  JACK = 11,
  QUEEN = 12,
  KING = 13,
  ACE = 14
}

export class Card {
  constructor(
    public readonly rank: Rank,
    public readonly suit: Suit
  ) {}

  toString(): string {
    const rankStr = this.rank === Rank.JACK ? 'J' :
                   this.rank === Rank.QUEEN ? 'Q' :
                   this.rank === Rank.KING ? 'K' :
                   this.rank === Rank.ACE ? 'A' :
                   this.rank.toString();
    return `${rankStr}${this.suit}`;
  }

  static fromString(cardStr: string): Card {
    const rank = cardStr.slice(0, -1);
    const suit = cardStr.slice(-1) as Suit;
    
    let rankValue: Rank;
    switch (rank) {
      case 'J': rankValue = Rank.JACK; break;
      case 'Q': rankValue = Rank.QUEEN; break;
      case 'K': rankValue = Rank.KING; break;
      case 'A': rankValue = Rank.ACE; break;
      default: rankValue = parseInt(rank) as Rank;
    }
    
    return new Card(rankValue, suit);
  }
}