import { Card, Suit, Rank } from './models/Card';
import { Hand } from './models/Hand';
import { GameLogger } from './services/GameLogger';

function main() {
  console.log('🃏 Poker Logger initialized!');
  
  const logger = new GameLogger();
  const sessionId = logger.startSession();
  
  const exampleHands = [
    [
      new Card(Rank.ACE, Suit.SPADES),
      new Card(Rank.KING, Suit.SPADES),
      new Card(Rank.QUEEN, Suit.SPADES),
      new Card(Rank.JACK, Suit.SPADES),
      new Card(Rank.TEN, Suit.SPADES)
    ],
    [
      new Card(Rank.EIGHT, Suit.HEARTS),
      new Card(Rank.EIGHT, Suit.DIAMONDS),
      new Card(Rank.EIGHT, Suit.CLUBS),
      new Card(Rank.EIGHT, Suit.SPADES),
      new Card(Rank.ACE, Suit.HEARTS)
    ],
    [
      new Card(Rank.ACE, Suit.HEARTS),
      new Card(Rank.KING, Suit.DIAMONDS),
      new Card(Rank.QUEEN, Suit.CLUBS),
      new Card(Rank.SEVEN, Suit.SPADES),
      new Card(Rank.TWO, Suit.HEARTS)
    ]
  ];

  console.log('\n--- Logging example hands ---');
  
  exampleHands.forEach((cards, index) => {
    logger.logHand(cards, {
      playerName: 'Player1',
      position: 'Button',
      result: index === 0 ? 'win' : index === 1 ? 'loss' : 'fold',
      notes: `Example hand ${index + 1}`
    });
  });

  console.log('\n--- Session Statistics ---');
  const stats = logger.getHandStats();
  console.log(`Total hands played: ${stats.totalHands}`);
  console.log('Hand types:');
  Object.entries(stats.handTypeStats).forEach(([type, count]) => {
    console.log(`  ${type}: ${count}`);
  });
  
  if (stats.winRate !== undefined) {
    console.log(`Win rate: ${(stats.winRate * 100).toFixed(1)}%`);
  }

  logger.endSession();
  
  console.log('\n--- Session Export ---');
  const exportedData = logger.exportSession(sessionId);
  console.log('Session data exported (first 200 chars):');
  console.log(exportedData.substring(0, 200) + '...');
}

if (require.main === module) {
  main();
}