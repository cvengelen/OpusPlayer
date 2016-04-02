//
//  PlayedOpusItems.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import "PlayedOpusItemsWindowController.h"

@implementation PlayedOpusItemsWindowController {

    // All previously played opus items
    NSMutableArray *playedOpusItems;
}

@synthesize playedOpusItems;

- ( id )initWithPlayedOpusItems:(NSMutableArray *)aPlayedOpusItems {

    self = [ super initWithWindowNibName:@"PlayedOpusItems" ];
    if ( self )
    {
        // Initialise the array with the played opus items
        playedOpusItems = [ NSMutableArray arrayWithArray:aPlayedOpusItems ];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Make it possible to close the window (this is not default)
    // The window can be shown with the menu item "Played opus items"
    _playedOpusItemsWindow.styleMask |= NSClosableWindowMask;
}

- (void) addPlayedOpus:(PlayedOpus*)playedOpus {
    // Notify the array controller that the contents will be changed
    [ _playedOpusItemsArrayController willChangeValueForKey:@"arrangedObjects" ];
    
    // Add the played opus item to the array with played opus items
    [ playedOpusItems addObject:playedOpus ];
    
    // Notify the array controller that the contents has been changed
    [ _playedOpusItemsArrayController didChangeValueForKey:@"arrangedObjects" ];
}

// Show the played opus items window
- (void)showWindow {
    [super showWindow:self];
    
    // Check if the window is miniaturized
    if ([_playedOpusItemsWindow isMiniaturized]) {
        // Deminiaturize the windows
        [_playedOpusItemsWindow deminiaturize:self];
    }
    
    // Put the window in front of other windowss
    [_playedOpusItemsWindow orderFront:self];
}

@end
