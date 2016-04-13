//
//  OpusPlayerAppDelegate.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <WebAppKit/WebAppKit.h>

#import "OpusPlayerAppDelegate.h"
#import "OpusPlayerWindowController.h"
#import "PlayedOpusItemsWindowController.h"
#import "WebApp.h"

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

        // Start a separate thread to run WebApp
        [NSThread detachNewThreadSelector:@selector(webAppThreadMethod:) toTarget:self withObject:nil];
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

#pragma mark -
#pragma mark WebApp

// Run WebApp on a separate thread
- (void)webAppThreadMethod:(id)options
{
    // Uncomment the following to get some more logging from WebApp
#ifdef DEBUG
    WASetDevelopmentMode(YES);
#endif

    // Create and schedule a timer. Required: without the timer, the runloop exits immediately.
    // See: https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html
    // Especially section Configuring the Run loop:
    //    Before you run a run loop on a secondary thread, you must add at least one input source or timer to it.
    //    If a run loop does not have any sources to monitor, it exits immediately when you try to run it.
    // The value of the time interval does not seem to make any difference.
    [NSTimer scheduledTimerWithTimeInterval:60.0 target:self
                                   selector:@selector(doFireTimer:) userInfo:nil repeats:YES];

    // Run WebApp, this also initializes the WebApp instance
    [WebApp run];
}

- (void)doFireTimer:(NSTimer *)timer {
    // No action
}

@end
