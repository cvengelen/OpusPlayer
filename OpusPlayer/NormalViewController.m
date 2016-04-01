//
//  NormalViewController.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 30-03-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import "NormalViewController.h"

#import "Opus.h"
#import "Track.h"

@interface NormalViewController ()

@end

@implementation NormalViewController {
    // The iTunes music dictionary
    NSDictionary* iTunesMusicDictionary;
    
    // All child playlists of a parent playlist, key is the persistent ID of the parent playlist
    NSMutableDictionary* childPlaylistsOfParent;
    
    // All playlists which do not have a parent playlist
    NSMutableArray* rootPlaylists;
    
    // All opus items of the selected playlist
    NSMutableArray* opusItems;
    
    // Selected composer and artist
    NSString *selectedComposer;
    NSString *selectedArtist;

}

@synthesize opusItems;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
}

- (id)init {
    self = [super initWithNibName:@"NormalViewController" bundle:nil];
    if (self) {
        [self setTitle:@"Opus Player Normal View"];

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
    long selectedRow = [ _playListsOutlineView selectedRow ];
    
    // Get the playlist dictionary from the selected row
    NSDictionary* playlist = [ _playListsOutlineView itemAtRow:selectedRow ];
    
    // Get all playlist tracks from the playlist
    NSArray* playlistTracks = [ playlist objectForKey:@"Playlist Items" ];
    
    // Get all tracks from the iTunes Music dictionary
    NSDictionary* tracks = [ iTunesMusicDictionary valueForKey:@"Tracks" ];
    
    // Save the sort descriptors currently in use
    NSArray* sortDescriptors = [ _playListArrayController sortDescriptors ];
    
    // Trigger KVC/KVO by posting KVO notification
    // See: http://stackoverflow.com/questions/1313709/kvc-kvo-and-bindings-why-am-i-only-receiving-one-change-notification
    [ _playListArrayController willChangeValueForKey:@"arrangedObjects" ];
    
    // Remove all selections from the array controller, because the new list of opus items may be smaller than the selected row.
    [ _playListArrayController removeSelectionIndexes:[ _playListArrayController selectionIndexes ] ];
    
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
    [ _playListArrayController setSortDescriptors:sortDescriptors ];
    
    // Remove the filter predicate if it was set: show all composers and artists
    [ _playListArrayController setFilterPredicate:nil ];
    
    // Remove the selected composer and artist, otherwise selecting a composer will reuse
    // the previously selected artist (and vice versa), giving unpredictable results
    selectedArtist = nil;
    selectedComposer = nil;
    [ _artistsComboBox setStringValue:@"" ];
    [ _composersComboBox setStringValue:@"" ];
    
    // Trigger rearrangement of the array controller arranged objects according to the new content and sorting
    [ _playListArrayController rearrangeObjects ];
    
    // Trigger KVC/KVO by posting KVO notification
    [ _playListArrayController didChangeValueForKey:@"arrangedObjects" ];
    
    // Insert values for the composers combobox
    [ self setComboBox:_composersComboBox withProperty:@"composer" ];
    
    // Insert values for the artists combobox
    [ self setComboBox:_artistsComboBox withProperty:@"artist" ];
    
    // Set the label before the composers and artists combo boxes only if both are enabled
    if ( [ _composersComboBox isEnabled ] && [ _artistsComboBox isEnabled ] ) [ _selectItemsTextField setStringValue:@"Select composer/artist:" ];
    else [ _selectItemsTextField setStringValue:@"" ];
    
    /*
    // Check if the playlist tableview actually contains on or more opus items
    if ( [ _playListArrayController.arrangedObjects count ] > 0 )
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
     */
}


#pragma mark -
#pragma mark NSComboBoxDelegate

/////////////////////////////////////////////////////////////////////////////
// Combobox delegate
/////////////////////////////////////////////////////////////////////////////

-( void )setComboBox:( NSComboBox* )aComboBox withProperty:( NSString* )aProperty
{
    NSMutableArray *comboBoxItems = [ NSMutableArray array ];
    for ( Opus *opusItem in _playListArrayController.arrangedObjects )
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
    [ _playListArrayController setFilterPredicate:nil ];
    
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
    [ _playListArrayController setFilterPredicate:predicate ];
    NSLog( @"#arranged objects with predicate: %ld", [ _playListArrayController.arrangedObjects count ] );
    
    // Do not change combobox list if there are no items in the filtered playlist
    if ( [ _playListArrayController.arrangedObjects count ] == 0 ) return;
    
    // Let the composer combobox only show the selected composer, and a blank item to get back to all composers
    [ self setComboBox:_composersComboBox withProperty:@"composer" ];
    
    // Let the artist combobox only show the selected artist, and a blank item to get back to all artists
    [ self setComboBox:_artistsComboBox withProperty:@"artist" ];
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


@end
