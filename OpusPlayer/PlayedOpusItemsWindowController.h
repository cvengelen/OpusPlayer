//
//  PlayedOpusItemsWindowController.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PlayedOpus.h"

@interface PlayedOpusItemsWindowController : NSWindowController

// The array containing the played opus items
@property (readwrite) NSMutableArray *playedOpusItems;

// The array controller for the played opus items
@property (weak) IBOutlet NSArrayController *playedOpusItemsArrayController;

@property (weak) IBOutlet NSWindow *playedOpusItemsWindow;

- (void)addPlayedOpus:(PlayedOpus *)playedOpus;

- (void)showWindow;

@end
