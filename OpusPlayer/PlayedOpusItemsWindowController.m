//
//  PlayedOpusItems.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import "PlayedOpusItems.h"

@implementation PlayedOpusItems {

    // All previously played opus items
    NSMutableArray *playedOpusItems;
}

@synthesize playedOpusItems;

- ( id )initWithPlayedOpusItems:(NSMutableArray *)aPlayedOpusItems {

    self = [ super initWithWindowNibName:@"PlayedOpusItems" ];
    if ( self )
    {
        // Initialise the array with the played opus items
        // playedOpusItems = [ NSMutableArray arrayWithArray:aPlayedOpusItems ];
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void) addPlayedOpus:(PlayedOpus*)playedOpus {
    // Notify the array controller that the contents will be changed
    [ _playedOpusItemsArrayController willChangeValueForKey:@"arrangedObjects" ];
    
    // Add the played opus item to the array with played opus items
    [ playedOpusItems addObject:playedOpus ];
    
    // Notify the array controller that the contents has been changed
    [ _playedOpusItemsArrayController didChangeValueForKey:@"arrangedObjects" ];
}

@end
