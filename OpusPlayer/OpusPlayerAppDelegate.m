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

        // Initialise the audio player
        audioPlayer = nil;
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
        // NSLog( @"Track ID: %@", trackId );
        NSDictionary* track = [ tracks objectForKey:[ trackId stringValue ] ];
        // NSLog( @"Track name: %@", [ track valueForKey:@"Name" ] );

        Opus* opus = [ [ Opus alloc ] init ];
        opus.composer = [ track valueForKey:@"Composer" ];
        opus.artist   = [ track valueForKey:@"Artist" ];
        opus.album    = [ track valueForKey:@"Album" ];
        opus.tracks   = [ [ NSMutableDictionary alloc ] init ];
 
        // Get the full name of the track
        NSString* trackName = [ track valueForKey:@"Name" ];

        /////////////////////////////////////////////////////////////////////////////
        // First remove the name of the composer from the track name, if present
        /////////////////////////////////////////////////////////////////////////////
        
        // Search for the name of the composer at the start of the track, followed by a colon or dash, with possible spaces
        NSString* composerName = [ NSString stringWithFormat:@"%@%@%@", @"^\\s*", opus.composer, @"\\s*[:-]\\s*" ];
        NSRange composerNameRange = [ trackName rangeOfString:composerName options:NSRegularExpressionSearch ];

        // Check if the name of the composer is found at the start of the track name
        if ( composerNameRange.location != NSNotFound )
        {
            // Remove the composer name from the track name
            trackName = [ trackName substringFromIndex:composerNameRange.length ];
        }

        // Setup the opus track data
        Track* opusTrack = [ [ Track alloc ] init ];
        opusTrack.location = [ track valueForKey:@"Location" ];
        opusTrack.trackNumber = [ [ track valueForKey:@"Track Number" ] intValue ];
 
        /////////////////////////////////////////////////////////////////////////////
        // Divide the track name in the opus name, and opus part names, divided by
        // either a colon or a dash, with possible spaces, and followed by at least one digit.
        /////////////////////////////////////////////////////////////////////////////

        // Try to find a divider string in the track name between an opus and an opus part:
        // a colon with possible spaces in front of or after the colon,
        // and followed by at least one digit (0-9). Bijvoorbeeld:
        //  Symfonie Nr. 5, Op. 67: 1. Allegro con brio
        NSString* opusDivider = @"\\s*:\\s*\\d";
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
    // Check if the current opus already equals the opus item at the selected index,
    // which means that the row is being automatically selected by playNextOpus.
    // In that case this method does not need to take any action.
    if ( [ currentOpus isEqual:[ [ _arrayController arrangedObjects ] objectAtIndex:[ _playlistTableView selectedRow ] ] ] ) return;

    // Release the audio hardware
    if ( audioPlayer ) [ self stopOpus ];
    
    // update the played opus items
    if ( currentOpus ) [ self updatePlayedOpusItems ];

    // Get the selected opus item
    currentOpus = [ [ _arrayController arrangedObjects ] objectAtIndex:[ _playlistTableView selectedRow ] ];
    
    // Start playing the opus item
    [ self startPlayingCurrentOpus ];
    
    // Enable playing a random opus item from the playlist
    [ _nextOpusButton setEnabled:YES ];
}

// AVAudioPlayerDelegate: Called when a sound has finished playing
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // Release the audio hardware
    [ self stopOpus ];
    
    // Play the next opus part, if there is one in the part names array of the current opus
    // else play the next randomly chosen opus if the shuffle button is on
    if ( currentOpusPartNamesIndex < ( [ currentOpusPartNames count ] - 1 ) ) [ self playNextOpusPart:nil ];
    else if ( [ _shuffleButton state ] == NSOnState ) [ self playNextOpus:nil ];
}

// NSApplicationDelegate: Sent by the default notification center after the application
// has been launched and initialized but before it has received its first event
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    opusIsPlaying = NO;
    currentOpus = nil;
    currentOpusPartNames = nil;
    currentOpusPartNamesIndex = 0;
    
    [ _previousOpusPartButton setEnabled:NO ];
    [ _playOrPauseButton setEnabled:NO ];
    [ _nextOpusPartButton setEnabled:NO ];
    [ _nextOpusButton setEnabled:NO ];
    [ _shuffleButton setEnabled:NO ];

    // Set full screen time every 10 seconds
    fullScreenTimer = [ NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(handleFullScreenTimer:) userInfo:nil repeats:YES ];

    fullScreenBoxXIncr = 10;
    fullScreenBoxYIncr = 10;
    fullScreenTimeYIncr = 10;
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
    if ( audioPlayer )
    {
        [ audioPlayer stop ];
        NSLog( @"Audio player stopped" );
    }
    
    if ( fullScreenTimer ) [ fullScreenTimer invalidate ];
}

