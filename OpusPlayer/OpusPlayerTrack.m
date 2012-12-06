//
//  OpusPlayerTrack.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "OpusPlayerTrack.h"

@implementation OpusPlayerTrack

@synthesize composer;
@synthesize opus;
@synthesize name;
@synthesize album;
@synthesize artist;
@synthesize location;
@synthesize opusTracks;

-(id)init
{
    self = [ super init ];
    if ( self )
    {
        //
    }
    return self;
}

- (BOOL)isEqual:(id)anObject
{
    if ( [ composer isEqualToString:[ anObject composer ] ] &&
         [ opus isEqualToString:[ anObject opus ] ] &&
         [ album isEqualToString:[ anObject album ] ] &&
         [ artist isEqualToString:[ anObject artist ] ] ) return YES;
    return NO;
}

@end
