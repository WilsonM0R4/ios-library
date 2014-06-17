/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "UAanalytics.h"
#import "UAirship.h"
#import "UAAddCustomEventAction.h"
#import "UAAction+Internal.h"
#import "UACustomEvent.h"

@interface UAAddCustomEventActionTest : XCTestCase

@property(nonatomic, strong) id analytics;
@property(nonatomic, strong) id airship;
@property(nonatomic, strong) UAAddCustomEventAction *action;

@end

@implementation UAAddCustomEventActionTest

- (void)setUp {
    self.analytics = [OCMockObject niceMockForClass:[UAAnalytics class]];
    self.airship = [OCMockObject mockForClass:[UAirship class]];
    [[[self.airship stub] andReturn:self.airship] shared];
    [[[self.airship stub] andReturn:self.analytics] analytics];

    self.action = [[UAAddCustomEventAction alloc] init];

    [super setUp];
}

- (void)tearDown {
    [self.analytics stopMocking];
    [self.airship stopMocking];

    [super tearDown];
}

/**
 * Test custom event action accepts all the situations.
 */
- (void)testAcceptsArgumentsAllSituations {
    NSDictionary *dict = @{@"event_name":@"event name"};

    [self verifyAcceptsArgumentsWithValue:dict shouldAccept:YES];
}

/**
 * Test that it rejects invalid argument values.
 */
- (void)testAcceptsArgumentsNo {
    NSDictionary *invalidDict = @{@"invalid_key":@"event name"};
    [self verifyAcceptsArgumentsWithValue:invalidDict shouldAccept:NO];

    [self verifyAcceptsArgumentsWithValue:nil shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@"not a dictionary" shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSObject alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:[[NSDictionary alloc] init] shouldAccept:NO];
    [self verifyAcceptsArgumentsWithValue:@[] shouldAccept:NO];
}

/**
 * Test performing the action actually creates and adds the event from a NSNumber event value.
 */
