//
//  FullScreenViewController.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 30-03-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

// Technical Q&A QA1340: Preventing sleep using I/O Kit:
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "FullScreenViewController.h"

@implementation FullScreenViewController {
    // Full screen timer
    NSTimer* fullScreenTimer;
    
    int textBoxXIncr;
    int textBoxYIncr;
    int timeYIncr;
    
    // Enabling and disabling sleep
    IOPMAssertionID assertionID;

    NSString *composerOpus;
    NSString *artist;
    NSString *opusPart;

    // Font size of the composerOpus string
    CGFloat composerOpusFontSize;

    // Cursor display count
    unsigned int cursorCount;
}

- (id)init {
    self = [super initWithNibName:@"FullScreenView" bundle:nil];
    if (self) {
        [self setTitle:@"Opus Player Full Screen View"];
        
        // Initialise the X and Y increments. These are not constanst,
        // because they are reversed in sign if the box or time hits the walls of the view
        textBoxXIncr = 2;
        textBoxYIncr = 2;
        timeYIncr = 2;

        // Initialise the cursor count
        cursorCount = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    if (composerOpus) {
        composerOpusFontSize = [FullScreenViewController setStringValue:composerOpus onTextField:_ComposerOpusTextField withMaximumFontSize:50.0 andMinimumFontSize:10.0];
        if (artist) [FullScreenViewController setStringValue:artist onTextField:_artistTextField withMaximumFontSize:composerOpusFontSize andMinimumFontSize:10.0];
        if (opusPart) [FullScreenViewController setStringValue:opusPart onTextField:_opusPartTextField withMaximumFontSize:composerOpusFontSize andMinimumFontSize:12.0];
    }

    [self setFullScreenTime];
}

-(void)applicationWillTerminate {
    // Stop the full screen timer
    if (fullScreenTimer) [fullScreenTimer invalidate];
}

-(void)windowDidEnterFullScreen {
    // Set full screen time every 5 seconds (to be moved to separate full screen class)
    fullScreenTimer = [ NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(handleFullScreenTimer:) userInfo:nil repeats:YES ];
    
    // Hide the cursor. See "Controlling the Mouse Cursor"
    // (http://developer.apple.com/library/mac/#documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
    CGError cgError = CGDisplayHideCursor(kCGDirectMainDisplay);
    if (kCGErrorSuccess == cgError ) {
        cursorCount += 1;
    } else {
        NSLog( @"CGDisplayHideCursor failed with error code %d", cgError );
    }
    
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
}

- (void)windowDidExitFullScreen {
    // Stop the full screen timer
    [ fullScreenTimer invalidate ];
    
    // Clear the time
    [ _timeTextField setStringValue:@"" ];

    // Display the cursor if it was not visible. See "Controlling the Mouse Cursor"
    // (http://developer.apple.com/library/mac/#documentation/GraphicsImaging/Conceptual/QuartzDisplayServicesConceptual/Articles/MouseCursor.html)
    // CGCursorIsVisible is deprecated from OS X 10.9
    // see https://developer.apple.com/library/mac/documentation/GraphicsImaging/Reference/Quartz_Services_Ref/#//apple_ref/c/func/CGCursorIsVisible
    while (cursorCount > 0 ) {
        CGError cgError = CGDisplayShowCursor(kCGDirectMainDisplay);
        if (kCGErrorSuccess == cgError ) {
            cursorCount -= 1;
        } else {
            NSLog( @"CGDisplayShowCursor failed with error code %d", cgError );
            break;
        }
    }

    // Release the assertion, to enable the system to be able to sleep again
    IOReturn assertionCreateWithNameReturn = IOPMAssertionRelease( assertionID );
    if ( assertionCreateWithNameReturn != kIOReturnSuccess )
    {
        NSLog( @"IOPMAssertionRelease failed with error code %d", assertionCreateWithNameReturn );
    }
}

-(void)setFullScreenTime {
    // Use NSCalendar and NSDateComponents to convert the current time in a string hours:minutes
    NSUInteger calendarUnits = NSHourCalendarUnit | NSMinuteCalendarUnit;
    NSDateComponents* timeComponents = [ [ NSCalendar currentCalendar ] components:calendarUnits fromDate:[ NSDate date ] ];
    
    // Set the time on the full screen window
    [ _timeTextField setStringValue:[ NSString stringWithFormat:@"%02ld:%02ld", [ timeComponents hour ], [ timeComponents minute ] ] ];
}

- (void)handleFullScreenTimer:(NSTimer *)timer {
    // Set the current time
    [self setFullScreenTime ];
    
    // Get the frame of the text box
    NSRect textFrame = [ _textBox frame ];
    
    // Get the bounds of the parent view of the box
    NSRect viewBounds = [ [ _textBox superview ] bounds ];
    
    // Determine the direction of the x increment of the box position in the full screen window
    if ( textBoxXIncr > 0 )
    {
        // Take care not to overwrite the timer at the left of the screen
        if ( ( textFrame.origin.x + textFrame.size.width + textBoxXIncr ) > ( viewBounds.size.width - _timeTextField.frame.size.width ) ) textBoxXIncr = -textBoxXIncr;
    }
    else
    {
        if ( ( textFrame.origin.x + textBoxXIncr ) < 0 ) textBoxXIncr = - textBoxXIncr;
    }
    
    // Determine the direction of the y increment of the box position in the full screen window
    if ( textBoxYIncr > 0 )
    {
        if ( ( textFrame.origin.y + textFrame.size.height + textBoxYIncr ) > viewBounds.size.height ) textBoxYIncr = -textBoxYIncr;
    }
    else
    {
        if ( ( textFrame.origin.y + textBoxYIncr ) < 0 ) textBoxYIncr = - textBoxYIncr;
    }
    
    // Move the box in the full screen window a bit
    textFrame.origin.x += textBoxXIncr;
    textFrame.origin.y += textBoxYIncr;
    [ _textBox setFrameOrigin:textFrame.origin ];
    
    // Get the frame of the Time text label in the full screen window
    NSRect timeFrame = [ _timeTextField frame ];
    
    // Determine the direction of the y increment of the time label position in the full screen window
    if ( timeYIncr > 0 )
    {
        if ( ( timeFrame.origin.y + timeFrame.size.height + timeYIncr ) > viewBounds.size.height ) timeYIncr = -timeYIncr;
    }
    else
    {
        if ( ( timeFrame.origin.y + timeYIncr ) < 0 ) timeYIncr = - timeYIncr;
    }
    
    // Move the time label in the full screen window a bit
    timeFrame.origin.y += timeYIncr;
    [ _timeTextField setFrameOrigin:timeFrame.origin ];
    
    // Get the last cursor delta
    int32_t deltaX, deltaY;
    CGGetLastMouseDelta( &deltaX, &deltaY );
    
    // Show the cursor if it is moving, else hide it
    if ((deltaX != 0) || (deltaY != 0)) {
        while (cursorCount > 0) {
            CGError cgError = CGDisplayShowCursor( kCGDirectMainDisplay );
            if (kCGErrorSuccess == cgError ) {
                cursorCount -= 1;
            } else {
                NSLog( @"CGDisplayShowCursor failed with error code %d", cgError );
                break;
            }
        }
    } else if ((deltaX == 0) && (deltaY == 0)) {
        if (0 == cursorCount) {
            CGError cgError = CGDisplayHideCursor( kCGDirectMainDisplay );
            if (kCGErrorSuccess == cgError ) {
                cursorCount += 1;
            } else {
                NSLog( @"CGDisplayHideCursor failed with error code %d", cgError );
            }
        }
    }
}

#pragma mark -
#pragma mark CurrentOpusDelegate

/////////////////////////////////////////////////////////////////////////////
// Current Opus Delegate methods
/////////////////////////////////////////////////////////////////////////////

// Notification from the current opus with the string value for composerOpus
-(void)setStringComposerOpus:(NSString *)aComposerOpus {
    if (!aComposerOpus) return;
    composerOpus = aComposerOpus;

    if (!_ComposerOpusTextField) return;
    composerOpusFontSize = [FullScreenViewController setStringValue:composerOpus onTextField:_ComposerOpusTextField withMaximumFontSize:50.0 andMinimumFontSize:10.0];
}

// Notification from the current opus with the string value for artist
-(void)setStringArtist:(NSString *)anArtist {
    if (!anArtist) return;
    artist = anArtist;

    if (!_artistTextField) return;

    // Use the font size selected for the composerOpus output as maximum,
    // to avoid that the font used for the artist is larger that the font for the opus
    [FullScreenViewController setStringValue:artist onTextField:_artistTextField withMaximumFontSize:composerOpusFontSize andMinimumFontSize:10.0];
}

// Notification from the current opus with the string value for opusPart
-(void)setStringOpusPart:(NSString *)anOpusPart {
    if (!anOpusPart) return;
    opusPart = anOpusPart;

    if (!_opusPartTextField) return;

    // Use the font size selected for the composerOpus output as maximum,
    // to avoid that the font used for the opus part is larger that the font for the opus
    [FullScreenViewController setStringValue:opusPart onTextField:_opusPartTextField withMaximumFontSize:composerOpusFontSize andMinimumFontSize:12.0];
}

#pragma mark -
#pragma mark Helper methods

// Set a string in a text field, adjusting the font size if the string does not fit
+(CGFloat)setStringValue:(NSString*)aString onTextField:(NSTextField*)aTextField withMaximumFontSize:(CGFloat)maximumFontSize andMinimumFontSize:(CGFloat)minimumFontSize
{
    NSFont* textFieldFont = [aTextField font];
    NSDictionary* fontAttributes;
    NSSize stringSize;
    // Use a generous margin in the text field width to allow for word wrap (e.g., "blaasinstrumenten" in Mozart's Gran Partita)
    CGFloat textFieldWidth = 0.8 * aTextField.frame.size.width;
    CGFloat textFieldHeight = aTextField.frame.size.height;
    CGFloat fontPointSize = maximumFontSize;
    
    // Start at the maximum allowed font size, but don't go below the minimum font size
    while (fontPointSize > minimumFontSize) {
        // Set the font size.
        textFieldFont = [NSFont fontWithName:textFieldFont.fontName size:fontPointSize];

        // Make a dictionary of the font with as key the font name
        fontAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:textFieldFont, NSFontAttributeName, nil];

        // Get the size of the string with the font attributes
        stringSize = [aString sizeWithAttributes:fontAttributes];
        int nLines = textFieldHeight / stringSize.height;

        // Break out of the loop if the string fits in the size of the text field, allowing for a little margin
        if (stringSize.width < (nLines * textFieldWidth)) break;

        // Try again with a smaller font size
        fontPointSize -= 1;
    }
    
    // Set the resulting font in the text field
    [aTextField setFont:textFieldFont];
    
    // Set the string in the text field
    [aTextField setStringValue:aString];
    
    // Return the selected font size
    return fontPointSize;
}

@end