/////////////////////////
// Button actions
/////////////////////////

// Play the previous opus part
- (IBAction)playPreviousOpusPart:(id)sender {
    // Release the audio hardware
    if ( audioPlayer ) [ self stopOpus ];
    
    if ( currentOpusPartNamesIndex <= 0 )
    {
        NSLog( @"Error: cannot decrease index: %d", currentOpusPartNamesIndex );
        return;
    }
    currentOpusPartNamesIndex--;

    [ _nextOpusPartButton setEnabled:YES ];
    if ( currentOpusPartNamesIndex == 0 ) [ _previousOpusPartButton setEnabled:NO ];

    [ self startPlayingOpusPart ];
}

// Play or pause
- (IBAction)playOrPause:(id)sender
{
    if ( opusIsPlaying ) [ self pauseOpus ];
    else [ self playOpus ];
}

// Play the next opus part
- (IBAction)playNextOpusPart:(id)sender
{
    // Release the audio hardware
    if ( audioPlayer ) [ self stopOpus ];
    
    if ( currentOpusPartNamesIndex >= ( [ currentOpusPartNames count ] - 1 ) )
    {
        NSLog( @"Error: cannot increase index to number of parts of current opus: %ld", [ currentOpusPartNames count ] );
        return;
    }
    currentOpusPartNamesIndex++;

    [ _previousOpusPartButton setEnabled:YES ];
    if ( currentOpusPartNamesIndex == ( [ currentOpusPartNames count ] - 1 ) ) [ _nextOpusPartButton setEnabled:NO ];

    [ self startPlayingOpusPart ];
}

// Play the next opus
- (IBAction)playNextOpus:(id)sender
{
    // Release the audio hardware
    if ( audioPlayer ) [ self stopOpus ];

    // update the played opus items
    if ( currentOpus ) [ self updatePlayedOpusItems ];

    // Get a random new opus
    // Use the arranged objects from the array controller to get the opus item
    int randomOpusItemsIndex = arc4random( ) % [ opusItems count ];
    currentOpus = [ [ _arrayController arrangedObjects ] objectAtIndex:randomOpusItemsIndex ];
    if ( [ currentOpus.tracks count ] == 0 )
    {
        NSLog( @"tracks empty" );
        return;
    }

    // Select the opus item in the table view, and show it
    // [ _playlistTableView selectRowIndexes:[ NSIndexSet indexSetWithIndex:randomOpusItemsIndex ] byExtendingSelection:NO ];
    [ _arrayController setSelectionIndex:randomOpusItemsIndex ];
    [ _playlistTableView scrollRowToVisible:[ _playlistTableView selectedRow ] ];
   
    // Start playing the current opus
    [ self startPlayingCurrentOpus ];
}

// Shuffle: If nothing is playing, start playing a randomly chosen opus.
// If an opus is finished, continue with another randomly chosen opus.
// See AVAudioPlayerDelegate method audioPlayerDidFinishPlaying
- (IBAction)shuffleButton:(id)sender
{
    if ( [ _shuffleButton state ] == NSOnState )
    {
        if ( !opusIsPlaying )
        {
            // Release the audio hardware
            if ( audioPlayer ) [ self stopOpus ];

            // Play the next opus item, chosen randomly
            [ self playNextOpus:nil ];
        }
        
        // Enable playing the next random opus item from the playlist
        [ _nextOpusButton setEnabled:YES ];
    }
}

/////////////////////////////
// Helper methods
/////////////////////////////

// Prepare for playing a new opus item
- (void)startPlayingCurrentOpus
{
    // Get the keys of the tracks dictionary, which are the names of all the parts of the opus.
    // The track names cannot be used for sorting, since they may range above 9, and tracks 10=19 would be sorted after 1 and before 2.
    // Therefore the track number, as stored in the Track object in the object stored with the key for sorting the opus parts.
    currentOpusPartNames = [ currentOpus.tracks keysSortedByValueUsingComparator: ^(id obj1, id obj2)
                            {
                                if ( [ obj1 trackNumber ] > [ obj2 trackNumber ] ) return (NSComparisonResult)NSOrderedDescending;
                                if ( [ obj1 trackNumber ] > [ obj2 trackNumber ] ) return (NSComparisonResult)NSOrderedAscending;
                                return (NSComparisonResult)NSOrderedSame;
                            } ];
    currentOpusPartNamesIndex = 0;

    [ _previousOpusPartButton setEnabled:NO ];

    if ( [ currentOpusPartNames count ] > 1 ) [ _nextOpusPartButton setEnabled:YES ];
    else [ _nextOpusPartButton setEnabled:NO ];
    
    // Get time at which the current opus starts playing
    currentOpusStartsPlayingDate = [ NSDate date ];

    // Output the composer, opus and artist
    NSString* composerOpus = [ [ currentOpus.composer stringByAppendingString:@": " ] stringByAppendingString:currentOpus.name ];
    [ _composerOpus setStringValue:composerOpus ];
    [ _artist setStringValue:currentOpus.artist ];

    [ _fullScreenComposerOpus setStringValue:composerOpus ];
    [ _fullScreenArtist setStringValue:currentOpus.artist ];
    
    [ self startPlayingOpusPart ];
}

