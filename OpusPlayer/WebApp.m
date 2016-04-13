//
//  WebApp.m
//  OpusPlayer
//
//  http://webappkit.org/
//  Uses WebAppKit framework
//
//  Created by Chris van Engelen on 12-04-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import "WebApp.h"

@implementation WebApp

static NSString *composerOpus;
static NSString *opusPart;
static NSString *artist;

// The delegate
static NSObject<WebAppDelegate>* delegate;

- (id)init {
    if ((self = [super init])) {
        [self addRouteSelector:@selector(index) HTTPMethod:@"GET" path:@"/"];
        [self addRouteSelector:@selector(handlePost:) HTTPMethod:@"POST" path:@"/*"];
        NSLog(@"Web Server initialised");
    }
    return self;
}

- (id)index {
    if (WAGetDevelopmentMode()) NSLog(@"Web Server request for index");
    
    // Use template index.wat from Resources
    WATemplate *template = [WATemplate templateNamed:@"index"];
    [template setValue:composerOpus forKey:@"composerOpus"];
    [template setValue:opusPart forKey:@"opusPart"];
    [template setValue:artist forKey:@"artist"];
    return template;
}


- (id)handlePost:(NSString*)name {
    if (WAGetDevelopmentMode()) NSLog(@"Web Server POST request: %@", name);
    
    // Issue request to delegate, as set in the action attribute of the form
    if ([name isEqualToString:@"playOrPause"]) [delegate webAppPlayOrPause];
    else if ([name isEqualToString:@"playNextOpus"]) [delegate webAppPlayNextOpus];
    
    // Return the original template
    return [self index];
}

+ (void)setComposerOpus:(NSString *)aComposerOpus {
    composerOpus = aComposerOpus;
}

+ (void)setOpusPart:(NSString *)anOpusPart {
    opusPart = anOpusPart;
}

+ (void)setArtist:(NSString *)anArtist {
    artist = anArtist;
}

+ (void)setDelegate:(NSObject<WebAppDelegate>*)aDelegate {
    delegate = aDelegate;
}

@end
