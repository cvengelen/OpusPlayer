//
//  OpusPlayerAppDelegate.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Opus.h"
#import "CurrentOpus.h"

@interface OpusPlayerAppDelegate : NSObject <NSApplicationDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, CurrentOpusDelegate>
{
    // The complete iTuns music dictionary (all 10 Mb)
    NSDictionary* iTunesMusicDictionary;

    // All child playlists of a parent playlist, key is the persistent ID of the parent playlist
    NSMutableDictionary* childPlaylistsOfParent;

    // All playlists which do not have a parent playlist
    NSMutableArray* rootPlaylists;
    
    // All opus items of the selected playlist
    NSMutableArray* opusItems;

    // Current playing opus item
    CurrentOpus* currentOpus;

    // All previously played opus items
    NSMutableArray* playedOpusItems;

    // Full screen timer
    NSTimer* fullScreenTimer;

    int fullScreenBoxXIncr;
    int fullScreenBoxYIncr;
    int fullScreenTimeYIncr;
}

@property (readwrite) NSMutableArray* opusItems;
@property (readwrite) NSMutableArray* playedOpusItems;

@property (assign) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSArrayController *arrayController;
@property (weak) IBOutlet NSTableView *playlistTableView;
@property (weak) IBOutlet NSArrayController *playedOpusItemsArrayController;

- (IBAction)playPreviousOpusPart:(id)sender;
- (IBAction)playOrPause:(id)sender;
- (IBAction)playNextOpusPart:(id)sender;
- (IBAction)playNextOpus:(id)sender;
- (IBAction)shuffleButton:(id)sender;

@property (weak) IBOutlet NSButton *previousOpusPartButton;
@property (weak) IBOutlet NSButton *playOrPauseButton;
@property (weak) IBOutlet NSButton *nextOpusPartButton;
@property (weak) IBOutlet NSButton *nextOpusButton;
@property (weak) IBOutlet NSButton *shuffleButton;

@property (weak) IBOutlet NSTextField *composerOpus;
@property (weak) IBOutlet NSTextField *opusPart;
@property (weak) IBOutlet NSTextField *artist;

@property (weak) IBOutlet NSBox *fullScreenBox;
@property (weak) IBOutlet NSTextField *fullScreenOpusPart;
@property (weak) IBOutlet NSTextField *fullScreenArtist;
@property (weak) IBOutlet NSTextField *fullScreenTime;
@property (weak) IBOutlet NSTextField *fullScreenComposerOpus;

@end
