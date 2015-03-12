/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

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

#import "UAInboxMessageList+Internal.h"

#import "UAirship.h"
#import "UAConfig.h"
#import "UADisposable.h"
#import "UAInbox.h"
#import "UAInboxAPIClient.h"
#import "UAInboxMessage+Internal.h"
#import "UAInboxDBManager+Internal.h"
#import "UAUtils.h"
#import "UAUser.h"
#import "UAHTTPConnection.h"
#import "UAURLProtocol.h"

NSString * const UAInboxMessageListWillUpdateNotification = @"com.urbanairship.notification.message_list_will_update";
NSString * const UAInboxMessageListUpdatedNotification = @"com.urbanairship.notification.message_list_updated";


@implementation UAInboxMessageList

@synthesize messages = _messages;

#pragma mark Create Inbox

- (instancetype)initWithUser:(UAUser *)user client:(UAInboxAPIClient *)client config:(UAConfig *)config {
    self = [super init];

    if (self) {
        self.inboxDBManager = [[UAInboxDBManager alloc] initWithConfig:config];
        self.user = user;
        self.client = client;
        self.batchOperationCount = 0;
        self.retrieveOperationCount = 0;

        self.unreadCount = -1;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;

    }
    return self;
}

+ (instancetype)messageListWithUser:(UAUser *)user client:(UAInboxAPIClient *)client config:(UAConfig *)config{
    return [[UAInboxMessageList alloc] initWithUser:user client:client config:config];
}

#pragma mark Custom setters

- (void)setMessages:(NSArray *)messages {
    @synchronized(self) {
        _messages = messages;

        NSMutableDictionary *messageIDMap = [NSMutableDictionary dictionary];
        NSMutableDictionary *messageURLMap = [NSMutableDictionary dictionary];

        for (UAInboxMessage *message in messages) {
            if (message.messageBodyURL.absoluteString) {
                [messageURLMap setObject:message forKey:message.messageBodyURL.absoluteString];
            }
            if (message.messageID) {
                [messageIDMap setObject:message forKey:message.messageID];
            }
        }

        self.messageIDMap = [messageIDMap copy];
        self.messageURLMap = [messageURLMap copy];
    }
}

- (NSArray *)messages {
    @synchronized(self) {
        return _messages;
    }
}

#pragma mark NSNotificationCenter helper methods

- (void)sendMessageListWillUpdateNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAInboxMessageListWillUpdateNotification object:nil];
}

- (void)sendMessageListUpdatedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:UAInboxMessageListUpdatedNotification object:nil];
}

#pragma mark Update/Delete/Mark Messages

