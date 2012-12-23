//
//  OpusPlayerAppDelegate.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "OpusPlayerAppDelegate.h"
#import "PlayedOpus.h"
#import "Track.h"

@implementation OpusPlayerAppDelegate

@synthesize opusItems;
@synthesize playedOpusItems;

- ( id )init
{
    self = [ super init ];
    if ( self )
    {
        NSLog( @"init" );

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
            NSLog( @"playlist: %@", [ playlist valueForKey:@"Name" ] );

            // Check if the playlist has a Folder key, which indicates thay the playlist is the parent of child playlists
            if ( [ playlist valueForKey:@"Folder" ] )
            {
                NSString* playlistPersistentId = [ playlist valueForKey:@"Playlist Persistent ID" ];
                NSLog( @" is folder with ID %@", playlistPersistentId );
                
                // Define a test block to look for child playlists for this parent playlist
                testForPlaylistChild = ^( id playlistToTest, NSUInteger playlistToTestIndex, BOOL *stop )
                {
                    NSString* parentPersistentId = [ playlistToTest valueForKey:@"Parent Persistent ID" ];
                    if ( [ parentPersistentId isEqualToString:playlistPersistentId ] ) return YES;
                    return NO;
                };
                
                NSIndexSet* indexSet = [ playlists indexesOfObjectsPassingTest:testForPlaylistChild ];
                NSArray* childPlayLists = [ playlists objectsAtIndexes:indexSet ];
                NSLog( @"#children: %ld", [ childPlayLists count ] );
                [ childPlaylistsOfParent setValue:childPlayLists forKey:playlistPersistentId ];
            }

            if ( ![ playlist objectForKey:@"Parent Persistent ID" ] )
            {
                [ rootPlaylists addObject:playlist ];
            }
        }
        
        // Initialise the array with the opus items in the playlist
        opusItems = [ NSMutableArray array ];
        
        // Initialise the array with the played opus items
        playedOpusItems = [ NSMutableArray array ];

        // There is no current opus yet
        currentOpus = nil;

        // Set the full screen data (to be moved to separate full screen class)
        fullScreenBoxXIncr = 10;
        fullScreenBoxYIncr = 10;
        fullScreenTimeYIncr = 10;
     }
    return self;
}


////////////////////////////////////////////////////
// Playlist outline view data source methods:
// Input for the rows of the playlist outline view
////////////////////////////////////////////////////

// NSOutlineViewDataSource: Returns the child item at the specified index of a given item
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if ( item == nil ) return [ rootPlaylists objectAtIndex:index ];

    // NSLog( @"outline view retrieves child %ld for item %@", index, [ item objectForKey:@"Name" ] );

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
    
    // NSLog( @"outline view retrieves number of children for %@", [ item objectForKey:@"Name" ] );

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
    // NSLog( @"selected row: %ld, item %@", selectedRow , [ playlist objectForKey:@"Name" ] );

    // Get all playlist tracks from the playlist
    NSArray* playlistTracks = [ playlist objectForKey:@"Playlist Items" ];

    // Get all tracks from the iTunes Music dictionary
    NSDictionary* tracks = [ iTunesMusicDictionary valueForKey:@"Tracks" ];

    // Trigger KVC/KVO by posting KVO notification
    // See: http://stackoverflow.com/questions/1313709/kvc-kvo-and-bindings-why-am-i-only-receiving-one-change-notification
    [ _arrayController willChangeValueForKey:@"arrangedObjects" ];

    // Clear all items from the dictionary with opus items
    [ opusItems removeAllObjects ];
 
    // Remove any sort descriptors on the array controller
    [ _arrayController setSortDescriptors:nil ];

    // Trigger rearrangement of the array controller arranged objects
    // This is needed because otherwise the contents will not change
    [ _arrayController rearrangeObjects ];
    
    for ( NSDictionary* playlistTrack in playlistTracks )
    {
        NSNumber* trackId= [ playlistTrack objectForKey:@"Track ID" ];
        NSDictionary* track = [ tracks objectForKey:[ trackId stringValue ] ];

        // Initialise an opus objec with the composer, artist and album
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
        int opusDividerBacktrack = 1;
        NSRange opusDividerRange = [ trackName rangeOfString:opusDivider options:NSRegularExpressionSearch ];
        
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
    
    // Define the sort descriptors for composer, opus name (special) and artist
    NSSortDescriptor* composerSortDescriptor = [ NSSortDescriptor sortDescriptorWithKey:@"composer" ascending:YES ];
    // Use numeric search in opus name sort descriptor
    NSSortDescriptor* opusNameSortDescription = [ NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES comparator:^(id name1, id name2) {
        return [ name1 compare:name2 options:NSNumericSearch ];
    } ];
    NSSortDescriptor* artistSortDescriptor   = [ NSSortDescriptor sortDescriptorWithKey:@"artist" ascending:YES ];

    // Sort the play list table on composer, opus name, and artist
    NSArray* playListSortDescriptors = [ NSArray arrayWithObjects:composerSortDescriptor, opusNameSortDescription, artistSortDescriptor, nil ];
    [ _arrayController setSortDescriptors:playListSortDescriptors ];
    
    // Trigger KVC/KVO by posting KVO notification
    [ _arrayController didChangeValueForKey:@"arrangedObjects" ];
    NSLog( @"#arranged objects in array controller: %ld", [ [ _arrayController arrangedObjects ] count ] );
    
    // Enable playing random opus items from the playlist
    [ _shuffleButton setEnabled:YES ];
}

