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
    int trackNumber;
}

@property (readwrite) NSString* location;
@property (readwrite) int trackNumber;

@end
