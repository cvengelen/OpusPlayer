//
//  WebApp.h
//  http://webappkit.org/
//  Uses WebAppKit framework
//
//  OpusPlayer
//
//  Created by Chris van Engelen on 12-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import <WebAppKit/WebAppKit.h>
#import "WebAppDelegate.h"

@interface WebApp : WAApplication

+ ( void )setComposerOpus:( NSString* )aComposerOpus;
+ ( void )setOpusPart:( NSString* )anOpusPart;
+ ( void )setArtist:( NSString* )anArtist;
+ ( void )setDelegate:( NSObject< WebAppDelegate >* )aDelegate;

@end