//
//  FullScreenViewController.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 30-03-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FullScreenViewController : NSViewController

@property (weak) IBOutlet NSBox       *textBox;
@property (weak) IBOutlet NSTextField *opusPartTextField;
@property (weak) IBOutlet NSTextField *artistTextField;
@property (weak) IBOutlet NSTextField *ComposerOpusTextField;

@property (weak) IBOutlet NSTextField *timeTextField;

-(void)applicationWillTerminate;

-(void)windowDidEnterFullScreen;
-(void)windowDidExitFullScreen;

-(void)setStringComposerOpus:(NSString *)aComposerOpus;
-(void)setStringArtist:(NSString *)anArtist;
-(void)setStringOpusPart:(NSString *)anOpusPart;

@end
