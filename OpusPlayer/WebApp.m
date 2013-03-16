//
//  WebApp.m
//  http://webappkit.org/
//  Uses WebAppKit framework
//
//  Used by Chris van Engelen on 15-03-2013
//  Copyright (c) 2013 Chris van Engelen. All rights reserved.
//

#import "WebApp.h"

@implementation WebApp

static NSString *composerOpus;
static NSString *opusPart;
static NSString *artist;

- (id)init
{
	if ( ( self = [ super init ] ) )
    {
		[ self addRouteSelector:@selector( index ) HTTPMethod:@"GET" path:@"/" ];
        NSLog( @"Web Server initialised" );
	}
	return self;
}


- (id)index
{
    // NSLog( @"Web Server request for index" );
    
    // Use template index.wat from Resources
	WATemplate *template = [ WATemplate templateNamed:@"index" ];
	[ template setValue:composerOpus forKey:@"composerOpus" ];
	[ template setValue:opusPart forKey:@"opusPart" ];
	[ template setValue:artist forKey:@"artist" ];
	return template;
}

+ ( void )setComposerOpus:( NSString * )aComposerOpus
{
    composerOpus = aComposerOpus;
}

+ ( void )setOpusPart:( NSString * )anOpusPart
{
    opusPart = anOpusPart;
}

+ ( void )setArtist:( NSString * )anArtist
{
    artist = anArtist;
}

@end