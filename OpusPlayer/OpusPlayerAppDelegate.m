//
//  OpusPlayerAppDelegate.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "OpusPlayerAppDelegate.h"

#import "OpusPlayerWindowController.h"
#import "PlayedOpusItemsWindowController.h"

@implementation OpusPlayerAppDelegate {
    // Opus Player window controller
    OpusPlayerWindowController *opusPlayerWindowController;

    // Played Opus Items window controller
    PlayedOpusItemsWindowController *playedOpusItemsWindowController;
}

- (id)init {
    self = [super init];
    if (self) {
       // Create the played opus items window controller
        playedOpusItemsWindowController = [[PlayedOpusItemsWindowController alloc] init];

        // Create the opus player window controller, needs the played opus items window controller to send the played opus items to.
        opusPlayerWindowController = [[OpusPlayerWindowController alloc] initWithPlayedOpusItemsWindowController:playedOpusItemsWindowController];
    }

    return self;
}

#pragma mark -
#pragma mark NSApplicationDelegate

// NSApplicationDelegate: Sent by the default notification center after the application
// has been launched and initialized but before it has received its first event
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Show the main opus player window
    [opusPlayerWindowController showWindow:self];
}

// NSApplicationDelegate: Sent by the default notification center immediately before the application terminates
-( void )applicationWillTerminate:(NSNotification *)notification
{
    [opusPlayerWindowController applicationWillTerminate];
}

#pragma mark -
#pragma mark Menu

- (IBAction)showPlayedOpusItems:(NSMenuItem *)sender {
    [playedOpusItemsWindowController showWindow];
}

@end