// Start playing the part at the current opus part names index of the current opus
- (void)startPlayingOpusPart
{
    // Safety check on current audio player still playing
    if ( audioPlayer )
    {
        if ( audioPlayer.playing ) [ self stopOpus ];
    }

    if ( currentOpusPartNamesIndex < 0 || currentOpusPartNamesIndex >= [ currentOpusPartNames count ] )
    {
        NSLog( @"Error: invalid index in current opus part names: %d", currentOpusPartNamesIndex );
        return;
    }
    NSString* partName = [ currentOpusPartNames objectAtIndex:currentOpusPartNamesIndex ];
    
    Track* opusTrack = [ currentOpus.tracks valueForKey:partName ];
    NSURL* locationUrl = [ NSURL URLWithString:opusTrack.location ];
    audioPlayer = [ [ AVAudioPlayer alloc ] init ];
    audioPlayer = [ audioPlayer initWithContentsOfURL:locationUrl error:NULL ];
    if ( !audioPlayer)
    {
        NSLog( @"Error initializing audio player with URL %@", locationUrl );
        return;
    }
    [ audioPlayer setDelegate:self ];
    [ self playOpus ];
    
    // Use NSCalendar and NSDateComponents to convert the duration in a string hours:minutes:seconds
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits
                                                                        fromDate:[ NSDate date ]
                                                                        toDate:[ NSDate dateWithTimeIntervalSinceNow:audioPlayer.duration ]
                                                                        options:0 ];
    NSString* partDuration = @"(";
    if ( [ timeComponents hour ] > 0 ) partDuration = [ partDuration stringByAppendingFormat:@"%02ld:", [ timeComponents hour ] ];
    partDuration = [ partDuration stringByAppendingFormat:@"%02ld:%02ld)", [ timeComponents minute ], [ timeComponents second ] ];
    
    // Set the part name, if different from the opus name, and add the duration of part
    if ( [ partName isEqualToString:currentOpus.name ] )
    {
        [ _opusPart setStringValue:partDuration ];
        [ _fullScreenOpusPart setStringValue:partDuration ];
    }
    else
    {
        [ _opusPart setStringValue:[ partName stringByAppendingFormat:@" %@", partDuration ] ];
        [ _fullScreenOpusPart setStringValue:[ partName stringByAppendingFormat:@" %@", partDuration ] ];

    }
}

// Update the played opus items
- (void)updatePlayedOpusItems
{
    PlayedOpus* playedOpus = [ [ PlayedOpus alloc ] init ];
    playedOpus.opus = currentOpus;
    playedOpus.atDate = currentOpusStartsPlayingDate;
    
    // Use NSCalendar and NSDateComponents to convert the duration in a string hours:minutes:seconds
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits fromDate:currentOpusStartsPlayingDate  toDate:[ NSDate date ]  options:0 ];
    playedOpus.forTime = [ NSString stringWithFormat:@"%02ld:%02ld:%02ld", [ timeComponents hour ], [ timeComponents minute ], [ timeComponents second ] ];
    
    // Notify the array controller that the contents will be changed
    [ _playedOpusItemsArrayController willChangeValueForKey:@"arrangedObjects" ];

    // Add the played opus item to the array with played opus items
    [ playedOpusItems addObject:playedOpus ];

    // Notify the array controller that the contents has been changed
    [ _playedOpusItemsArrayController didChangeValueForKey:@"arrangedObjects" ];
}

//////////////////////////////
// Low level helper methods
//////////////////////////////

// Start playing the audio player
- (void)playOpus
{
    [ audioPlayer play ];
    [ _playOrPauseButton setTitle:@"Pause" ];
    [ _playOrPauseButton setEnabled:YES ];
    opusIsPlaying = YES;
}

// Pause the audio player
- (void)pauseOpus
{
    [ audioPlayer pause ];
    [ _playOrPauseButton setTitle:@"Play" ];
    opusIsPlaying = NO;
}

// Stop the audio player
- (void)stopOpus
{
    [ audioPlayer stop ];
    [ _playOrPauseButton setTitle:@"Play" ];
    opusIsPlaying = NO;
}

@end
