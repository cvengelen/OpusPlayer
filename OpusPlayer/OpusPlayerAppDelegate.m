//
//  OpusPlayerAppDelegate.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

// Technical Q&A QA1340: Preventing sleep using I/O Kit:
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "OpusPlayerAppDelegate.h"
#import "CurrentOpus.h"
#import "Track.h"

#import "NormalViewController.h"
#import "FullScreenViewController.h"
#import "PlayedOpusItemsWindowController.h"

@implementation OpusPlayerAppDelegate
{
    // The complete iTunes music dictionary (all 10 Mb)
    NSDictionary* iTunesMusicDictionary;
    
    // All child playlists of a parent playlist, key is the persistent ID of the parent playlist
    NSMutableDictionary* childPlaylistsOfParent;
    
    // All playlists which do not have a parent playlist
    NSMutableArray* rootPlaylists;
    
    // All opus items of the selected playlist
    NSMutableArray* opusItems;
    
    // Current playing opus item
    CurrentOpus* currentOpus;

    // Current time of the currently playing opus track
    NSTimeInterval currentOpusCurrentTime;

    // All opus items played during the current shuffle, reset after all opus items have been played
    NSMutableArray* shuffledOpusItems;

    // Full screen timer
    NSTimer* fullScreenTimer;
    
    int fullScreenBoxXIncr;
    int fullScreenBoxYIncr;
    int fullScreenTimeYIncr;

    // Enabling and disabling sleep
    IOPMAssertionID assertionID;
    
    // Font size of the composerOpus string
    CGFloat composerOpusFontSize;
    CGFloat fullScreenComposerOpusFontSize;
    
    // Selected composer and artist
    NSString *selectedComposer;
    NSString *selectedArtist;

    // Normal and full screen view controllers
    NormalViewController *normalViewController;
    FullScreenViewController *fullScreenViewController;

    // Played Opus Items window controller
    PlayedOpusItemsWindowController *playedOpusItemsWindowController;
}

@synthesize opusItems;
@synthesize currentOpusCurrentTime;

- ( id )init
{
    self = [ super init ];
    if ( self )
    {
        // Get path to Music directy under user home
        NSString* iTunesMusicLibraryPath = [ NSSearchPathForDirectoriesInDomains( NSMusicDirectory, NSUserDomainMask, YES ) objectAtIndex:0 ];
        iTunesMusicLibraryPath = [ iTunesMusicLibraryPath stringByAppendingPathComponent:@"iTunes/iTunes Music Library" ];
        iTunesMusicLibraryPath = [ iTunesMusicLibraryPath stringByAppendingPathExtension:@"xml" ];
        
        // Check if file exists
        if ( ![ [ NSFileManager defaultManager ] fileExistsAtPath:iTunesMusicLibraryPath ] )
        {
            NSLog( @"iTunes music library not found at default location: %@", iTunesMusicLibraryPath );
            @throw [ NSException exceptionWithName:@"iTunesMusicLibraryNotFound" reason:[ NSString stringWithFormat:@"iTunes music library not found at default location: %@", iTunesMusicLibraryPath ] userInfo:nil ];

        }
 
        // Make a dictionary of the plist information in the iTunes Music dictionary file
        iTunesMusicDictionary = [ NSDictionary dictionaryWithContentsOfFile:iTunesMusicLibraryPath ];

        // Initialise the dictionary of child playlists of a parent playlist
        childPlaylistsOfParent = [ NSMutableDictionary dictionary ];

        // Initialise the array with root playlists (the playlists without a parent playlist)
        rootPlaylists = [ NSMutableArray array ];
        
        // Declaration of a function which tests if a playlist it the child of a given parent playlist
        BOOL ( ^testForPlaylistChild )( id playlistToTest, NSUInteger playlistToTestIndex, BOOL *stop );
        
        // Loop over all playlists in the iTunes music dictionary: this is an array under key Playlists
        NSArray* playlists = [ iTunesMusicDictionary valueForKey:@"Playlists" ];
        for ( NSDictionary* playlist in playlists )
        {
            // Check if the playlist has a Folder key, which indicates thay the playlist is the parent of child playlists
            if ( [ playlist valueForKey:@"Folder" ] )
            {
                NSString* playlistPersistentId = [ playlist valueForKey:@"Playlist Persistent ID" ];
                
                // Define a test block to look for child playlists for this parent playlist
                testForPlaylistChild = ^( id playlistToTest, NSUInteger playlistToTestIndex, BOOL *stop )
                {
                    NSString* parentPersistentId = [ playlistToTest valueForKey:@"Parent Persistent ID" ];
                    if ( [ parentPersistentId isEqualToString:playlistPersistentId ] ) return YES;
                    return NO;
                };
                
                NSIndexSet* indexSet = [ playlists indexesOfObjectsPassingTest:testForPlaylistChild ];
                NSArray* childPlayLists = [ playlists objectsAtIndexes:indexSet ];
                [ childPlaylistsOfParent setValue:childPlayLists forKey:playlistPersistentId ];
            }

            if ( ![ playlist objectForKey:@"Parent Persistent ID" ] )
            {
                [ rootPlaylists addObject:playlist ];
            }
        }
        
        // Initialise the array with the opus items in the playlist
        opusItems = [ NSMutableArray array ];
        
        // Initialise the array with the shuffled opus items
        shuffledOpusItems = [ NSMutableArray array ];

        // There is no current opus yet
        currentOpus = nil;
        currentOpusCurrentTime = 0;

        // Set the full screen data (to be moved to separate full screen class)
        fullScreenBoxXIncr = 2;
        fullScreenBoxYIncr = 2;
        fullScreenTimeYIncr = 2;
        
        // Initialise HID remote control
        if ([HIDRemote isCandelairInstallationRequiredForRemoteMode:kHIDRemoteModeExclusiveAuto])
        {
            // Candelair needs to be installed. Inform the user about it.
            NSLog( @"Candelair needs to be installed for handling remote control" );
        }
        else
        {
            // Start using HIDRemote ..
            HIDRemote *sHIDRemote = [HIDRemote sharedHIDRemote];
            if ([sHIDRemote startRemoteControl:kHIDRemoteModeExclusiveAuto])
            {
                [ sHIDRemote setDelegate:self ];
                NSLog( @"HID remote successfully started" );
            }
            else
            {
                NSLog( @"HID remote failure" );
            }
        }

        // Create instances for the full screen and normal view controllers
        fullScreenViewController = [[FullScreenViewController alloc] init];
        normalViewController = [[NormalViewController alloc] initWithOpusPlayerAppDelegate:self andWithFullScreenViewController:fullScreenViewController];

        // Create the played opus items window controller
        playedOpusItemsWindowController = [[PlayedOpusItemsWindowController alloc] init];
    }

    return self;
}

