//
//  Track.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 17-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "Track.h"

@implementation Track

@synthesize location;
@synthesize trackNumber;
@synthesize totalTime;

-( id )initWithLocation:( NSString* )aLocation withTrackNumber:( unsigned int )aTrackNumber withTotalTime:( unsigned long )aTotalTime
{
    self = [ super init ];
    if ( self )
    {
        location = aLocation;
        trackNumber = aTrackNumber;
        totalTime = aTotalTime;
    }
    return self;
}

@end