- (UADisposable *)retrieveMessageListWithSuccessBlock:(UAInboxMessageListCallbackBlock)successBlock
                                     withFailureBlock:(UAInboxMessageListCallbackBlock)failureBlock {

    if (!self.user.isCreated) {
        return nil;
    }

    UA_LDEBUG("Retrieving message list.");

    self.retrieveOperationCount++;
    [self sendMessageListWillUpdateNotification];


    __block UAInboxMessageListCallbackBlock retrieveMessageListSuccessBlock = successBlock;
    __block UAInboxMessageListCallbackBlock retrieveMessageListFailureBlock = failureBlock;

    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        retrieveMessageListSuccessBlock = nil;
        retrieveMessageListFailureBlock = nil;
    }];


    // Fetch new messages
    [self.client retrieveMessageListOnSuccess:^(NSInteger status, NSArray *messages, NSInteger unread) {
        [self.queue addOperationWithBlock:^{
            // Sync client state
            [self syncLocalMessageState];

            if (status == 200) {
                UA_LDEBUG(@"Refreshing message list.");

                NSMutableSet *responseMessageIDs = [NSMutableSet set];

                // Convert dictionary to objects for convenience
                for (NSDictionary *message in messages) {
                    if (![self.inboxDBManager updateMessageWithDictionary:message]) {
                        [self.inboxDBManager addMessageFromDictionary:message];
                    }

                    NSString *messageID = [message valueForKey:@"message_id"];
                    if (messageID) {
                        [responseMessageIDs addObject:messageID];
                    }
                }

                // Delete server side deleted messages
                NSPredicate *deletedPredicate = [NSPredicate predicateWithFormat:@"NOT (messageID IN %@)", responseMessageIDs];
                NSArray *deletedMessages = [self.inboxDBManager fetchMessagesWithPredicate:deletedPredicate];
                if (deletedMessages.count) {
                    UA_LDEBUG(@"Server deleted messages: %@", deletedMessages);
                    [self.inboxDBManager deleteMessages:deletedMessages];
                }

                // Block is dispatched on the main queue
                [self refreshInboxWithCompletionHandler:^() {
                    if (self.retrieveOperationCount > 0) {
                        self.retrieveOperationCount--;
                    }

                    if (retrieveMessageListSuccessBlock) {
                        retrieveMessageListSuccessBlock();
                    }

                    [self sendMessageListUpdatedNotification];
                }];
            } else {
                UA_LDEBUG(@"Retrieve message list succeeded with messages: %@", self.messages);
                dispatch_async(dispatch_get_main_queue(), ^() {
                    if (self.retrieveOperationCount > 0) {
                        self.retrieveOperationCount--;
                    }

                    if (retrieveMessageListSuccessBlock) {
                        retrieveMessageListSuccessBlock();
                    }

                    [self sendMessageListUpdatedNotification];
                });
            }
        }];

    } onFailure:^(UAHTTPRequest *request){
        if (self.retrieveOperationCount > 0) {
            self.retrieveOperationCount--;
        }

        UA_LDEBUG(@"Retrieve message list failed with status: %ld", (long)request.response.statusCode);
        if (retrieveMessageListFailureBlock) {
            retrieveMessageListFailureBlock();
        }

        [self sendMessageListUpdatedNotification];
    }];

    return disposable;
}


- (UADisposable *)markMessagesRead:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler {
    self.batchOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];


    UA_LDEBUG(@"Marking messages as read %@.", messages);

    [self.queue addOperationWithBlock:^{
        for (UAInboxMessage *message in messages) {
            if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                message.data.unreadClient = NO;
            }
        }

        [self.inboxDBManager saveContext];


        // Block is dispatched on the main queue
        [self refreshInboxWithCompletionHandler:^{
            if (self.batchOperationCount > 0) {
                self.batchOperationCount--;
            }

            if (inboxMessageListCompletionBlock) {
                inboxMessageListCompletionBlock();
            }

            [self sendMessageListUpdatedNotification];
        }];

        [self syncLocalMessageState];
    }];

    return disposable;
}

- (UADisposable *)markMessagesDeleted:(NSArray *)messages completionHandler:(UAInboxMessageListCallbackBlock)completionHandler{
    self.batchOperationCount++;
    [self sendMessageListWillUpdateNotification];

    __block UAInboxMessageListCallbackBlock inboxMessageListCompletionBlock = completionHandler;
    UADisposable *disposable = [UADisposable disposableWithBlock:^{
        inboxMessageListCompletionBlock = nil;
    }];

    UA_LDEBUG(@"Marking messages as deleted %@.", messages);

    [self.queue addOperationWithBlock:^{
        for (UAInboxMessage *message in messages) {
            if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                message.data.deletedClient = YES;
            }
        }

        [self.inboxDBManager saveContext];

        // Block is dispatched on the main queue
        [self refreshInboxWithCompletionHandler:^{
            if (self.batchOperationCount > 0) {
                self.batchOperationCount--;
            }

            if (inboxMessageListCompletionBlock) {
                inboxMessageListCompletionBlock();
            }

            [self sendMessageListUpdatedNotification];
        }];

        [self syncLocalMessageState];
    }];

    return disposable;
}

- (void)loadSavedMessages {
    // First load
    [self sendMessageListWillUpdateNotification];
    [self refreshInboxWithCompletionHandler:^ {
        [self sendMessageListUpdatedNotification];
    }];
}


#pragma mark -
#pragma mark Helpers

/**
 * Helper method to refresh the inbox messages. Performs any blocking database
 * operations on a background queue, but updates the messages and calls the
 * specified completionHandler on the main queue.
 *
 * @param completionHandler Optional completion handler.
 */
