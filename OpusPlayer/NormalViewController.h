//
//  NormalViewController.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 30-03-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PlayedOpusItemsWindowController.h"
#import "FullScreenViewController.h"
#import "CurrentOpus.h"
#import "HIDRemote.h"
#import "WebAppDelegate.h"

@interface NormalViewController : NSViewController <NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, NSComboBoxDelegate, CurrentOpusDelegate, HIDRemoteDelegate,  WebAppDelegate>

// Initialise with the played opus items window controller and the full screen view controller
- (id)initWithPlayedOpusItemsWindowController:(PlayedOpusItemsWindowController *)thePlayedOpusItemsWindowController
              andWithFullScreenViewController:(FullScreenViewController *)theFullScreenViewController;

-(void)applicationWillTerminate;

// The array containing the collected opus items from a playlist
@property (readwrite) NSMutableArray *opusItems;

// The outline view with the iTunes playlists overview
@property (weak) IBOutlet NSOutlineView     *playListsOutlineView;

// The array controller with the opus items shown in the playlist table view
@property (weak) IBOutlet NSArrayController *playListArrayController;

// The table view with all opus items of the selected playlist
@property (weak) IBOutlet NSTableView       *playlistTableView;

// The combo box with all composers of the opus items in the playlist table view
@property (weak) IBOutlet NSComboBox *composersComboBox;

// The combo box with all artists of the opus items in the playlist table view
@property (weak) IBOutlet NSComboBox *artistsComboBox;
@property (weak) IBOutlet NSTextField *selectItemsTextField;

- (IBAction)composersEndEditing:(NSComboBox *)sender;
- (IBAction)artistsEndEditing:(NSComboBox *)sender;

@property (weak) IBOutlet NSButton *previousOpusPartButton;
@property (weak) IBOutlet NSButton *playOrPauseButton;
@property (weak) IBOutlet NSButton *nextOpusPartButton;
@property (weak) IBOutlet NSButton *nextOpusButton;
@property (weak) IBOutlet NSButton *shuffleButton;

- (IBAction)playPreviousOpusPart:(id)sender;
- (IBAction)playOrPause:(id)sender;
- (IBAction)playNextOpusPart:(id)sender;
- (IBAction)playNextOpus:(id)sender;
- (IBAction)shuffleOpusItemsFromPlaylist:(id)sender;
- (IBAction)setCurrentTime:(NSSlider *)sender;

@property (weak) IBOutlet NSTextField *composerOpus;
@property (weak) IBOutlet NSTextField *opusPart;
@property (weak) IBOutlet NSTextField *artist;

@property (weak) IBOutlet NSSlider *currentTimeSlider;

@property (readwrite) NSNumber *currentOpusCurrentTime;

@end