#pragma mark -
#pragma mark NSOutlineViewDataSource

////////////////////////////////////////////////////
// Playlist outline view data source methods:
// Input for the rows of the playlist outline view
////////////////////////////////////////////////////

// NSOutlineViewDataSource: Returns the child item at the specified index of a given item
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if ( item == nil ) return [ rootPlaylists objectAtIndex:index ];

    NSArray* childPlaylists = [ childPlaylistsOfParent objectForKey:[ item objectForKey:@"Playlist Persistent ID" ] ];
    if ( childPlaylists ) return [ childPlaylists objectAtIndex:index ];
    
    return nil;
}

// NSOutlineViewDataSource: Returns a Boolean value that indicates whether the a given item is expandable
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if ( [ item objectForKey:@"Folder" ] ) return YES;
    return NO;
}

// NSOutlineViewDataSource: Returns the number of child items encompassed by a given item
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if ( item == nil ) return [ rootPlaylists count ];

    NSArray* childPlaylists = [ childPlaylistsOfParent objectForKey:[ item objectForKey:@"Playlist Persistent ID" ] ];
    if ( childPlaylists ) return [ childPlaylists count ];

    return  0;
}

// NSOutlineViewDataSource: Invoked by outlineView to return the data object associated with the specified item
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    // NSLog( @"outline view retrieves item for item %@", [ item objectForKey:@"Name" ] );
    return [ item objectForKey:@"Name" ];
}

#pragma mark -
#pragma mark NSOutlineViewDelegate

////////////////////////////////////////////////////
// Delegate methods: handle notifications
////////////////////////////////////////////////////

