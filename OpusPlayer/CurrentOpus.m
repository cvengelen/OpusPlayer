//
//  CurrentOpus.m
//
//  Currently playing opus item: handles the audio player interface
//
//  Created by Chris van Engelen on 22-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import "CurrentOpus.h"
#import "Track.h"

@implementation CurrentOpus

@synthesize opus;
@synthesize startsPlayingDate;
@synthesize isPlaying;

-( id )initWithOpus:( Opus* )anOpus andDelegate:( NSObject <CurrentOpusDelegate>* )aDelegate;
{
    self = [ super init ];
    if ( self )
    {
        opus = anOpus;
        delegate = aDelegate;

        // Get the keys of the tracks dictionary, which are the names of all the parts of the opus.
        // The track names cannot be used for sorting, since they may range above 9, and tracks 10=19 would be sorted after 1 and before 2.
        // Therefore the track number, as stored in the Track object in the object stored with the key for sorting the opus parts.
        partNames = [ opus.tracks keysSortedByValueUsingComparator: ^(id obj1, id obj2)
                     {
                         if ( [ obj1 trackNumber ] > [ obj2 trackNumber ] ) return (NSComparisonResult)NSOrderedDescending;
                         if ( [ obj1 trackNumber ] > [ obj2 trackNumber ] ) return (NSComparisonResult)NSOrderedAscending;
                         return (NSComparisonResult)NSOrderedSame;
                     } ];

        partNamesIndex = 0;
        
        // Initialise the audio player
        audioPlayer = nil;
        isPlaying = NO;
    }
    return self;
}

-( void )startPlaying
{    
    // Get time at which the opus starts playing
    startsPlayingDate = [ NSDate date ];
    
    // Output the composer, opus and artist
    NSString* composerOpus = @"";
    if ( opus.composer && [ opus.composer length ] > 0 ) composerOpus = [ opus.composer stringByAppendingString:@": " ];
    if ( opus.name && [ opus.name length ] > 0 ) composerOpus = [ composerOpus stringByAppendingString:opus.name ];
    else composerOpus = [ composerOpus stringByAppendingString:@"-" ];
    
    // Output opus total time only when more than one track
    if ( [ opus.tracks count ] > 1 )
    {
        // Determine opus total time
        unsigned long opusTotalTime = 0;
        for ( Track* track in [ opus.tracks allValues ] ) opusTotalTime += track.totalTime;
        
        if ( opusTotalTime > 0 )
        {
            // Use NSCalendar and NSDateComponents to convert the duration in a string hours:minutes:seconds
            NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
            NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits
                                                                                  fromDate:[ NSDate date ]
                                                                                    toDate:[ NSDate dateWithTimeIntervalSinceNow:( opusTotalTime / 1000 ) ]
                                                                                   options:0 ];
            NSString* opusDuration = @" (";
            if ( [ timeComponents hour ] > 0 ) opusDuration = [ opusDuration stringByAppendingFormat:@"%02ld:", [ timeComponents hour ] ];
            opusDuration = [ opusDuration stringByAppendingFormat:@"%02ld:%02ld)", [ timeComponents minute ], [ timeComponents second ] ];
            composerOpus = [ composerOpus stringByAppendingString:opusDuration ];
        }
    }
    
    // Notify the delegate of the new composerOpus and artist string values
    [ delegate setStringComposerOpus:composerOpus ];
    [ delegate setStringArtist:opus.artist ];

    // Start playing the first (or only) opus part
    [ self startPlayingOpusPart ];
    
    // Disable the previous opus part button
    [ delegate.previousOpusPartButton setEnabled:NO ];
    
    // Enable the next opus part button when there is more than one opus part
    if ( [ partNames count ] > 1 ) [ delegate.nextOpusPartButton setEnabled:YES ];
    else [ delegate.nextOpusPartButton setEnabled:NO ];
}

