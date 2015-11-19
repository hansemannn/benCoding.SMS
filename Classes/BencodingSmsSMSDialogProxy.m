/**
 * benCoding.SMS Project
 * Copyright (c) 2012-2014 by Ben Bahrenburg. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "BencodingSmsSMSDialogProxy.h"
#import "TiUtils.h"
#import "TiApp.h"

BOOL lockPortrait = NO;
BOOL statusBarHiddenCheck = NO;
BOOL statusBarHiddenOldValue = NO;

@implementation MFMessageComposeViewController (AutoRotation)

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (lockPortrait == YES) {
        return NO;
    } else {
        
        // Check if the orientation is supported in the Tiapp.xml settings
        BOOL allowRotate = [[[TiApp app] controller] shouldAutorotateToInterfaceOrientation:interfaceOrientation];
        
        // If it is supported, we need to move the entire app.
        // Without doing this, our keyboard wont reposition itself
        if (allowRotate == YES) {
            [[UIApplication sharedApplication] setStatusBarOrientation:interfaceOrientation animated:NO];
        }
        
        // We tell the app if we can rotate, ie is this a support orientation
        return allowRotate;        
    }
}

@end

@implementation BencodingSmsSMSDialogProxy

-(NSNumber*)canSendText:(id)unused
{
    return  NUMBOOL([MFMessageComposeViewController canSendText] == YES);
}

-(void)open:(id)args
{
    if ([self canSendText:nil] == NO) {
        if ([self _hasListeners:@"errored"]) {
            [self fireEvent:@"errored" withObject:@{@"message" : @"Your device does not support sending text messages."}];
        }         
        return;
    }
    
    // Make sure we're on the UI thread, this stops bad things
	ENSURE_UI_THREAD(open,args);
    
    id message = [self valueForKey:@"messageBody"];
    id toRecipients = [self valueForKey:@"toRecipients"];
    id statusBarHidden = [self valueForKey:@"statusBarHidden"];
    id barColor = [self valueForKey:@"barColor"];
    
    args = [args objectAtIndex:0];

    id portraitOnly = [args valueForKey:@"portraitOnly"];
    id animated = [args valueForKey:@"animated"];
    
    lockPortrait = [TiUtils boolValue:portraitOnly def:NO];
    statusBarHiddenOldValue = [[UIApplication sharedApplication] isStatusBarHidden];

    ENSURE_TYPE_OR_NIL(toRecipients, NSArray);
    
    if (toRecipients == nil) {
        toRecipients == [NSArray array];
    }
    
    MFMessageComposeViewController * smsComposer = [[MFMessageComposeViewController alloc] init];
    [smsComposer setMessageComposeDelegate:self];

    // Build the message contents
    [smsComposer setBody:[TiUtils stringValue:message]];
    [smsComposer setRecipients:toRecipients];
    
    // If we are hiding the statusbar we perform the below
    if ([TiUtils boolValue:statusBarHidden def:NO] == YES) {
        //Set our dialog to full screen
        [smsComposer setEdgesForExtendedLayout:UIRectEdgeAll];
        [smsComposer setExtendedLayoutIncludesOpaqueBars:YES];
    }

    // See if we need to do anything with the barColor
    UIColor * nativeBarColor = [[TiUtils colorValue:barColor] _color];
    if (nativeBarColor != nil) {
        [[smsComposer navigationBar] setTintColor:nativeBarColor];
    }
    
    // We call into core TiApp module this handles the controller magic for us
    [[[[TiApp app] controller] topPresentedController] presentViewController:smsComposer animated:[TiUtils boolValue:animated def:YES] completion:nil];
}

#pragma mark Delegate 
- (void)messageComposeViewController:(MFMessageComposeViewController *)smsComposer didFinishWithResult:(MessageComposeResult)result
{
    NSString *eventName;
    NSString *msg;

    // If we enabled full screen, we need to set it back
    if (statusBarHiddenOldValue != [TiUtils boolValue:[self valueForKey:@"statusBarHdiden"] def:NO])
    {
        [[UIApplication sharedApplication] setStatusBarHidden:statusBarHiddenOldValue];
    }
    
    // Hide the dialog window
    [smsComposer dismissViewControllerAnimated:YES completion:nil];
    
    if (result == MessageComposeResultCancelled) {
        eventName = @"cancelled";
        msg = @"Message was cancelled.";
        
    } else if (result == MessageComposeResultSent) {
        eventName = @"completed";
        msg = @"Message sent successfully.";
    }else {
        eventName = @"errored";
        msg = @"Error sending message.";
    }
    
    if ([self _hasListeners:eventName]) {
        [self fireEvent:eventName withObject:@{@"message" : msg}];
    }
}

@end