// NSOutlineView: notification that selection changed
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // Get the selected row from the outline view
    long selectedRow = [ _outlineView selectedRow ];
    
    // Get the playlist dictionary from the selected row
    NSDictionary* playlist = [ _outlineView itemAtRow:selectedRow ];

    // Get all playlist tracks from the playlist
    NSArray* playlistTracks = [ playlist objectForKey:@"Playlist Items" ];

    // Get all tracks from the iTunes Music dictionary
    NSDictionary* tracks = [ iTunesMusicDictionary valueForKey:@"Tracks" ];

    // Save the sort descriptors currently in use
    NSArray* sortDescriptors = [ _arrayController sortDescriptors ];
    
    // Trigger KVC/KVO by posting KVO notification
    // See: http://stackoverflow.com/questions/1313709/kvc-kvo-and-bindings-why-am-i-only-receiving-one-change-notification
    [ _arrayController willChangeValueForKey:@"arrangedObjects" ];

    // Remove all selections from the array controller, because the new list of opus items may be smaller than the selected row.
    [ _arrayController removeSelectionIndexes:[ _arrayController selectionIndexes ] ];
    
    // Clear all items from the dictionary with opus items
    [ opusItems removeAllObjects ];

    // Loop over all tracks in the playlist
    for ( NSDictionary* playlistTrack in playlistTracks )
    {
        NSNumber* trackId= [ playlistTrack objectForKey:@"Track ID" ];
        NSDictionary* track = [ tracks objectForKey:[ trackId stringValue ] ];

        // Initialise an opus object with the composer, artist and album
        Opus* opus = [ [ Opus alloc ] initWithComposer:[ track valueForKey:@"Composer" ]
                                      withArtist:[ track valueForKey:@"Artist" ]
                                      withAlbum:[ track valueForKey:@"Album" ] ];
        
        // Get the full name of the track
        NSString* trackName = [ track valueForKey:@"Name" ];

        /////////////////////////////////////////////////////////////////////////////
        // First remove the name of the composer from the track name, if present
        /////////////////////////////////////////////////////////////////////////////
        
        // Search for the name of the composer at the start of the track, followed by a colon or dash, with possible spaces
        NSString* composerPrefix = [ NSString stringWithFormat:@"%@%@%@", @"^\\s*", opus.composer, @"\\s*[:-]\\s*" ];
        NSRange composerNameRange = [ trackName rangeOfString:composerPrefix options:NSRegularExpressionSearch ];

        // Check if the name of the composer is found at the start of the track name
        if ( composerNameRange.location != NSNotFound )
        {
            // Remove the composer name from the track name
            trackName = [ trackName substringFromIndex:composerNameRange.length ];
        }

        // Initialise an track object
        Track* opusTrack = [ [ Track alloc ] initWithLocation:[ track valueForKey:@"Location" ]
                                             withTrackNumber:[ [ track valueForKey:@"Track Number" ] intValue ]
                                             withTotalTime:[ [ track valueForKey:@"Total Time" ] longValue ] ];
  
        /////////////////////////////////////////////////////////////////////////////
        // Divide the track name in the opus name, and opus part names, divided by
        // either a colon or a dash, with possible spaces, and followed by at least one digit.
        /////////////////////////////////////////////////////////////////////////////

        // Try to find a divider string in the track name between an opus and an opus part:
        // a colon with possible spaces in front of the colon, and at least one space after the colon (see Haydn trios)
        // and followed by at least one digit (0-9). For example: Symfonie Nr. 5, Op. 67: 1. Allegro con brio
        NSString* opusDivider = @"\\s*:\\s+\\d";
        unsigned long opusDividerBacktrack = 1;
        NSRange opusDividerRange = [ trackName rangeOfString:opusDivider options:NSRegularExpressionSearch ];

        // Check if an opus divider string was not found in the track name
        if ( opusDividerRange.location == NSNotFound )
        {
            // Try again, now with a colon, followed by one word, like Variatie, Section, etc., and a digit.
            // Must come before check on dash, see Section 88 and Section 91 of Canto Ostinato, which contains both a colon and a dash.
            // Must only be done after an unsuccusfull search for a colon.
            opusDivider = @"\\s*:\\s+\\S+\\s\\d";
            opusDividerRange = [ trackName rangeOfString:opusDivider options:NSRegularExpressionSearch ];
            // Check if this opus divider string was found
            if ( opusDividerRange.location != NSNotFound )
            {
                // Determine the opus divider backtrack: the part of the divider string that is part of the track name
                
                // Get the divider string
                NSString *opusDividerString = [ trackName substringWithRange:opusDividerRange ];
                // Search for the colon and following space in the divider string
                NSString *colonDivider = @"\\s*:\\s+";
                NSRange colonRange = [ opusDividerString rangeOfString:colonDivider options:NSRegularExpressionSearch ];
                // The colon should always be found
                if ( colonRange.location != NSNotFound )
                {
                    // The part of the divider string which is included is the total lenght, minus the lenght of the colon string
                    opusDividerBacktrack = opusDividerRange.length - colonRange.length;
                }
            }
        }

        // Check if an opus divider string was not found in the track name
        if ( opusDividerRange.location == NSNotFound )
        {
            // Try again, now with a dash instead of a colon, followed by at least one space
            // Must only be done after an unsuccusfull search for a colon
            opusDivider = @"\\s*-\\s+\\d";
            opusDividerBacktrack = 1;
            opusDividerRange = [ trackName rangeOfString:opusDivider options:NSRegularExpressionSearch ];
        }
       
        // Check if an opus divider string was not found in the track name
        if ( opusDividerRange.location == NSNotFound )
        {
            // Try again, now only with a colon, followed by at least one space
            opusDivider = @"\\s*:\\s+";
            opusDividerBacktrack = 0;
            opusDividerRange = [ trackName rangeOfString:opusDivider options:NSRegularExpressionSearch ];
        }
        
        // Check if an opus divider string was not found in the track name
        if ( opusDividerRange.location == NSNotFound )
        {
            // This track does not seem to be part of an opus

            // Copy the full name and the track location
            opus.name = trackName;
            [ opus.tracks setObject:opusTrack forKey:trackName ];
            
            // Add the opus to the collection
            [ opusItems addObject:opus ];
            
            // Move to the next track in the playlist
            continue;
        }

        // Get the opus name: everything before the opus divider
        NSRange opusNameRange = { 0, opusDividerRange.location };
        opus.name = [ trackName substringWithRange:opusNameRange ];
    
        // Get the opus part name: everything after the opus divider, but with the digit in the opus divider
        NSString* partName = [ trackName substringFromIndex:( opusDividerRange.location + opusDividerRange.length - opusDividerBacktrack ) ];

        // Check if the collection of opus items already contains this opus
        // Note: this uses isEqual from Opus, so checks for composer, opus name, artist and album
        if ( [ opusItems containsObject:opus ] )
        {
            // Get the existing opus
            Opus* existingOpus = [ opusItems objectAtIndex:[ opusItems indexOfObject:opus ] ];

            // Add part name and location to the tracks dictionary of the existing opus
            [ existingOpus.tracks setObject:opusTrack forKey:partName ];

            // Move to the next track in the playlist
            continue;
        }

        // Add part name and location to the tracks dictionary of the new opus
        [ opus.tracks setObject:opusTrack forKey:partName ];

        // The opus is not yet in the collection of opus items: add the opus to the collection
        [ opusItems addObject:opus ];
    }

    NSLog( @"#opusItems: %ld from a total of %ld", [ opusItems count ], [ playlistTracks count ] );
    
    // Set the sort descriptors
    [ _arrayController setSortDescriptors:sortDescriptors ];

    // Remove the filter predicate if it was set: show all composers and artists
    [ _arrayController setFilterPredicate:nil ];

    // Remove the selected composer and artist, otherwise selecting a composer will reuse
    // the previously selected artist (and vice versa), giving unpredictable results
    selectedArtist = nil;
    selectedComposer = nil;
    [ _artists setStringValue:@"" ];
    [ _composers setStringValue:@"" ];

    // Trigger rearrangement of the array controller arranged objects according to the new content and sorting
    [ _arrayController rearrangeObjects ];
    
    // Trigger KVC/KVO by posting KVO notification
    [ _arrayController didChangeValueForKey:@"arrangedObjects" ];
    
    // Insert values for the composers combobox
    [ self setComboBox:_composers withProperty:@"composer" ];
    
    // Insert values for the artists combobox
    [ self setComboBox:_artists withProperty:@"artist" ];
    
    // Set the label before the composers and artists combo boxes only if both are enabled
    if ( [ _composers isEnabled ] && [ _artists isEnabled ] ) [ _selectItems setStringValue:@"Select composer/artist:" ];
    else [ _selectItems setStringValue:@"" ];

    // Check if the playlist tableview actually contains on or more opus items
    if ( [ _arrayController.arrangedObjects count ] > 0 )
    {
        // Enable playing random opus items from the playlist
        [ _shuffleButton setEnabled:YES ];
    
        // Enable playing a random opus item from the playlist
        [ _nextOpusButton setEnabled:YES ];
    }
    else
    {
        // No items in the playlist
        
        // Disable playing random opus items from the playlist
        [ _shuffleButton setEnabled:NO ];
        
        // Disable playing a random opus item from the playlist
        [ _nextOpusButton setEnabled:NO ];
    }
}

#pragma mark -
#pragma mark NSTableViewDelegate