// NSTableViewDelegate: Informs the delegate that the table view’s selection has changed
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    // Check if there is already a current opus
    if ( currentOpus )
    {
        // Check if the current opus already equals the opus item at the selected index,
        // which means that the row is being automatically selected by playNextOpus.
        // In that case this method does not need to take any action.
        if ( [ currentOpus.opus isEqual:[ [ _arrayController arrangedObjects ] objectAtIndex:[ _playlistTableView selectedRow ] ] ] ) return;

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

    // Initialize a new current opus with the selected opus item
    // (let ARM delete the previous current opus)
    currentOpus = [ [ CurrentOpus alloc ] initWithOpus:opus andDelegate:self ];
    
    // Start playing the opus item
    [ currentOpus startPlaying ];
    
    // Enable playing a random opus item from the playlist
    [ _nextOpusButton setEnabled:YES ];
}

// Notification from the current opus that it did finish playing the complete opus (all tracks)
-( void )opusDidFinishPlaying
{
    // Play the next randomly chosen opus if the shuffle button is on
    // (this is the same as activating the "Next opus" button)
    if ( [ _shuffleButton state ] == NSOnState ) [ self playNextOpus:nil ];
}

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

    // Set full screen time every 10 seconds (to be moved to separate full screen class)
    fullScreenTimer = [ NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(handleFullScreenTimer:) userInfo:nil repeats:YES ];
}

- (void)handleFullScreenTimer:(NSTimer *)timer
{
    // Use NSCalendar and NSDateComponents to convert the current time in a string hours:minutes
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits fromDate:[ NSDate date ] ];
    
    // Set the time on the full screen window
    [ _fullScreenTime setStringValue:[ NSString stringWithFormat:@"%02ld:%02ld", [ timeComponents hour ], [ timeComponents minute ] ] ];
    
    // Get the frame of the box in the full screen window
    NSRect fullScreenBoxFrame = [ _fullScreenBox frame ];

    // Get the bounds of the parent view of the box
    NSRect fullScreenViewBounds = [ [ _fullScreenBox superview ] bounds ];

    // Determine the direction of the x increment of the box position in the full screen window
    if ( fullScreenBoxXIncr > 0 )
    {
        if ( ( fullScreenBoxFrame.origin.x + fullScreenBoxFrame.size.width + fullScreenBoxXIncr ) > fullScreenViewBounds.size.width ) fullScreenBoxXIncr = -fullScreenBoxXIncr;
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

}

// NSApplicationDelegate: Sent by the default notification center immediately before the application terminates
-( void )applicationWillTerminate:(NSNotification *)notification
{
    // Release the audio hardware
    if ( currentOpus )
    {
        [ currentOpus stopPlaying ];
        NSLog( @"Audio player stopped" );
    }
    
    // Stop the full screen timer
    if ( fullScreenTimer ) [ fullScreenTimer invalidate ];
}

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
    // if ( opusIsPlaying ) [ self pauseOpus ];
    // else [ self playOpus ];
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
    }
    
    // Get a random new opus
    // Use the arranged objects from the array controller to get the opus item
    int randomOpusItemsIndex = arc4random( ) % [ opusItems count ];
    Opus* opus = [ [ _arrayController arrangedObjects ] objectAtIndex:randomOpusItemsIndex ];
    if ( [ opus.tracks count ] == 0 )
    {
        NSLog( @"tracks empty" );
        return;
    }
    
    // Initialize a new current opus item
    // (let ARM delete the previous current opus)
    currentOpus = [ [ CurrentOpus alloc ] initWithOpus:opus andDelegate:self ];
    
    // Start playing the current opus item
    [ currentOpus startPlaying ];

    // Select the opus item in the table view, and show it
    // must be done via the array controller (because of sorting the input array by the array controller)
    [ _arrayController setSelectionIndex:randomOpusItemsIndex ];
    [ _playlistTableView scrollRowToVisible:[ _playlistTableView selectedRow ] ];
}

// Shuffle: If nothing is playing, start playing a randomly chosen opus.
// If an opus is finished, continue with another randomly chosen opus.
// See AVAudioPlayerDelegate method audioPlayerDidFinishPlaying
- (IBAction)shuffleButton:(id)sender
{
    if ( [ _shuffleButton state ] == NSOnState )
    {
        // Release the audio hardware
        if ( currentOpus ) [ currentOpus stopPlaying ];

        // Play the next opus item, chosen randomly
        [ self playNextOpus:nil ];
        
        // Enable playing the next random opus item from the playlist
        [ _nextOpusButton setEnabled:YES ];
    }
}

/////////////////////////////
// Helper methods
/////////////////////////////

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
    
    // Notify the array controller that the contents will be changed
    [ _playedOpusItemsArrayController willChangeValueForKey:@"arrangedObjects" ];

    // Add the played opus item to the array with played opus items
    [ playedOpusItems addObject:playedOpus ];

    // Notify the array controller that the contents has been changed
    [ _playedOpusItemsArrayController didChangeValueForKey:@"arrangedObjects" ];
}

@end
