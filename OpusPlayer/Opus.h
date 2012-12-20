//
//  Opus.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 06-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Opus : NSObject
{
    NSString* composer;
    NSString* name;
    NSString* album;
    NSString* artist;
    
    // Dictionary holding the track locations with the trackname as key
    NSMutableDictionary* tracks;
}

@property (readwrite) NSString* composer;
@property (readwrite) NSString* name;
@property (readwrite) NSString* album;
@property (readwrite) NSString* artist;
@property (readwrite) NSMutableDictionary* tracks;

- ( id )initWithComposer:( NSString* )aComposer withArtist:( NSString* )anArtist withAlbum:( NSString* )anAlbum;
- ( BOOL )isEqual:( id )anObject;

@end