// NSTableViewDelegate: Informs the delegate that the table view’s selection has changed
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    // Get the index of the selected row in the playlist tableview
    NSInteger selectedRowIndex = [ _playlistTableView selectedRow ];

    // Return if a selection has been removed, in which case the selected row is -1
    if ( selectedRowIndex < 0 ) return;
    
    // Check if there is already a current opus
    if ( currentOpus )
    {
        // Check if the current opus already equals the opus item at the selected index,
        // which means that the row is being automatically selected by playNextOpus.
        // In that case this method does not need to take any action.
        if ( [ currentOpus.opus isEqual:[ [ _arrayController arrangedObjects ] objectAtIndex:[ _playlistTableView selectedRow ] ] ] ) return;

        // NSLog( @"Selected play list row changed manually: stop playing current opus %@", currentOpus.opus.name );

        // Release the audio hardware
        [ currentOpus stopPlaying ];
    
        // update the played opus items
        [ self updatePlayedOpusItems ];
    }

    // Get the new selected opus item from the playlist table
    Opus* opus = [ [ _arrayController arrangedObjects ] objectAtIndex:[ _playlistTableView selectedRow ] ];
    if ( [ opus.tracks count ] == 0 )
    {
        NSLog( @"tracks empty" );
        return;
    }
    // NSLog( @"Selected play list row changed manually: start playing opus %@", opus.name );

    // Initialize a new current opus with the selected opus item
    // (let ARM delete the previous current opus)
    currentOpus = [ [ CurrentOpus alloc ] initWithOpus:opus andDelegate:self ];
    
    // Start playing the opus item
    [ currentOpus startPlaying ];
}

#pragma mark -
#pragma mark NSWindowDelegate

-( void )windowDidEnterFullScreen:( NSNotification* )notification
{
    NSWindow *window = ( NSWindow* )notification.object;
    if ( [ window.identifier isEqualToString:@"fullScreenWindow" ] )
    {
        // Set full screen time every 5 seconds (to be moved to separate full screen class)
        fullScreenTimer = [ NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(handleFullScreenTimer:) userInfo:nil repeats:YES ];

        // Hide the cursor. See "Controlling the Mouse Cursor"
        // (http://developer.apple.com/library/mac/#documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
        CGDisplayHideCursor( kCGDirectMainDisplay );

        // Clear the last cursor delta (now suddenly called Mouse?)
        int32_t deltaX, deltaY;
        CGGetLastMouseDelta( &deltaX, &deltaY );

        // Set the current time in the full screen
        [self setFullScreenTime ];

        // reasonForActivity is used by the system whenever it needs to tell
        // the user why the system is not sleeping (limited to 128 chararcers).
        CFStringRef reasonForActivity = CFSTR( "OpusPlayer Full Window is active" );
        
        IOReturn assertionCreateWithNameReturn = IOPMAssertionCreateWithName( kIOPMAssertionTypeNoDisplaySleep,
                                                                             kIOPMAssertionLevelOn, reasonForActivity, &assertionID );
        if ( assertionCreateWithNameReturn != kIOReturnSuccess )
        {
            NSLog( @"IOPMAssertionCreateWithName failed with error code %d", assertionCreateWithNameReturn );
        }
    } else if ( [ window.identifier isEqualToString:@"testFullScreenWindow" ] ) {
        NSLog( @"test full screen window did enter full screen" );
        [fullScreenViewController windowDidEnterFullScreen];
        NSView *view = [fullScreenViewController view];
        [_testFullScreenBox setContentView:view];
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    NSWindow *window = ( NSWindow* )notification.object;
    if ( [ window.identifier isEqualToString:@"fullScreenWindow" ] )
    {
        // Stop the full screen timer
        [ fullScreenTimer invalidate ];

        // Clear the time on the full screen window
        [ _fullScreenTime setStringValue:@"" ];

        // Display the cursor if it was not visible. See "Controlling the Mouse Cursor"
        // (http://developer.apple.com/library/mac/#documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
        if ( !( CGCursorIsVisible( ) ) ) CGDisplayShowCursor( kCGDirectMainDisplay );
        
        // Release the assertion, to enable the system to be able to sleep again
        IOReturn assertionCreateWithNameReturn = IOPMAssertionRelease( assertionID );
        if ( assertionCreateWithNameReturn != kIOReturnSuccess )
        {
            NSLog( @"IOPMAssertionRelease failed with error code %d", assertionCreateWithNameReturn );
        }
    } else if ( [ window.identifier isEqualToString:@"testFullScreenWindow" ] ) {
        NSLog( @"test full screen window did exit full screen" );
        [fullScreenViewController windowDidExitFullScreen];
        NSView *view = [normalViewController view];
        [_testFullScreenBox setContentView:view];
    }
}

-( void )toggleTestFullScreen {
    [_testFullScreenWindow toggleFullScreen:self];
}

-( void )setFullScreenTime
{
    // Use NSCalendar and NSDateComponents to convert the current time in a string hours:minutes
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits fromDate:[ NSDate date ] ];
    
    // Set the time on the full screen window
    [ _fullScreenTime setStringValue:[ NSString stringWithFormat:@"%02ld:%02ld", [ timeComponents hour ], [ timeComponents minute ] ] ]; 
}

