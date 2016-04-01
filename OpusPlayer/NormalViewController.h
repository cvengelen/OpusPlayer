//
//  NormalViewController.h
//  OpusPlayer
//
//  Created by Chris van Engelen on 30-03-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NormalViewController : NSViewController <NSOutlineViewDelegate, NSOutlineViewDataSource, NSTableViewDelegate, NSComboBoxDelegate>

@property (readwrite) NSMutableArray *opusItems;

@property (weak) IBOutlet NSOutlineView     *playListsOutlineView;
@property (weak) IBOutlet NSArrayController *playListArrayController;
@property (weak) IBOutlet NSTableView       *playlistTableView;

@property (weak) IBOutlet NSComboBox *composersComboBox;
@property (weak) IBOutlet NSComboBox *artistsComboBox;
@property (weak) IBOutlet NSTextField *selectItemsTextField;

@end
