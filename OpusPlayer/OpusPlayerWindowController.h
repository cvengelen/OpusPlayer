//
//  OpusPlayerWindowController.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 04-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PlayedOpusItemsWindowController.h"

@interface OpusPlayerWindowController : NSWindowController <NSWindowDelegate>

// The opus player window
@property (weak) IBOutlet NSWindow *opusPlayerWindow;

// The box in the opus player window, in which the normal or full screen view is placed
@property (weak) IBOutlet NSBox *opusPlayerBox;

// Initialise with the played opus items window controller
- (id)initWithPlayedOpusItemsWindowController:(PlayedOpusItemsWindowController *)playedOpusItemsWindowController;

- (void)showWindow;

-(void)applicationWillTerminate;

@end
