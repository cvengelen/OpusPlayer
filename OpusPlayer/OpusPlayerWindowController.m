//
//  OpusPlayerWindowController.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 04-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import "OpusPlayerWindowController.h"
#import "NormalViewController.h"
#import "FullScreenViewController.h"

@implementation OpusPlayerWindowController {
    NormalViewController     *normalViewController;
    FullScreenViewController *fullScreenViewController;
}

- (id)initWithPlayedOpusItemsWindowController:(PlayedOpusItemsWindowController *)playedOpusItemsWindowController {
    self = [super initWithWindowNibName:@"OpusPlayerWindow"];
    if (self) {
        fullScreenViewController = [[FullScreenViewController alloc] init];
        
        // Forward the played opus items window controller to the normal view controller, for the played opus items.
        normalViewController = [[NormalViewController alloc] initWithPlayedOpusItemsWindowController:playedOpusItemsWindowController
                                                                     andWithFullScreenViewController:fullScreenViewController];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Initialise the opus player box with the normal container view
    [_opusPlayerBox setContentView:[normalViewController view]];
    
    // Make it impossible to close the window
    _opusPlayerWindow.styleMask &= ~NSClosableWindowMask;

    // Make this the main window of the application
    [_opusPlayerWindow makeMainWindow];

    // Make the window key (receiving keyboard input), and put it in front of other windows
    [_opusPlayerWindow makeKeyAndOrderFront:self];
}


- (void)showWindow {
    [super showWindow:self];
    
    // Check if the window is miniaturized
    if ([_opusPlayerWindow isMiniaturized]) {
        // Deminiaturize the windows
        [_opusPlayerWindow deminiaturize:self];
    }
    
    // Put the window in front of other windowss
    [_opusPlayerWindow orderFront:self];
}

#pragma mark -
#pragma mark NSWindowDelegate

-(void)windowDidEnterFullScreen:( NSNotification* )notification {
    // Setup the full screen window controller
    [fullScreenViewController windowDidEnterFullScreen];

    // Set the full screen view in the content of the opus player box
    [_opusPlayerBox setContentView:[fullScreenViewController view]];
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    // Setup the full screen window controller
    [fullScreenViewController windowDidExitFullScreen];

    // Set the full screen view in the content of the opus player box
    [_opusPlayerBox setContentView:[normalViewController view]];
}

@end