// Start playing the part at the current opus part names index of the current opus
- (void)startPlayingOpusPart
{
    // Safety check on current audio player still playing
    if ( audioPlayer ) [ self stopPlaying ];

    if ( partNamesIndex < 0 || partNamesIndex >= [ partNames count ] )
    {
        NSLog( @"Error: invalid index in current opus part names: %d", partNamesIndex );
        return;
    }
    NSString* partName = [ partNames objectAtIndex:partNamesIndex ];
    
    Track* track = [ opus.tracks valueForKey:partName ];
    
    // Check for m4p: can't play (see: "Ik loop maar een beetje")
    if ( [ track.location hasSuffix:@"m4p" ] )
    {
        NSLog( @"Sorry, can't play m4p file: %@", partName );
        NSRunAlertPanel( @"Warning", @"Sorry, OpusPlayer cannot play m4p file '%@'", @"OK", nil, nil, partName );
        return;
    }
    
    NSURL* locationUrl = [ NSURL URLWithString:track.location ];
    NSError* audioPlayerError;
    audioPlayer = [ [ AVAudioPlayer alloc ] initWithContentsOfURL:locationUrl error:&audioPlayerError ];
    if ( !audioPlayer)
    {
        NSLog( @"Error initializing audio player with URL %@: %@", locationUrl, audioPlayerError );
        return;
    }

    // Let the audio player send a message to this current opus object when finished with playing the track
    [ audioPlayer setDelegate:self ];
 
    // start playing the track
    [ self startOrContinuePlaying ];
    
    NSString* partDetails = @"(";
    
    // Add total # parts if number of tracks > 1
    if ( [ partNames count ] > 1 ) partDetails = [ partDetails stringByAppendingFormat:@"%d/%ld, ", ( partNamesIndex + 1), [ partNames count ] ];
    
    // Add placeholder for current time
    partDetails = [ partDetails stringByAppendingString:@"%@/" ];
    
    // Use NSCalendar and NSDateComponents to convert the duration in a string hours:minutes:seconds
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits
                                                                          fromDate:[ NSDate date ]
                                                                            toDate:[ NSDate dateWithTimeIntervalSinceNow:audioPlayer.duration ]
                                                                           options:0 ];
    
    if ( [ timeComponents hour ] > 0 ) partDetails = [ partDetails stringByAppendingFormat:@"%02ld:", [ timeComponents hour ] ];
    partDetails = [ partDetails stringByAppendingFormat:@"%02ld:%02ld)", [ timeComponents minute ], [ timeComponents second ] ];
    
    // Set the part name, if different from the opus name, and add the duration of part
    if ( [ partName isEqualToString:opus.name ] ) { opusPartString = partDetails; }
    else { opusPartString = [ partName stringByAppendingFormat:@" %@", partDetails ]; }

    // Notify the delegate of the new opus part string value, with current duration 00:00
    [ delegate setStringOpusPart:[ NSString stringWithFormat:opusPartString, @"00:00" ] ];

    // Notify the delegate of the new opus part duration
    [ delegate setOpusPartDuration:audioPlayer.duration ];
    
    // Notify the delegate of the current time of the playing track
    [ delegate setOpusPartCurrentTime:0 ];
}

// Handle notification from currentTime timer
- (void)handleCurrentTimeTimer:(NSTimer *)timer
{
    // Use NSCalendar and NSDateComponents to convert the current time in a string hours:minutes:seconds
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits
                                                                          fromDate:[ NSDate date ]
                                                                            toDate:[ NSDate dateWithTimeIntervalSinceNow:audioPlayer.currentTime ]
                                                                            options:0 ];
    NSString* currentTimeAsString = @"";
    if ( [ timeComponents hour ] > 0 ) currentTimeAsString = [ currentTimeAsString stringByAppendingFormat:@"%02ld:", [ timeComponents hour ] ];
    currentTimeAsString = [ currentTimeAsString stringByAppendingFormat:@"%02ld:%02ld", [ timeComponents minute ], [ timeComponents second ] ];
    
    // Notify the delegate of the new opus part string value, with actual current duration
    [ delegate setStringOpusPart:[ NSString stringWithFormat:opusPartString, currentTimeAsString ] ];

    // Notify the delegate of the current time of the playing track
    [ delegate setOpusPartCurrentTime:audioPlayer.currentTime ];
}


