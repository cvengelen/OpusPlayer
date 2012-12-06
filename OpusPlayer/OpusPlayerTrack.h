//
//  OpusPlayerTrack.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpusPlayerTrack : NSObject
{
    NSString* composer;
    NSString* opus;
    NSString* name;
    NSString* album;
    NSString* artist;
    NSString* location;
    // Dictionary holding the track locations with the trackname as key
    NSMutableDictionary* opusTracks;
}

@property (readwrite) NSString* composer;
@property (readwrite) NSString* opus;
@property (readwrite) NSString* name;
@property (readwrite) NSString* album;
@property (readwrite) NSString* artist;
@property (readwrite) NSString* location;
@property (readwrite) NSMutableDictionary* opusTracks;

- (BOOL)isEqual:(id)anObject;

@end
