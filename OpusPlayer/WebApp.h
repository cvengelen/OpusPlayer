//
//  WebApp.h
//  http://webappkit.org/
//  Uses WebAppKit framework
//
//  Used by Chris van Engelen on 15-03-2013
//  Copyright (c) 2013 Chris van Engelen. All rights reserved.
//

#import <WebAppKit/WebAppKit.h>
#import "WebAppDelegate.h"

@interface WebApp : WAApplication

+ ( void )setComposerOpus:( NSString* )aComposerOpus;
+ ( void )setOpusPart:( NSString* )anOpusPart;
+ ( void )setArtist:( NSString* )anArtist;
+ ( void )setDelegate:( NSObject< WebAppDelegate >* )aDelegate;

@end