- (void)handleFullScreenTimer:(NSTimer *)timer
{
    // Set the current time in the full screen
    [self setFullScreenTime ];
     
    // Get the frame of the box in the full screen window
    NSRect fullScreenBoxFrame = [ _fullScreenBox frame ];
    
    // Get the bounds of the parent view of the box
    NSRect fullScreenViewBounds = [ [ _fullScreenBox superview ] bounds ];
    
    // Determine the direction of the x increment of the box position in the full screen window
    if ( fullScreenBoxXIncr > 0 )
    {
        // Take care not to overwrite the timer at the left of the screen
        if ( ( fullScreenBoxFrame.origin.x + fullScreenBoxFrame.size.width + fullScreenBoxXIncr ) > ( fullScreenViewBounds.size.width - _fullScreenTime.frame.size.width ) ) fullScreenBoxXIncr = -fullScreenBoxXIncr;
    }
    else
    {
        if ( ( fullScreenBoxFrame.origin.x + fullScreenBoxXIncr ) < 0 ) fullScreenBoxXIncr = - fullScreenBoxXIncr;
    }
    
    // Determine the direction of the y increment of the box position in the full screen window
    if ( fullScreenBoxYIncr > 0 )
    {
        if ( ( fullScreenBoxFrame.origin.y + fullScreenBoxFrame.size.height + fullScreenBoxYIncr ) > fullScreenViewBounds.size.height ) fullScreenBoxYIncr = -fullScreenBoxYIncr;
    }
    else
    {
        if ( ( fullScreenBoxFrame.origin.y + fullScreenBoxYIncr ) < 0 ) fullScreenBoxYIncr = - fullScreenBoxYIncr;
    }
    
    // Move the box in the full screen window a bit
    fullScreenBoxFrame.origin.x += fullScreenBoxXIncr;
    fullScreenBoxFrame.origin.y += fullScreenBoxYIncr;
    [ _fullScreenBox setFrameOrigin:fullScreenBoxFrame.origin ];
    
    // Get the frame of the Time text label in the full screen window
    NSRect fullScreenTimeFrame = [ _fullScreenTime frame ];
    
    // Determine the direction of the y increment of the time label position in the full screen window
    if ( fullScreenTimeYIncr > 0 )
    {
        if ( ( fullScreenTimeFrame.origin.y + fullScreenTimeFrame.size.height + fullScreenTimeYIncr ) > fullScreenViewBounds.size.height ) fullScreenTimeYIncr = -fullScreenTimeYIncr;
    }
    else
    {
        if ( ( fullScreenTimeFrame.origin.y + fullScreenTimeYIncr ) < 0 ) fullScreenTimeYIncr = - fullScreenTimeYIncr;
    }
    
    // Move the time label in the full screen window a bit
    fullScreenTimeFrame.origin.y += fullScreenTimeYIncr;
    [ _fullScreenTime setFrameOrigin:fullScreenTimeFrame.origin ];

    // Get the last cursor delta
    int32_t deltaX, deltaY;
    CGGetLastMouseDelta( &deltaX, &deltaY );

    // Show the cursor if it is moving, else hide it again if it was visible
    if ( ( ( deltaX != 0 ) || ( deltaY != 0 ) ) && !( CGCursorIsVisible( ) ) ) { CGDisplayShowCursor( kCGDirectMainDisplay ); }
    else if ( ( deltaX == 0 ) && ( deltaY == 0 ) && CGCursorIsVisible( ) ) { CGDisplayHideCursor( kCGDirectMainDisplay ); }
}

#pragma mark -
#pragma mark NSApplicationDelegate

// NSApplicationDelegate: Sent by the default notification center after the application
// has been launched and initialized but before it has received its first event
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Disable all player buttons: there is nothing to play yet.
    [ _previousOpusPartButton setEnabled:NO ];
    [ _playOrPauseButton setEnabled:NO ];
    [ _nextOpusPartButton setEnabled:NO ];
    [ _nextOpusButton setEnabled:NO ];
    [ _shuffleButton setEnabled:NO ];
    
    // Set the default sorting of the play list tableview on composer, opus and artist (suitable for classical music)
    // Define the sort descriptors for composer, opus name (special) and artist
    NSSortDescriptor* composerSortDescriptor = [ NSSortDescriptor sortDescriptorWithKey:@"composer" ascending:YES ];
    // Use numeric search in opus name sort descriptor: numeric fields are sorted numerically (magically).
    NSSortDescriptor* opusNameSortDescription = [ NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES comparator:^(id name1, id name2) {
        return [ name1 compare:name2 options:NSNumericSearch ];
    } ];
    NSSortDescriptor* artistSortDescriptor   = [ NSSortDescriptor sortDescriptorWithKey:@"artist" ascending:YES ];
    
    // Sort the play list tableview on composer, opus name, and artist
    NSArray* playListSortDescriptors = [ NSArray arrayWithObjects:composerSortDescriptor, opusNameSortDescription, artistSortDescriptor, nil ];
    [ _arrayController setSortDescriptors:playListSortDescriptors ];

    // Set the minimum slider value
    _currentTimeSlider.minValue = 0;

    // Initialise the test full screen box with the normal container view
    [_testFullScreenBox setContentView:[normalViewController view]];
}

// NSApplicationDelegate: Sent by the default notification center immediately before the application terminates
-( void )applicationWillTerminate:(NSNotification *)notification
{
    // Release the audio hardware
    if ( currentOpus ) [ currentOpus stopPlaying ];

    // Stop the full screen timer
    if ( fullScreenTimer ) [ fullScreenTimer invalidate ];
}

#pragma mark -
#pragma mark Button actions

/////////////////////////
// Button actions
/////////////////////////

// Play the previous opus part
- (IBAction)playPreviousOpusPart:(id)sender
{
    // play the previous opus part of the current opus
    [ currentOpus playPreviousOpusPart ];
}

// Play or pause
- (IBAction)playOrPause:(id)sender
{
    // Play the current opus if paused, or pause if playing
    [ currentOpus playOrPause ];
}

// Play the next opus part
- (IBAction)playNextOpusPart:(id)sender
{
    // play the next opus part of the current opus
    [ currentOpus playNextOpusPart ];
}

