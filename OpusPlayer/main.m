//
//  main.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 02-12-12.
//  Copyright (c) 2012 Chris van Engelen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// Technical Q&A QA1340: Preventing sleep using I/O Kit: 
#import <IOKit/pwr_mgt/IOPMLib.h>

int main(int argc, char *argv[])
{
    // reasonForActivity is used by the system whenever it needs to tell
    // the user why the system is not sleeping (limited to 128 chararcers).
    CFStringRef reasonForActivity = CFSTR( "OpusPlayer is active");
    
    IOPMAssertionID assertionID;
    IOReturn assertionCreateWithNameReturn = IOPMAssertionCreateWithName( kIOPMAssertionTypeNoDisplaySleep,
                                                                          kIOPMAssertionLevelOn, reasonForActivity, &assertionID );
    if ( assertionCreateWithNameReturn != kIOReturnSuccess )
    {
        NSLog( @"IOPMAssertionCreateWithName failed with error code %d", assertionCreateWithNameReturn );
        return 1;
    }

    int applicationMainReturn = NSApplicationMain(argc, (const char **)argv);
    
    // Release the assertion, to enable the system to be able to sleep again
    assertionCreateWithNameReturn = IOPMAssertionRelease( assertionID );
    if ( assertionCreateWithNameReturn != kIOReturnSuccess )
    {
        NSLog( @"IOPMAssertionRelease failed with error code %d", assertionCreateWithNameReturn );
        return 1;
    }
    
    // Return the value from NSApplicationMain
    return applicationMainReturn;
}
