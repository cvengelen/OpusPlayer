//
//  WebAppDelegate.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 20-03-13.
//  Copyright (c) 2013 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol WebAppDelegate <NSObject>

// Request the delegate to play or pause the current opus
-( void )webAppPlayOrPause;

// Request the delegate to play the next opus
-( void )webAppPlayNextOpus;

@end