- (void)testPerformNSNumber {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction id",
                           @"event_value": @(123.45),
                           @"attribution_type": @"attribution type",
                           @"attribution_id": @"attribution id"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
               [event.transactionID isEqualToString:@"transaction id"] &&
               [event.eventValue isEqualToNumber:@(123.45)] &&
               [event.attributionType isEqualToString:@"attribution type"] &&
               [event.attributionID isEqualToString:@"attribution id"];

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test performing the action actually creates and adds the event from a string
 * event value.
 */
- (void)testPerformString {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction id",
                           @"event_value": @"123.45",
                           @"attribution_type": @"attribution type",
                           @"attribution_id": @"attribution id"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction id"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.attributionType isEqualToString:@"attribution type"] &&
        [event.attributionID isEqualToString:@"attribution id"];

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test perform with invalid event name should result in error.
 */
- (void)testPerformInvalidCustomEventName {
    NSDictionary *dict = @{@"event_name": @"",
                           @"transaction_id": @"transaction id",
                           @"event_value": @"123.45",
                           @"attribution_type": @"attribution type",
                           @"attribution_id": @"attribution id"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict withSituation:UASituationManualInvocation];

    NSError *error = [NSError errorWithDomain:UAAddCustomEventActionErrorDomain
                                         code:UAAddCustomEventActionErrorCodeInvalidEventName
                                     userInfo:@{NSLocalizedDescriptionKey:@"Invalid event. Verify event name is not empty and within 255 characters."}];
    
    UAActionResult *expectedResult = [UAActionResult resultWithError:error];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];
}

/**
 * Test perform when attribution ID does not exist.
 */
- (void)testPerformNoAttributionID {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction id",
                           @"event_value": @"123.45",
                           @"attribution_type": @"attribution type"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction id"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.attributionType isEqualToString:@"attribution type"] &&
        ([event.attributionID length] == 0);

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test perform when attribution type does not exist.
 */
- (void)testPerformNoAttributionType {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction id",
                           @"event_value": @"123.45",
                           @"attribution_id": @"attribution id"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction id"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.attributionID isEqualToString:@"attribution id"] &&
        ([event.attributionType length] == 0);

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test perform when both attribution type and ID does not exist, autofill is
 * true and conversion ID exist
 */
- (void)testPerformAutoFillTrueConversionID {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction id",
                           @"event_value": @"123.45",
                           @"auto_fill_landing_page": @"YES"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    // Set a conversion push ID for the analytics session
    [[[self.analytics stub] andReturn:@{@"launched_from_push_id":@"push ID"}] session];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction id"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        [event.attributionType isEqualToString:kUAAttributionLandingPage] &&
        [event.attributionID isEqualToString:@"push ID"];

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test perform when both attribution type and ID does not exist, autofill is
 * true and conversion ID does not exist
 */
- (void)testPerformAutoFillTrueNoConversionID {
    NSDictionary *dict = @{@"event_name": @"event name",
                           @"transaction_id": @"transaction id",
                           @"event_value": @"123.45",
                           @"auto_fill_landing_page": @"YES"};

    UAActionArguments *args = [UAActionArguments argumentsWithValue:dict
                                                      withSituation:UASituationManualInvocation];

    UAActionResult *expectedResult = [UAActionResult emptyResult];

    [[self.analytics expect] addEvent:[OCMArg checkWithBlock:^BOOL(id obj) {
        UACustomEvent *event = obj;
        return [event.eventName isEqualToString:@"event name"] &&
        [event.transactionID isEqualToString:@"transaction id"] &&
        [event.eventValue isEqualToNumber:@(123.45)] &&
        ([event.attributionType length] == 0) &&
        ([event.attributionID length] == 0);

    }]];

    [self verifyPerformWithArgs:args withExpectedResult:expectedResult];

    // Verify the event was added
    XCTAssertNoThrow([self.analytics verify], @"Custom event should have been added.");
}

/**
 * Test perform when both attribution type and ID does not exist and autofill is false
 */
- (void)testPerformAutoFillFalse {
    // TODO: Add test for MC_RAP
}

/**
 * Helper method to verify perform.
 */
- (void)verifyPerformWithArgs:(UAActionArguments *)args
           withExpectedResult:(UAActionResult *)expectedResult {

    __block BOOL finished = NO;

    [self.action performWithArguments:args withCompletionHandler:^(UAActionResult *result) {
        finished = YES;
        XCTAssertEqual(result.status, expectedResult.status, @"Result status should match expected result status.");
        XCTAssertEqual(result.fetchResult, expectedResult.fetchResult, @"FetchResult should match expected fetchresult.");
    }];

    XCTAssertTrue(finished, @"Action should have completed.");
}

/**
 * Helper method to verify accepts arguments.
 */
- (void)verifyAcceptsArgumentsWithValue:(id)value shouldAccept:(BOOL)shouldAccept {
    NSArray *situations = @[[NSNumber numberWithInteger:UASituationWebViewInvocation],
                            [NSNumber numberWithInteger:UASituationForegroundPush],
                            [NSNumber numberWithInteger:UASituationBackgroundPush],
                            [NSNumber numberWithInteger:UASituationLaunchedFromPush],
                            [NSNumber numberWithInteger:UASituationManualInvocation]];

    for (NSNumber *situationNumber in situations) {
        UAActionArguments *args = [UAActionArguments argumentsWithValue:value
                                                          withSituation:[situationNumber integerValue]];

        BOOL accepts = [self.action acceptsArguments:args];
        if (shouldAccept) {
            XCTAssertTrue(accepts, @"Add custom event action should accept value %@ in situation %@", value, situationNumber);
        } else {
            XCTAssertFalse(accepts, @"Add custom event action should not accept value %@ in situation %@", value, situationNumber);
        }
    }
}

@end