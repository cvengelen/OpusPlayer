//
//  OpusPlayerAppDelegate.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "OpusPlayerAppDelegate.h"
#import "PlayedOpus.h"

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

    [ opusItems removeAllObjects ];
    
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
        
        // Find the first occurence of ": " in the track name
        NSRange colonRange = [ trackName rangeOfString:@": " ];

        // Move to the next track if not found
        if ( colonRange.location == NSNotFound )
        {
            // Copy the full name and the track location
            opus.name = trackName;
            [ opus.tracks setValue:[ track valueForKey:@"Location" ] forKey:trackName ];
            
            // Add the opus to the collection
            [ opusItems addObject:opus ];
            
            // Move to the next track in the playlist
            continue;
        }

        // Get the opus name: everything before the colon
        NSRange opusNameRange = { 0, colonRange.location };
        opus.name = [ trackName substringWithRange:opusNameRange ];
        NSString* partName = [ trackName substringFromIndex: opusNameRange.length + 2 ];
        
        // Check if the collection of opus items already contains this opus
        if ( [ opusItems containsObject:opus ] )
        {
            // Get the existing opus
            Opus* existingOpus = [ opusItems objectAtIndex:[ opusItems indexOfObject:opus ] ];

            // Add part name and location to the tracks dictionary of the existing opus
            [ existingOpus.tracks setValue:[ track valueForKey:@"Location" ] forKey:partName ];

            // Move to the next track in the playlist
            continue;
        }

        // Add part name and location to the tracks dictionary of the new opus
        [ opus.tracks setValue:[ track valueForKey:@"Location" ] forKey:partName ];

        // The opus is not yet in the collection of opus items: add the opus to the collection
        [ opusItems addObject:opus ];
    }
        
    NSLog( @"#opusItems: %ld from a total of %ld", [ opusItems count ], [ playlistTracks count ] );
 
    // Trigger KVC/KVO by posting KVO notification
    [ _arrayController didChangeValueForKey:@"arrangedObjects" ];
    
    // Enable playing random opus items from the playlist
    [ _shuffleButton setEnabled:YES ];

    // Enable playing a random opus item from the playlist
    [ _nextOpusButton setEnabled:YES ];
}

// NSTableViewDelegate: Informs the delegate that the table view’s selection has changed
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
    // Release the audio hardware
    if ( audioPlayer ) [ self stopOpus ];

    // Get the selected opus item
    currentOpus = [ opusItems objectAtIndex:[ _playlistTableView selectedRow ] ];
    
    // Start playing the opus item
    [ self startPlayingCurrentOpus ];
}

// AVAudioPlayerDelegate: Called when a sound has finished playing
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // Release the audio hardware
    [ self stopOpus ];
    
    // Play the next opus part, if there is one in the part names array of the current opus
    // else play the next opus if the shuffle button is on
    if ( currentOpusPartNamesIndex < ( [ currentOpusPartNames count ] - 1 ) ) [ self playNextOpusPart:nil ];
    else
    {
        [ self updatePlayedOpusItems ];
        
        // Play the next opus item, chosen at random if the shuffle button is on
        if ( [ _shuffleButton state ] == NSOnState ) [ self playNextOpus:nil ];
    }
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
    int randomOpusItemsIndex = arc4random( ) % [ opusItems count ];
    currentOpus = [ opusItems objectAtIndex:randomOpusItemsIndex ];
    if ( [ currentOpus.tracks count ] == 0 )
    {
        NSLog( @"tracks empty" );
        return;
    }

    // Select the opus item in the table view
    [ _playlistTableView selectRowIndexes:[ NSIndexSet indexSetWithIndex:randomOpusItemsIndex ] byExtendingSelection:NO ];
    
    // Start playing the current opus
    [ self startPlayingCurrentOpus ];
}

// Shuffle: If nothing is playing, start playing a randomly chosen opus.
// If an opus is finished, continue with another randomly chosen opus.
// See AVAudioPlayerDelegate method audioPlayerDidFinishPlaying
- (IBAction)shuffleButton:(id)sender
{
    if ( ( [ _shuffleButton state ] == NSOnState ) && !opusIsPlaying )
    {
        // Release the audio hardware
        if ( audioPlayer ) [ self stopOpus ];

        // Play the next opus item, chosen randomly
        [ self playNextOpus:nil ];
    }
}

/////////////////////////////
// Helper methods
/////////////////////////////

// Prepare for playing a new opus item
- (void)startPlayingCurrentOpus
{
    currentOpusPartNames = [ [ currentOpus.tracks allKeys ] sortedArrayUsingComparator: ^(id obj1, id obj2)
                            {
                                return[ obj1 caseInsensitiveCompare:obj2 ];
                            } ];
    currentOpusPartNamesIndex = 0;

    [ _previousOpusPartButton setEnabled:NO ];

    if ( [ currentOpusPartNames count ] > 1 ) [ _nextOpusPartButton setEnabled:YES ];
    else [ _nextOpusPartButton setEnabled:NO ];
    
    // Get time at which the current opus starts playing
    currentOpusStartsPlayingDate = [ NSDate date ];

    // Output the composer, opus and artist
    [ _composerOpus setStringValue:[ [ currentOpus.composer stringByAppendingString:@": " ] stringByAppendingString:currentOpus.name ] ];
    [ _artist setStringValue:currentOpus.artist ];
    
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
    NSString* partName = [ currentOpusPartNames objectAtIndex: currentOpusPartNamesIndex ];
    
    NSURL* locationUrl = [ NSURL URLWithString:[ currentOpus.tracks valueForKey:partName ] ];
    audioPlayer = [ [ AVAudioPlayer alloc ] init ];
    audioPlayer = [ audioPlayer initWithContentsOfURL:locationUrl error:NULL ];
    if ( !audioPlayer)
    {
        NSLog( @"Error initializing audio player with URL %@", locationUrl );
        return;
    }
    [ audioPlayer setDelegate:self ];
    [ self playOpus ];
    if ( [ partName isEqualToString:currentOpus.name ] )  [ _opusPart setStringValue:@"" ];
    else [ _opusPart setStringValue:partName ];
}

// Update the played opus items
- (void)updatePlayedOpusItems
{
    PlayedOpus* playedOpus = [ [ PlayedOpus alloc ] init ];
    playedOpus.opus = currentOpus;
    playedOpus.atDate = currentOpusStartsPlayingDate;
    
    // Get the system calendar
    NSCalendar *systemCalendar = [ NSCalendar currentCalendar ];
    
    // Get conversion to hours, minutes, seconds
    NSUInteger unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ systemCalendar components:unitFlags fromDate:currentOpusStartsPlayingDate  toDate:[ NSDate date ]  options:0 ];
    playedOpus.forTime = [ NSString stringWithFormat:@"%ld:%ld:%ld", [ timeComponents hour ], [ timeComponents minute ], [ timeComponents second ] ];
    
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
