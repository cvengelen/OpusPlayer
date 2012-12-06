//
//  Opus.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 06-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "Opus.h"

@implementation Opus

@synthesize composer;
@synthesize name;
@synthesize album;
@synthesize artist;
@synthesize tracks;

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
         [ name     isEqualToString:[ anObject name ] ] &&
         [ album    isEqualToString:[ anObject album ] ] &&
         [ artist   isEqualToString:[ anObject artist ] ] ) return YES;
    return NO;
}

@end
