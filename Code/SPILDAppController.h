//
//  SPILDAppController.h
//  SPILDemo
//
//  Copyright 2009 Kelan Champagne. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SPILDTopLayerView;


@interface SPILDAppController : NSObject {
    IBOutlet NSWindow *_window;
    IBOutlet SPILDTopLayerView *__weak _mainView;

    IBOutlet NSButton *_startStopButton;
    IBOutlet NSMatrix *_progressIndicatorType;
    IBOutlet NSColorWell *_fgColorWell;
    IBOutlet NSColorWell *_bgColorWell;
    
    NSTimer *_determinateProgressTimer;
}

// IB Actions
- (IBAction)pickNewForeColor:(id)sender;
- (IBAction)pickNewBackColor:(id)sender;
- (IBAction)selectProgressIndicatorType:(id)sender;
- (IBAction)startStopProgressIndicator:(id)sender;

// Properties
@property (weak) IBOutlet SPILDTopLayerView *mainView;

@end
