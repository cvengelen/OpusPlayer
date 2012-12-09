//
//  PlayedOpus.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 09-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Opus.h"

@interface PlayedOpus : NSObject
{
    NSDate* atDate;
    NSString* forTime;
    Opus* opus;
}

@property (readwrite) NSDate* atDate;
@property (readwrite) NSString* forTime;
@property (readwrite) Opus* opus;

@end