- (void)refreshInboxWithCompletionHandler:(void (^)())completionHandler {
    [self.queue addOperationWithBlock:^{
        NSString *predicateFormat = @"(messageExpiration == nil || messageExpiration >= %@) && (deletedClient == NO || deletedClient == nil)";
        NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateFormat, [NSDate date]];
        NSMutableArray *savedMessages = [[self.inboxDBManager fetchMessagesWithPredicate:predicate] mutableCopy];

        NSInteger unreadCount = 0;

        for (UAInboxMessage *msg in savedMessages) {
            msg.inbox = self;
            if (msg.unread) {
                unreadCount ++;
            }

            // Add messsage's body url to the cachable urls
            [UAURLProtocol addCachableURL:msg.messageBodyURL];
        }

        UA_LINFO(@"Inbox messages updated.");

        UA_LDEBUG(@"Loaded saved messages: %@.", savedMessages);
        dispatch_async(dispatch_get_main_queue(), ^() {

            self.unreadCount = unreadCount;
            self.messages = [NSArray arrayWithArray:savedMessages];

            if (completionHandler) {
                completionHandler();
            }
        });
    }];
}

/**
 * Syncs any locally deleted and read messages with Urban Airship.
 */
- (void)syncLocalMessageState {
    NSPredicate *locallyReadPredicate = [NSPredicate predicateWithFormat:@"unreadClient == NO && unread == YES"];
    NSArray *locallyReadMessages = [self.inboxDBManager fetchMessagesWithPredicate:locallyReadPredicate];

    UA_LDEBUG(@"Marking %@ read on server.", locallyReadMessages);
    if (locallyReadMessages.count) {
        [self.client performBatchMarkAsReadForMessages:locallyReadMessages onSuccess:^{
            [self.queue addOperationWithBlock:^{
                for (UAInboxMessage *message in locallyReadMessages) {
                    UA_LDEBUG(@"Successfully marked messages read on server.");
                    if ([message isKindOfClass:[UAInboxMessage class]] && !message.data.isGone) {
                        message.data.unread = NO;
                    }
                }
                [self.inboxDBManager saveContext];
            }];
        } onFailure:^(UAHTTPRequest *request) {
            UA_LDEBUG(@"Failed to mark messages read.");
        }];
    }

    NSPredicate *deletedPredicate = [NSPredicate predicateWithFormat:@"deletedClient == YES"];
    NSArray *deletedMessages = [self.inboxDBManager fetchMessagesWithPredicate:deletedPredicate];

    UA_LDEBUG(@"Deleting %@ on server.", deletedMessages);
    if (deletedMessages.count) {
        [self.client performBatchDeleteForMessages:deletedMessages onSuccess:^{
            UA_LDEBUG(@"Successfully deleted messages on server.");
        } onFailure:^(UAHTTPRequest *request) {
            UA_LDEBUG(@"Failed to delete messages.");
        }];
    }
}


#pragma mark -
#pragma mark Get messages

- (NSUInteger)messageCount {
    return [self.messages count];
}

- (UAInboxMessage *)messageForBodyURL:(NSURL *)url {
    return [self.messageURLMap objectForKey:url.absoluteString];
}

- (UAInboxMessage *)messageForID:(NSString *)messageID {
    return [self.messageIDMap objectForKey:messageID];
}

- (BOOL)isRetrieving {
    return self.retrieveOperationCount > 0;
}

- (BOOL)isBatchUpdating {
    return self.batchOperationCount > 0;
}

- (id)debugQuickLookObject {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:@""];

    NSUInteger index = 0;
    NSUInteger characterIndex = 0;
    for (UAInboxMessage *message in self.messages) {
        NSString *line = index < self.messages.count-1 ? [NSString stringWithFormat:@"%@\n", message.title] : message.title;
        [attributedString.mutableString appendString:line];
        // Display unread messages in bold text
        NSString *fontName = message.unread ? @"Helvetica Bold" : @"Helvetica";
        [attributedString addAttribute:NSFontAttributeName value:[UIFont fontWithName:fontName size:15]
                                 range:NSMakeRange(characterIndex, line.length)];
        index++;
        characterIndex += line.length;
    }

    return attributedString;
}

@end
