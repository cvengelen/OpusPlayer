//
//  FullScreenViewController.m
//  OpusPlayer
//
//  Created by Chris van Engelen on 30-03-16.
//  Copyright © 2016 Chris van Engelen. All rights reserved.
//

#import "FullScreenViewController.h"

@interface FullScreenViewController ()

@end

@implementation FullScreenViewController {
    OpusPlayerAppDelegate *opusPlayerAppDelegate;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (id)init:(OpusPlayerAppDelegate *)opusPlayerAppDelegateIn {
    self = [super initWithNibName:@"FullScreenViewController" bundle:nil];
    if (self) {
        [self setTitle:@"Normal"];
        opusPlayerAppDelegate = opusPlayerAppDelegateIn;
    }
    return self;
}

- (IBAction)exitFullScreen:(NSButton *)sender {
    [opusPlayerAppDelegate toggleTestFullScreen];
}

@end