#pragma mark -
#pragma mark Button actions

-( void )playNextOpusPart
{
    // Release the audio hardware
    if ( audioPlayer ) [ self stopPlaying ];
    
    if ( partNamesIndex >= ( [ partNames count ] - 1 ) )
    {
        NSLog( @"Error: cannot increase index to number of parts of current opus: %ld", [ partNames count ] );
        return;
    }
    partNamesIndex++;
    
    [ delegate.previousOpusPartButton setEnabled:YES ];
    if ( partNamesIndex == ( [ partNames count ] - 1 ) ) [ delegate.nextOpusPartButton setEnabled:NO ];
    
    [ self startPlayingOpusPart ];

}

-( void )playPreviousOpusPart
{
    // Release the audio hardware
    if ( audioPlayer ) [ self stopPlaying ];

    if ( partNamesIndex <= 0 )
    {
        NSLog( @"Error: cannot decrease index: %d", partNamesIndex );
        return;
    }
    partNamesIndex--;

    [ delegate.nextOpusPartButton setEnabled:YES ];
    if ( partNamesIndex == 0 ) [ delegate.previousOpusPartButton setEnabled:NO ];

    [ self startPlayingOpusPart ];
}

-( void )playFirstOpusPart
{
    // Release the audio hardware
    if ( audioPlayer ) [ self stopPlaying ];

    // Start with the first opus part
    partNamesIndex = 0;
    
    // Disable the previous opus part button
    [ delegate.previousOpusPartButton setEnabled:NO ];
    
    // Enable the next opus part button when there is more than one opus part
    if ( [ partNames count ] > 1 ) [ delegate.nextOpusPartButton setEnabled:YES ];
    else [ delegate.nextOpusPartButton setEnabled:NO ];
    
    [ self startPlayingOpusPart ];
}

-( void )playOrPause
{
    // Check if the audio player is playing
    if ( isPlaying ) [ self pausePlaying ];
    else [ self startOrContinuePlaying ];
}

// Start or continue playing
-( void )startOrContinuePlaying
{
    [ audioPlayer play ];
    [ delegate.playOrPauseButton setTitle:NSLocalizedString(@"Pause", @"pause the playing of the current track") ];
    [ delegate.playOrPauseButton setEnabled:YES ];
    isPlaying = YES;
    
    // Set current time timer every second
    currentTimeTimer = [ NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector( handleCurrentTimeTimer: ) userInfo:nil repeats:YES ];
}

// Pause playing
-( void )pausePlaying
{
    [ audioPlayer pause ];
    [ delegate.playOrPauseButton setTitle:NSLocalizedString(@"Play", @"start or continue the playing of the current track") ];
    isPlaying = NO;
    
    // Stop the current time timer
    if ( currentTimeTimer ) [ currentTimeTimer invalidate ];
}

// Stop playing (releases the hardware)
-( void )stopPlaying
{
    [ audioPlayer stop ];
    [ delegate.playOrPauseButton setTitle:NSLocalizedString(@"Play", @"start or continue the playing of the current track") ];
    isPlaying = NO;
    
    // Stop the current time timer
    if ( currentTimeTimer ) [ currentTimeTimer invalidate ];
}

-( void )setCurrentTime:( NSTimeInterval )aCurrentTime
{
    NSLog( @"Set current time to: %f", aCurrentTime );
    audioPlayer.currentTime = aCurrentTime;
}

#pragma mark -
#pragma mark AVAudioPlayerDelegate

// AVAudioPlayerDelegate: Called when a sound has finished playing
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    // Release the audio hardware
    // Do not release the audio hardware: this may give interruption of sound when played via airport
    // [ self stopPlaying ];
    
    // Play the next opus part, if there is one in the part names array of the current opus
    // else signal the delegate that the player did finish playing
    if ( partNamesIndex < ( [ partNames count ] - 1 ) ) [ self playNextOpusPart ];
    else [ delegate opusDidFinishPlaying ];
}

@end