// Play the next opus
- (IBAction)playNextOpus:(id)sender
{
    // Check if there is a current opus
    if ( currentOpus )
    {
        // stop playing the current opus
        [ currentOpus stopPlaying ];
    
        // update the played opus items
        [ self updatePlayedOpusItems ];

        // Add the opus to the list of shuffled opus items
        [ shuffledOpusItems addObject:currentOpus ];
    }
    
    // Get a random new opus from the opus items in the selected playlist,
    // with the played opus items removed
    
    // Initialise an array with the opus items in the playlist: the arranged objects from the array controller
    NSMutableArray* remainingOpusItems = [ NSMutableArray arrayWithArray:[ _arrayController arrangedObjects ] ];
    NSLog( @"#opus items in playlist: %ld", [ remainingOpusItems count ] );

    // Remove the already shuffled items from the playlist
    for ( CurrentOpus* shuffledOpusItem in shuffledOpusItems )
    {
        [ remainingOpusItems removeObject:shuffledOpusItem.opus ];
    }
    NSLog( @"#remaining opus items in playlist after removing shuffled opus items: %ld", [ remainingOpusItems count ] );

    // Check if all items in the playlist have been played
    if ( [ remainingOpusItems count ] == 0 )
    {
        // Use all items again
        [ shuffledOpusItems removeAllObjects ];
        NSLog( @"restart shuffle: list of shuffled opus items cleared" );

        remainingOpusItems = [ NSMutableArray arrayWithArray:[ _arrayController arrangedObjects ] ];
        NSLog( @"#opus items in playlist: %ld", [ remainingOpusItems count ] );
    }

    // Try removing the composer from the remaining list of opus items
    NSPredicate* predicate = [ NSPredicate predicateWithFormat:@"!( composer like[cd] %@ )", currentOpus.opus.composer ];
    NSArray* remainingOpusItemsAfterRemovingComposer = [ remainingOpusItems filteredArrayUsingPredicate:predicate ];
    NSLog( @"#filtered remaining opus items after removing composer %@: %ld",
          currentOpus.opus.composer, [ remainingOpusItemsAfterRemovingComposer count ] );

    // Check if there are opus items left after removing the opus items with the same composer
    if ( [ remainingOpusItemsAfterRemovingComposer count ] != 0 )
    {
        // Continue with the filtered list of opus items
        remainingOpusItems = [ NSMutableArray arrayWithArray:remainingOpusItemsAfterRemovingComposer ];
    }

    // Try removing the artist from the filtered remaining list of opus items
    predicate = [ NSPredicate predicateWithFormat:@"!( artist like[cd] %@ )", currentOpus.opus.artist ];
    NSArray* remainingOpusItemsAfterRemovingArtist = [ remainingOpusItems filteredArrayUsingPredicate:predicate ];
    NSLog( @"#filtered remaining opus items after removing artist %@: %ld",
          currentOpus.opus.artist, [ remainingOpusItemsAfterRemovingArtist count ] );

    // Check if there are opus items left after removing the opus items with the same artist
    if ( [ remainingOpusItemsAfterRemovingArtist count ] != 0 )
    {
        // Continue with the filtered list of opus items
        remainingOpusItems = [ NSMutableArray arrayWithArray:remainingOpusItemsAfterRemovingArtist ];
    }

    // Use a random index to get an opus item from the list of remaining opus items
    int remainingOpusItemsIndex = arc4random( ) % [ remainingOpusItems count ];
    Opus* opus = [ remainingOpusItems objectAtIndex:remainingOpusItemsIndex ];
    if ( [ opus.tracks count ] == 0 )
    {
        NSLog( @"tracks empty" );
        return;
    }
    NSLog( @"Play next opus %@", opus.name );
    
    // Initialize a new current opus item
    // (let ARM delete the previous current opus)
    currentOpus = [ [ CurrentOpus alloc ] initWithOpus:opus andDelegate:self ];
    
    // Start playing the current opus item
    [ currentOpus startPlaying ];

    // Set the selected opus item in the play list table view to the index of the selected opus item in the array of arranged objects.
    // This must be done via the array controller (because of sorting the input array by the array controller)
    [ _arrayController setSelectionIndex:[ [ _arrayController arrangedObjects ] indexOfObject:opus ] ];

    // Make sure the selected row in the play list table view is visible
    [ _playlistTableView scrollRowToVisible:[ _playlistTableView selectedRow ] ];
}

// Shuffle is activated or deactivated
- (IBAction)shuffleOpusItemsFromPlaylist:(id)sender
{
    // Check if there is no current opus playing, and shuffle is activated
    if ( ( ( currentOpus == nil ) || !currentOpus.isPlaying ) &&
        ( [ _shuffleButton state ] == NSOnState ) )
    {
        // Shuffle is activated, and there is no current opus item playing: start playing a randomly chosen opus.
        // If an opus is finished, continue with another randomly chosen opus.
        // See CurrentOpusDelegate method opusDidFinishPlaying
        
        // Play an opus item, chosen randomly
        [ self playNextOpus:nil ];
    }
}

- (IBAction)setCurrentTime:(NSSlider *)currentTimeSlider
{
    [ currentOpus setCurrentTime:[ currentTimeSlider floatValue ] ];
}

/////////////////////////////
// Helper methods
/////////////////////////////

#pragma mark -
#pragma mark Helper methods

// Update the played opus items
- (void)updatePlayedOpusItems
{
    PlayedOpus* playedOpus = [ [ PlayedOpus alloc ] init ];
    playedOpus.opus = currentOpus.opus;
    playedOpus.atDate = currentOpus.startsPlayingDate;
    
    // Use NSCalendar and NSDateComponents to convert the duration in a string hours:minutes:seconds
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits fromDate:currentOpus.startsPlayingDate  toDate:[ NSDate date ]  options:0 ];
    playedOpus.forTime = [ NSString stringWithFormat:@"%02ld:%02ld:%02ld", [ timeComponents hour ], [ timeComponents minute ], [ timeComponents second ] ];

    [self addPlayedOpus:playedOpus];
}

- (void) addPlayedOpus:(PlayedOpus *)playedOpus {
    // Send the played opus item to the played opus items window controller
    [playedOpusItemsWindowController addPlayedOpus:playedOpus];
}

