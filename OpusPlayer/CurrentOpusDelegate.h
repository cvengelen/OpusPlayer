//
//  CurrentOpusDelegate.h
//
//  Protocol for a delegate of the CurrentOpus class
//  - Send opusDidFinishPlaying message to delegate when de audio player has finished playing.
//  - Use XIB outlets from the delegate to handle buttons en text fields.
//
//  Created by Chris van Engelen on 22-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CurrentOpusDelegate <NSObject>

@property (weak) IBOutlet NSButton *previousOpusPartButton;
@property (weak) IBOutlet NSButton *playOrPauseButton;
@property (weak) IBOutlet NSButton *nextOpusPartButton;
@property (weak) IBOutlet NSButton *nextOpusButton;
@property (weak) IBOutlet NSButton *shuffleButton;

// Notify the delegate that the opus did finish playing
-( void )opusDidFinishPlaying;

// Notify the delegate of new string values for the composerOpus, artist and opus part.
-( void )setStringComposerOpus:( NSString* )aComposerOpus;
-( void )setStringArtist:( NSString* )anArtist;
-( void )setStringOpusPart:( NSString* )anOpusPart;

@end
