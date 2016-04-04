//
//  PlayedOpusItems.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//
//  The played opus items window does not have any user input, and therefore cannot become a main window
//

#import "PlayedOpusItemsWindowController.h"
#import "PlayedOpus.h"

@implementation PlayedOpusItemsWindowController {

    // All previously played opus items
    NSMutableArray *playedOpusItems;
}

@synthesize playedOpusItems;

- (id)init {

    self = [super initWithWindowNibName:@"PlayedOpusItemsWindow"];
    if ( self )
    {
        // Initialise the array with the played opus items
        playedOpusItems = [ NSMutableArray array ];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Make it possible to close the window (this is not default)
    // The window can be shown with the menu item "Played opus items"
    _playedOpusItemsWindow.styleMask |= NSClosableWindowMask;
}

- (void)addCurrentOpus:(CurrentOpus *)currentOpus {
    // Make a new played opus item for the current opus
    PlayedOpus* playedOpus = [PlayedOpus new];
    playedOpus.opus = currentOpus.opus;
    playedOpus.atDate = currentOpus.startsPlayingDate;
    
    // Use NSCalendar and NSDateComponents to convert the duration in a string hours:minutes:seconds
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits fromDate:currentOpus.startsPlayingDate  toDate:[ NSDate date ]  options:0 ];
    playedOpus.forTime = [ NSString stringWithFormat:@"%02ld:%02ld:%02ld", [ timeComponents hour ], [ timeComponents minute ], [ timeComponents second ] ];

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