// Set a string in a text field, adjusting the font size if the string does not fit
-( CGFloat )setStringValue:( NSString* )aString onTextField:( NSTextField* )aTextField withMaximumFontSize:(CGFloat)maximumFontSize andMinimumFontSize:(CGFloat)minimumFontSize
{
    NSFont* textFieldFont = [ aTextField font ];
    NSDictionary* fontAttributes;
    NSSize stringSize;
    // Use a generous margin in the text field width to allow for word wrap (e.g., "blaasinstrumenten" in Mozart's Gran Partita)
    CGFloat textFieldWidth = 0.8 * aTextField.frame.size.width;
    CGFloat textFieldHeight = aTextField.frame.size.height;
    CGFloat fontPointSize = maximumFontSize;
    
    // Start at the maximum allowed font size, but don't go below the minimum font size
    while ( fontPointSize > minimumFontSize )
    {
        // Set the font size.
        textFieldFont = [ NSFont fontWithName:textFieldFont.fontName size:fontPointSize ];
        // Make a dictionary of the font with as key the font name
        fontAttributes = [ [ NSDictionary alloc ] initWithObjectsAndKeys:textFieldFont, NSFontAttributeName, nil];
        // Get the size of the string with the font attributes
        stringSize = [ aString sizeWithAttributes:fontAttributes ];
        int nLines = textFieldHeight / stringSize.height;
        // Break out of the loop if the string fits in the size of the text field, allowing for a little margin
        if ( stringSize.width < (nLines * textFieldWidth ) ) break;
        // Try again with a smaller font size
        fontPointSize -= 1;
    }
    
    // Set the resulting font in the text field
    [ aTextField setFont:textFieldFont ];

    // Set the string in the text field
    [ aTextField setStringValue:aString ];

    // Return the selected font size
    return fontPointSize;
}

#pragma mark -
#pragma mark CurrentOpusDelegate

/////////////////////////////////////////////////////////////////////////////
// Current Opus Delegate methods
/////////////////////////////////////////////////////////////////////////////

// Notification from the current opus that it did finish playing the complete opus (all tracks)
-( void )opusDidFinishPlaying
{
    // Play the next randomly chosen opus if the shuffle button is on
    // (this is the same as activating the "Next opus" button)
    if ( [ _shuffleButton state ] == NSOnState ) [ self playNextOpus:nil ];
}

// Notification from the current opus with the string value for composerOpus
-( void )setStringComposerOpus:( NSString* )aComposerOpus
{
    composerOpusFontSize = [ self setStringValue:aComposerOpus onTextField:_composerOpus withMaximumFontSize:20.0 andMinimumFontSize:8.0 ];

    fullScreenComposerOpusFontSize = [ self setStringValue:aComposerOpus onTextField:_fullScreenComposerOpus withMaximumFontSize:50.0 andMinimumFontSize:10.0 ];
}

// Notification from the current opus with the string value for artist
-( void )setStringArtist:( NSString* )anArtist
{
    // Use the font size selected for the composerOpus output as maximum,
    // to avoid that the font used for the artist is larger that the font for the opus
    [ self setStringValue:anArtist onTextField:_artist withMaximumFontSize:composerOpusFontSize andMinimumFontSize:8.0 ];
    [ self setStringValue:anArtist onTextField:_fullScreenArtist withMaximumFontSize:fullScreenComposerOpusFontSize andMinimumFontSize:10.0 ];
}

// Notification from the current opus with the string value for opusPart
-( void )setStringOpusPart:( NSString* )anOpusPart
{
    // Use the font size selected for the composerOpus output as maximum,
    // to avoid that the font used for the opus part is larger that the font for the opus
    [ self setStringValue:anOpusPart onTextField:_opusPart withMaximumFontSize:composerOpusFontSize andMinimumFontSize:8.0 ];
    [ self setStringValue:anOpusPart onTextField:_fullScreenOpusPart withMaximumFontSize:fullScreenComposerOpusFontSize andMinimumFontSize:12.0 ];
}

// Notification from the current opus of the opus track duration
-( void )setOpusPartDuration:( NSTimeInterval )duration
{
    _currentTimeSlider.maxValue = duration;
}

// Notify the delegate of the current time of a track
-( void )setOpusPartCurrentTime:( NSTimeInterval )currentTime
{
    // Use the current opus current time setter method to allow for a key-value observer to pick up the value (i.e., the slider)
    [ self setCurrentOpusCurrentTime:currentTime ];
}


#pragma mark -
#pragma mark NSComboBoxDelegate

/////////////////////////////////////////////////////////////////////////////
// Combobox delegate
/////////////////////////////////////////////////////////////////////////////

-( void )setComboBox:( NSComboBox* )aComboBox withProperty:( NSString* )aProperty
{
    NSMutableArray *comboBoxItems = [ NSMutableArray array ];
    for ( Opus *opusItem in _arrayController.arrangedObjects )
    {
        if ( ![ comboBoxItems containsObject:[ opusItem valueForKey:aProperty ] ] ) [ comboBoxItems addObject:[ opusItem valueForKey:aProperty ] ];
    }
    [ aComboBox removeAllItems ];
    if ( [ comboBoxItems count ] > 0 )
    {
        [ comboBoxItems sortUsingComparator:^(id property1, id property2) { return [ property1 compare:property2 ]; } ];
        [ comboBoxItems insertObject:@"All" atIndex:0 ];
        [ aComboBox addItemsWithObjectValues:comboBoxItems ];
        [ aComboBox setEnabled:YES ];
    }
    else
    {
        [ aComboBox setEnabled:NO ];
    }
    [ aComboBox reloadData ];
}

