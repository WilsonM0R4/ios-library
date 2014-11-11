/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAShareAction.h"
#import "UAUtils.h"
#import "UAGlobal.h"
#import "UAActivityViewController.h"

@interface UAShareAction()
@property (nonatomic, strong) UAActivityViewController *activityViewController;
@property (nonatomic, strong) UAActivityViewController *lastActivityViewController;
@property (nonatomic, strong) UIPopoverController *popoverController;
@end

@implementation UAShareAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {

    if (arguments.situation == UASituationBackgroundPush || arguments.situation == UASituationBackgroundInteractiveButton) {
        return NO;
    }

    if (![arguments.value isKindOfClass:[NSString class]]) {
        return NO;
    }

    IF_IOS7_OR_GREATER(return YES;)

    // Reject if on iOS 6.x (unsupported).
    return NO;

}

- (void)performWithArguments:(UAActionArguments *)arguments
                  actionName:(NSString *)actionName
           completionHandler:(UAActionCompletionHandler)completionHandler {

    UA_LDEBUG(@"Running share action: %@", arguments);

    NSArray *activityItems = @[arguments.value];

    self.activityViewController = [[UAActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    self.activityViewController.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypeSaveToCameraRoll, UIActivityTypeAirDrop];

    NSString *deviceType = [UIDevice currentDevice].model;
    float deviceVersion = [[UIDevice currentDevice].systemVersion floatValue];

    __weak UAShareAction *weakSelf = self;
    self.activityViewController.dismissalBlock = ^{
        __strong UAShareAction *strongSelf = weakSelf;

        completionHandler([UAActionResult emptyResult]);

        if ([strongSelf.lastActivityViewController isEqual:strongSelf.activityViewController]) {
            strongSelf.lastActivityViewController = nil;
            strongSelf.popoverController = nil;

        } else if ([deviceType rangeOfString:@"iPad"].location != NSNotFound && deviceVersion >= 7.0 && deviceVersion < 8.0) {

            if (strongSelf.activityViewController != nil) {
                strongSelf.lastActivityViewController = strongSelf.activityViewController;
                strongSelf.popoverController = [[UIPopoverController alloc] initWithContentViewController:strongSelf.activityViewController];
                strongSelf.popoverController.delegate = strongSelf.activityViewController;
                [strongSelf.popoverController presentPopoverFromRect:strongSelf.activityViewController.sourceRect inView:[UAUtils topController].view permittedArrowDirections:0 animated:YES];
            }
        }
    };

    void (^displayShareBlock)(void) = ^(void) {

        self.lastActivityViewController = self.activityViewController;

        // iOS 8.0+
        if ([self.activityViewController respondsToSelector:@selector(popoverPresentationController)]) {

            UIPopoverPresentationController * popoverPresentationController = self.activityViewController.popoverPresentationController;

            popoverPresentationController.permittedArrowDirections = 0;

            // Set the delegate, center the popover on the screen
            popoverPresentationController.delegate = self.activityViewController;
            popoverPresentationController.sourceRect = self.activityViewController.sourceRect;
            popoverPresentationController.sourceView = [UAUtils topController].view;

            [[UAUtils topController] presentViewController:self.activityViewController animated:YES completion:nil];

        } else if ([deviceType rangeOfString:@"iPad"].location != NSNotFound && deviceVersion >= 7.0 && deviceVersion < 8.0) {
            // iOS 7.x iPad only
            self.popoverController = [[UIPopoverController alloc] initWithContentViewController:self.activityViewController];
            self.popoverController.delegate = self.activityViewController;
            [self.popoverController presentPopoverFromRect:self.activityViewController.sourceRect inView:[UAUtils topController].view permittedArrowDirections:0 animated:YES];

        } else {

            [[UAUtils topController] presentViewController:self.activityViewController animated:YES completion:nil];
        }
    };

    if (self.lastActivityViewController) {
        if ([deviceType rangeOfString:@"iPad"].location != NSNotFound && deviceVersion >= 7.0 && deviceVersion < 8.0) {
            [self.popoverController dismissPopoverAnimated:YES];
        } else {
            [self.lastActivityViewController dismissViewControllerAnimated:YES completion:displayShareBlock];
        }
    } else {
        displayShareBlock();
    }
}

@end
