//
//  Track.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 17-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Track : NSObject
{
    NSString* location;
    unsigned int trackNumber;
    unsigned long totalTime;
}

@property (readwrite) NSString* location;
@property (readwrite) unsigned int trackNumber;
@property (readwrite) unsigned long totalTime;

- ( id )initWithLocation:( NSString* )aLocation withTrackNumber:( unsigned int )aTrackNumber withTotalTime:( unsigned long )aTotalTime;

@end
