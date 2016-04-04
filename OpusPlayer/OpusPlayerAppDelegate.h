//
//  OpusPlayerAppDelegate.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Opus.h"
#import "CurrentOpusDelegate.h"
#import "HIDRemote.h"

@interface OpusPlayerAppDelegate : NSObject < NSApplicationDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, NSComboBoxDelegate, NSWindowDelegate, CurrentOpusDelegate, HIDRemoteDelegate >

@property (readwrite) NSMutableArray* opusItems;
@property (readwrite) NSTimeInterval currentOpusCurrentTime;

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSArrayController *arrayController;
@property (weak) IBOutlet NSTableView *playlistTableView;

- (IBAction)playPreviousOpusPart:(id)sender;
- (IBAction)playOrPause:(id)sender;
- (IBAction)playNextOpusPart:(id)sender;
- (IBAction)playNextOpus:(id)sender;
- (IBAction)shuffleOpusItemsFromPlaylist:(id)sender;
- (IBAction)setCurrentTime:(NSSlider *)sender;

@property (weak) IBOutlet NSComboBox *composers;
@property (weak) IBOutlet NSComboBox *artists;
@property (weak) IBOutlet NSTextField *selectItems;

@property (weak) IBOutlet NSButton *previousOpusPartButton;
@property (weak) IBOutlet NSButton *playOrPauseButton;
@property (weak) IBOutlet NSButton *nextOpusPartButton;
@property (weak) IBOutlet NSButton *nextOpusButton;
@property (weak) IBOutlet NSButton *shuffleButton;

@property (weak) IBOutlet NSTextField *composerOpus;
@property (weak) IBOutlet NSTextField *opusPart;
@property (weak) IBOutlet NSTextField *artist;
@property (weak) IBOutlet NSSlider *currentTimeSlider;

@property (weak) IBOutlet NSBox *fullScreenBox;
@property (weak) IBOutlet NSTextField *fullScreenOpusPart;
@property (weak) IBOutlet NSTextField *fullScreenArtist;
@property (weak) IBOutlet NSTextField *fullScreenTime;
@property (weak) IBOutlet NSTextField *fullScreenComposerOpus;

- (IBAction)composersEndEditing:(NSComboBox *)sender;
- (IBAction)artistsEndEditing:(NSComboBox *)sender;

@property (weak) IBOutlet NSWindow *testFullScreenWindow;
@property (weak) IBOutlet NSBox *testFullScreenBox;

@end
