//
//  CardMatchingGame.m
//  Matchismo
//
//  Created by Nikita Kukushkin on 30/01/2013.
//  Copyright (c) 2013 Nikita Kukushkin. All rights reserved.
//

#import "CardMatchingGame.h"

@interface CardMatchingGame()

// Keeps track of how many cards
// are being matched this game
@property (nonatomic) enum GameMode gameMode;

@property (nonatomic, readwrite) NSArray *history;
@property (nonatomic, readwrite) int score;
@property (nonatomic, readwrite) int flipCount;
@property (nonatomic, strong) NSMutableArray *cards;
@property (nonatomic) NSUInteger flipCost;
@property (nonatomic) NSUInteger matchBonus;
@property (nonatomic) NSUInteger mismatchPenalty;
@end

@implementation CardMatchingGame

#pragma mark - Game Logic

- (BOOL)isGameOver
{
    BOOL gameOver = NO;
    
    // Getting an array of cards
    // that haven't been played yet
    NSMutableArray *unplayedCards = [[NSMutableArray alloc] init];
    for (Card *card in self.cards) {
        if (!card.isUnplayable) {
            [unplayedCards addObject:card];
        }
    }
    // If there is less cards than needed for a match then
    // it's a game over (gameMode = 2/3 for twoCard/threeCard)
    if ([unplayedCards count] < self.gameMode) {
        gameOver = YES;
    }
    // If there is more than 8(worst case for 3 card match)
    // cards still ready to be played, game can not be over
    else if ([unplayedCards count] > 8) {
        gameOver = NO;
    }
    // Code below checks for avalable matches,
    // if there are none, then the game is over
    else {
        NSUInteger avalableMatches = 0;
        
        if (self.gameMode == twoCards) {
            for (Card *cardOne in unplayedCards) {
                for (Card *cardTwo in unplayedCards) {
                    if([cardOne match:@[cardTwo]]) {
                        avalableMatches++;
                    }
                }
            }
            // Subtracting duplicate counts
            avalableMatches -= [unplayedCards count];
        }
        else if (self.gameMode == threeCards) {
            // Non-ideal performance,
            // however could be ok, since this runs only
            // after there are 8 cards left unplayed
            NSMutableSet *threeCardCombinations = [[NSMutableSet alloc] init];
            for (Card *cardOne in unplayedCards) {
                for (Card *cardTwo in unplayedCards) {
                    for (Card *cardThree in unplayedCards) {
                        NSSet *threeCardCombination = [NSSet setWithArray:@[cardOne, cardTwo, cardThree]];
                        if ([threeCardCombination count] == 3) {
                            // We put sets of 3 elements into a set of all triplets
                            // that way we should eliminate any permutation effects
                            [threeCardCombinations addObject:threeCardCombination];
                        }
                    }
                }
            }
            for (NSSet *cardTrioS in [threeCardCombinations allObjects]) {
                NSArray *cardTrio = [cardTrioS allObjects];
                if ([cardTrio[0] match:@[cardTrio[1], cardTrio[2]]]) {
                    avalableMatches++;
                }
            }
        }
    
        gameOver = (avalableMatches) ? NO : YES; // no avalable matches = game over
    }

    // Disabling some game fatures
    // if the game is over
    if (gameOver) {
        self.flipCost = 0;
        if (![[self.history lastObject] isEqualToString:@"Game Over"]) {
            self.history = [self.history arrayByAddingObject:@"Game Over"];
        }
        for (Card *card in unplayedCards) {
            card.faceUp = YES;
        }
    }
    return gameOver;
}

- (void)twoCardGameFlipCardAtIndex:(NSUInteger)index
{
    Card *card = [self cardAtIndex:index];
    NSString *status = nil;
    if (!card.isUnplayable) {
        if (!card.isFaceUp) {
            for (Card *otherCard in self.cards) {
                if (otherCard.isFaceUp && !otherCard.isUnplayable) {
                    int matchScore = [card match:@[otherCard]];
                    if (matchScore) {
                        otherCard.unplayable = YES;
                        card.unplayable = YES;
                        self.score += matchScore * self.matchBonus;
                        status = [NSString stringWithFormat:@"matched %@ and %@ for %d points", card, otherCard, matchScore * self.matchBonus];
                    }
                    else {
                        otherCard.faceUp = NO;
                        self.score -= self.mismatchPenalty;
                        status = [NSString stringWithFormat:@"%@ and %@ don't match: %d points penalty", card, otherCard, self.mismatchPenalty];
                    }
                }
            }
            self.score -= self.flipCost;
        }
        card.faceUp = !card.isFaceUp;
    }
    if (![self isGameOver]) {
        self.flipCount++;
        if (status) {
            self.history = [self.history arrayByAddingObject:status];
        }
    }
}

- (void)threeCardGameFlipCardAtIndex:(NSUInteger)index
{
    Card *card = [self cardAtIndex:index];
    NSString *status = nil;
    
    if (!card.isUnplayable) {
        if (!card.isFaceUp) {
            // otherCards array has to keep 2 other cards,
            // since this is a three card flip logic
            NSMutableArray *otherCards = [[NSMutableArray alloc] init];
            for (Card *otherCard in self.cards) {
                if (otherCard.isFaceUp && !otherCard.isUnplayable) {
                    [otherCards addObject:otherCard];
                    if (otherCards.count == 2)
                    {
                        int matchScore = [card match:otherCards];
                        if (matchScore) {
                            for (Card *card in otherCards) {
                                card.unplayable = YES;
                            }
                            card.unplayable = YES;
                            self.score += matchScore * self.matchBonus;
                            status = [NSString stringWithFormat:@"matched %@ %@ %@ for %d points", card, otherCards[0], otherCards[1], matchScore * self.matchBonus];
                        }
                        else {
                            for (Card *card in otherCards) {
                                card.faceUp = NO;
                            }
                            self.score -= self.mismatchPenalty;
                            status = [NSString stringWithFormat:@"%@ %@ %@ don't match: %d points penalty", card, otherCards[0], otherCards[1], self.mismatchPenalty];
                        }
                    }
                }
            }
            self.score -= self.flipCost;
        }
        card.faceUp = !card.isFaceUp;
    }
    if (![self isGameOver]) {
        self.flipCount++;
        if (status) {
            self.history = [self.history arrayByAddingObject:status];
        }
    }
}

#pragma mark - Public

- (Card *)cardAtIndex:(NSUInteger)index
{
    return (index < self.cards.count) ? self.cards[index] : nil;
}

- (void)flipCardAtIndex:(NSUInteger)index
{
    if (self.gameMode == threeCards) {
        [self threeCardGameFlipCardAtIndex:index];
    }
    else {
        [self twoCardGameFlipCardAtIndex:index];
    }
}

#pragma mark - Accessors

- (NSMutableArray *)cards
{
    if (!_cards) {
        _cards = [[NSMutableArray alloc] init];
    }
    return _cards;
}

- (NSArray *)history
{
    if (!_history) {
        _history = [[NSArray alloc] init];
    }
    return _history;
}

#pragma mark - Initializers

- (id)initWithCardCount:(NSUInteger)cardCount andGameMode:(enum GameMode)gameMode usingDeck:(Deck *)deck
{
    self = [super init];
    
    if (self) {
        // Initializing game settings
        self.flipCost = 1;
        self.matchBonus = 5;
        self.mismatchPenalty = 2;
        
        self.gameMode = gameMode;
        for (int i = 0; i < cardCount; i++) {
            Card *card = [deck drawRandomCard];
            if (!card) {
                self = nil;
            }
            else {
                self.cards[i] = card;
            }
        }
    }
    
    return self;
}

@end
