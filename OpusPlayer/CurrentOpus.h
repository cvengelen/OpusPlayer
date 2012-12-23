//
//  CurrentOpus.h
//
//  Currently playing opus item
//
//  Created by Chris van Engelen on 22-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVAudioPlayer.h>
#import "Opus.h"
#import "CurrentOpusDelegate.h"

@interface CurrentOpus : NSObject <AVAudioPlayerDelegate>
{
    // The current opus
    Opus* opus;
    
    // Part names
    NSArray* partNames;

    // Current index in part names
    int partNamesIndex;

    // Date and time at which opus starts playing
    NSDate* startsPlayingDate;

    // Is the opus item playing?
    BOOL isPlaying;
    
    // The delegate
    NSObject<CurrentOpusDelegate>* delegate;
    
    // The audio player
    AVAudioPlayer* audioPlayer;
}

@property (readonly) Opus* opus;
@property (readonly) NSDate* startsPlayingDate;
@property (readonly) BOOL isPlaying;

-( id )initWithOpus:( Opus* )anOpus andDelegate:( NSObject <CurrentOpusDelegate>* )aDelegate;

-( void )startPlaying;
-( void )playNextOpusPart;
-( void )playPreviousOpusPart;

-( void )playOrPause;
-( void )stopPlaying;

@end