// Filter the opus items in the playlist on the current settings of selected composer, and selected artist, if any
-( void )filterPlaylistOnComposerAndArtist
{
    // Remove the current predicate
    [ _arrayController setFilterPredicate:nil ];

    // With composer and artist not selected, the predicate is removed by setting it to nil;
    NSPredicate *predicate = nil;
    
    if ( ( selectedArtist != nil ) && ( selectedComposer != nil ) )
    {
        // Use the selected composer and artist as a selection on the opus items in the playlist
        if ( [ selectedComposer isEqualToString:@"" ] ) predicate = [ NSPredicate predicateWithFormat:@"( composer == '' ) AND ( artist like[cd] %@ )", selectedArtist ];
        else predicate = [ NSPredicate predicateWithFormat:@"( composer like[cd] %@ ) AND ( artist like[cd] %@ )", selectedComposer, selectedArtist ];
    }
    else if ( selectedArtist != nil )
    {
        // Use the selected artist as a selection on the opus items in the playlist
        if ( [ selectedArtist isEqualToString:@"" ] ) predicate = [ NSPredicate predicateWithFormat:@"artist == ''" ];
        else predicate = [ NSPredicate predicateWithFormat:@"artist like[cd] %@", selectedArtist ];
        
    }
    else if ( selectedComposer != nil )
    {
        // Use the selected composer as a selection on the opus items in the playlist
        if ( [ selectedComposer isEqualToString:@"" ] ) predicate = [ NSPredicate predicateWithFormat:@"composer == ''" ];
        else predicate = [ NSPredicate predicateWithFormat:@"composer like[cd] %@", selectedComposer ];
    }
    
    // Filter the arranged objects in the playlist view array controller with the predicate (nil removes the predicate)
    [ _arrayController setFilterPredicate:predicate ];
    NSLog( @"#arranged objects with predicate: %ld", [ _arrayController.arrangedObjects count ] );
    
    // Do not change combobox list if there are no items in the filtered playlist
    if ( [ _arrayController.arrangedObjects count ] == 0 ) return;
    
    // Let the composer combobox only show the selected composer, and a blank item to get back to all composers
    [ self setComboBox:_composers withProperty:@"composer" ];
    
    // Let the artist combobox only show the selected artist, and a blank item to get back to all artists
    [ self setComboBox:_artists withProperty:@"artist" ];
}

-( void )comboBoxSelectionDidChange:(NSNotification *)aNotification
{
    NSComboBox* comboBox = ( NSComboBox* )aNotification.object;
    NSString *selectedItem = [ comboBox objectValueOfSelectedItem ];

    // Return immediately when no item is selected
    if ( selectedItem == nil ) return;
    
    // Clear any possible typed in value
    [ comboBox setStringValue:@"" ];

    NSLog( @"comboBoxSelectionDidChange - %@ combobox selection did change to %@", comboBox.identifier, selectedItem );

    if ( [ comboBox.identifier isEqualToString:@"composers" ] )
    {
        // If "All" is selected then remove the selected composer,
        // else set the selected composer to the selected combobox item
        if ([ selectedItem isEqualToString:@"All" ] ) selectedComposer = nil;
        else selectedComposer = selectedItem;
    }
    else if ( [ comboBox.identifier isEqualToString:@"artists" ] )
    {
        // If "All" is selected then remove the selected artist,
        // else set the selected artist to the selected combobox item
        if ([ selectedItem isEqualToString:@"All" ] ) selectedArtist = nil;
        else selectedArtist = selectedItem;
    }

    // Filter the playlist
    [ self filterPlaylistOnComposerAndArtist ];
}

- (IBAction)composersEndEditing:(NSComboBox *)sender
{
    NSString *selectedItem = [ sender stringValue ];
    // NSLog( @"composersEndEditing - composers combobox selection did change to %@", selectedItem );
    
    // Return immediately when no item is selected,
    // or when item is selected with combobox selection, in which case the textfield is empty
    if ( !selectedItem || [ selectedItem isEqualToString:@"" ] ) return;
    
    // If "All" (case insensitive) is entered then remove the selected composer,
    // else set the selected composer to the entered string
    if ( [ [ selectedItem lowercaseString ] isEqualToString:@"all" ] ) selectedComposer = nil;
    else selectedComposer = selectedItem;

    // Filter the playlist
    [ self filterPlaylistOnComposerAndArtist ];
}

- (IBAction)artistsEndEditing:(NSComboBox *)sender
{
    NSString *selectedItem = [ sender stringValue ];
    // NSLog( @"artistsEndEditing - artists combobox selection did change to %@", selectedItem );
    
    // Return immediately when no item is selected,
    // or when item is selected with combobox selection, in which case the textfield is empty

    if ( !selectedItem || [ selectedItem isEqualToString:@"" ] ) return;
    
    // If "All" (case insensitive) is entered then remove the selected artist,
    // else set the selected artist to the entered string
    if ( [ [ selectedItem lowercaseString ] isEqualToString:@"all" ] ) selectedArtist = nil;
    else selectedArtist = selectedItem;

    // Filter the playlist
    [ self filterPlaylistOnComposerAndArtist ];
}

#pragma mark -
#pragma mark Menu

- (IBAction)showPlayedOpusItems:(NSMenuItem *)sender {
    [playedOpusItemsWindowController showWindow];
}

#pragma mark -
#pragma mark HIDRemote

/////////////////////////////////////////////////////////////////////////////
// HID delegate
/////////////////////////////////////////////////////////////////////////////

- (void)hidRemote:(HIDRemote *)hidRemote eventWithButton:(HIDRemoteButtonCode)buttonCode isPressed:(BOOL)isPressed fromHardwareWithAttributes:(NSMutableDictionary *)attributes
{
	// NSLog(@"%@: Button with code %d %@", hidRemote, buttonCode, (isPressed ? @"pressed" : @"released"));

    // Only react to button pressed
    if ( ! isPressed ) return;
    
    switch (buttonCode)
    {
        case kHIDRemoteButtonCodePlay:
        case kHIDRemoteButtonCodeCenter:
            if ( currentOpus )
            {
                [ currentOpus playOrPause ];
            }
            else
            {
                if ( [ _nextOpusButton isEnabled ] ) [ self playNextOpus:nil ];
            }
            return;

        case kHIDRemoteButtonCodeDown:
            if ( currentOpus && [ _previousOpusPartButton isEnabled ] ) [ currentOpus playPreviousOpusPart ];
            return;

        case kHIDRemoteButtonCodeUp:
            if ( currentOpus && [ _nextOpusPartButton isEnabled ] ) [ currentOpus playNextOpusPart ];
            return;

        case kHIDRemoteButtonCodeRight:
            if ( [ _nextOpusButton isEnabled ] ) [ self playNextOpus:nil ];
            return;
            
        case kHIDRemoteButtonCodeLeft:
            // Play from the start of the current opus
            if ( currentOpus) [ currentOpus playFirstOpusPart ];
            return;
           
        default:
            NSLog( @"unsupported button: %d", buttonCode );
    }
}

@end
