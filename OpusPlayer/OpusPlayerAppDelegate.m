//
//  OpusPlayerAppDelegate.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "OpusPlayerAppDelegate.h"

@implementation OpusPlayerAppDelegate

@synthesize opusItems;

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
        
        //
        opusItems = [ NSMutableArray array ];

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
     }
    return self;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if ( item == nil )
    {
        NSLog( @"outline view retrieves child %ld of root", index );
        return [ rootPlaylists objectAtIndex:index ];
    }

    NSLog( @"outline view retrieves child %ld for item %@", index, [ item objectForKey:@"Name" ] );
    
    // if ( item == [ level0Values objectAtIndex:1 ] ) return [ jazzValues objectAtIndex:index ];
    // if ( item == [ level0Values objectAtIndex:2 ] ) return [ classicalValues objectAtIndex:index ];

    NSArray* childPlaylists = [ childPlaylistsOfParent objectForKey:[ item objectForKey:@"Playlist Persistent ID" ] ];
    if ( childPlaylists ) return [ childPlaylists objectAtIndex:index ];
    
    return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if ( [ item objectForKey:@"Folder" ] ) return YES;
    //     if ( item == [ level0Values objectAtIndex:1 ] ) return YES;
    // if ( item == [ level0Values objectAtIndex:2 ] ) return YES;
    return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if ( item == nil ) return [ rootPlaylists count ];
    
    NSLog( @"outline view retrieves number of children for %@", [ item objectForKey:@"Name" ] );
     //    if ( item == [ level0Values objectAtIndex:0 ] ) return 0;
    //    if ( item == [ level0Values objectAtIndex:1 ] ) return 2;
    //    if ( item == [ level0Values objectAtIndex:2 ] ) return 3;

    NSArray* childPlaylists = [ childPlaylistsOfParent objectForKey:[ item objectForKey:@"Playlist Persistent ID" ] ];
    if ( childPlaylists ) return [ childPlaylists count ];

    return  0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    // NSLog( @"outline view retrieves item for item %@", [ item objectForKey:@"Name" ] );
    // return item;
    return [ item objectForKey:@"Name" ];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // Get the selected row from the outline view
    long selectedRow = [ _outlineView selectedRow ];
    
    // Get the playlist dictionary from the selected row
    NSDictionary* playlist = [ _outlineView itemAtRow:selectedRow ];
    NSLog( @"selected row: %ld, item %@", selectedRow , [ playlist objectForKey:@"Name" ] );

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

    [ self playNextOpus:nil ];
    [ _nextOpusButton setEnabled:YES ];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    opusPlaying = NO;
    currentOpus = nil;
    currentOpusPartNames = nil;
    currentOpusPartNamesIndex = 0;
    
    [ _previousOpusPartButton setEnabled:NO ];
    [ _playOrPauseButton setEnabled:NO ];
    [ _nextOpusPartButton setEnabled:NO ];
    [ _nextOpusButton setEnabled:NO ];
}

- (IBAction)playPreviousOpusPart:(id)sender {
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

- (IBAction)playOrPause:(id)sender
{
    if ( opusPlaying ) [ self pauseOpus ];
    else [ self playOpus ];
}

- (IBAction)playNextOpusPart:(id)sender
{
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

- (IBAction)playNextOpus:(id)sender
{
    int randomOpusItemsIndex = arc4random( ) % [ opusItems count ];
    currentOpus = [ opusItems objectAtIndex:randomOpusItemsIndex ];
    if ( [ currentOpus.tracks count ] == 0 )
    {
        NSLog( @"tracks empty" );
        return;
    }

    currentOpusPartNames = [ [ currentOpus.tracks allKeys ] sortedArrayUsingComparator: ^(id obj1, id obj2)
                            {
                                return[ obj1 caseInsensitiveCompare:obj2 ];
                            } ];
    currentOpusPartNamesIndex = 0;

    [ _previousOpusPartButton setEnabled:NO ];

    if ( [ currentOpusPartNames count ] > 1 ) [ _nextOpusPartButton setEnabled:YES ];
    else [ _nextOpusPartButton setEnabled:NO ];

    [ self startPlayingOpusPart ];
}

- (void)startPlayingOpusPart
{
    if ( opusPlaying ) [ self stopOpus ];
    
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
    [ _composerOpus setStringValue:[ [ currentOpus.composer stringByAppendingString:@": " ] stringByAppendingString:currentOpus.name ] ];
    if ( [ partName isEqualToString:currentOpus.name ] )  [ _opusPart setStringValue:@"" ];
    else [ _opusPart setStringValue:partName ];
}

- (void)playOpus
{
    [ audioPlayer play ];
    [ _playOrPauseButton setTitle:@"Pause" ];
    [ _playOrPauseButton setEnabled:YES ];
    opusPlaying = YES;
}

- (void)pauseOpus
{
    [ audioPlayer pause ];
    [ _playOrPauseButton setTitle:@"Play" ];
    opusPlaying = NO;
}

- (void)stopOpus
{
    [ audioPlayer stop ];
    [ _playOrPauseButton setTitle:@"Play" ];
    opusPlaying = NO;
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if ( currentOpusPartNamesIndex < ( [ currentOpusPartNames count ] - 1 ) ) [ self playNextOpusPart:nil ];
    else [ self playNextOpus:nil ];
}

@end
