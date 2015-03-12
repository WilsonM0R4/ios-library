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

#import <Foundation/Foundation.h>

/**
 * The domain for NSErrors generated by the NSJSONSerialization+UAAdditions methods.
 */
extern NSString * const UAJSONSerializationErrorDomain;

/**
 * Represents the possible error conditions when serializing JSON objects.
 */
typedef NS_ENUM(NSInteger, UAJSONSerializationErrorCode) {
    /**
     * Indicates an error in serializing an invalid object.
     */
    UAJSONSerializationErrorCodeInvalidObject
};

/**
 * The NSJSONSerialization convenience methods.
 */
@interface NSJSONSerialization (UAAdditions)

/**
 * Converts a Foundation object to a JSON formatted NSString
 * @param jsonObject Foundation object to convert 
 * @return NSString formatted as JSON, or nil if an error occurs
 * @note Writing JSON strings with this method defaults to no NSJSONWritingOptions, and does not accept fragments.
 */
+ (NSString *)stringWithObject:(id)jsonObject;

/**
 * Converts a Foundation object to a JSON formatted NSString
 * @param jsonObject Foundation object to convert
 * @param error An NSError pointer for storing errors, if applicable.
 * @return NSString formatted as JSON, or nil if an error occurs
 * @note Writing JSON strings with this method defaults to no NSJSONWritingOptions, and does not accept fragments.
 */
+ (NSString *)stringWithObject:(id)jsonObject error:(NSError **)error;

/**
 * Converts a Foundation object to a JSON formatted NSString
 * @param jsonObject Foundation object to convert
 * @param acceptingFragments `YES` if objects representing JSON value fragments are acceptable, `NO` otherwise.
 * @return NSString formatted as JSON, or nil if an error occurs.
 * @note Writing JSON strings with this method defaults to no NSJSONWritingOptions.
 */
+ (NSString *)stringWithObject:(id)jsonObject acceptingFragments:(BOOL)acceptingFragments;

/**
 * Converts a Foundation object to a JSON formatted NSString
 * @param jsonObject Foundation object to convert
 * @param acceptingFragments `YES` if objects representing JSON value fragments are acceptable, `NO` otherwise.
 * @param error An NSError pointer for storing errors, if applicable.
 * @return NSString formatted as JSON, or nil if an error occurs.
 * @note Writing JSON strings with this method defaults to no NSJSONWritingOptions.
 */
+ (NSString *)stringWithObject:(id)jsonObject acceptingFragments:(BOOL)acceptingFragments error:(NSError **)error;

/**
 * Converts a Foundation object to a JSON formatted NSString
 * @param jsonObject Foundation object to convert
 * @param opt NSJSONWritingOptions options
 * @return NSString formatted as JSON, or nil if an error occurs
 */
+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt;

/**
 * Converts a Foundation object to a JSON formatted NSString
 * @param jsonObject Foundation object to convert
 * @param opt NSJSONWritingOptions options
 * @param error An NSError pointer for storing errors, if applicable.
 * @return NSString formatted as JSON, or nil if an error occurs
 */
+ (NSString *)stringWithObject:(id)jsonObject options:(NSJSONWritingOptions)opt error:(NSError **)error;


/**
 * Create a Foundation object from JSON string
 * @param jsonString the JSON NSString to convert
 * @return A Foundation object, or nil if an error occurs.
 * @note Creating objects with this method defaults to NSJSONReadingMutableContainers options.
 */
+ (id)objectWithString:(NSString *)jsonString;

/**
 * Create a Foundation object from JSON string
 * @param jsonString the JSON NSString to convert
 * @param opt NSJSONReadingOptions
 * @return A Foundation object, or nil if an error occurs.
 */
+ (id)objectWithString:(NSString *)jsonString options:(NSJSONReadingOptions)opt;

/**
 * Create a Foundation object from JSON string
 * @param jsonString the JSON NSString to convert
 * @param opt NSJSONReadingOptions
 * @param error An NSError pointer for storing errors, if applicable.
 * @return A Foundation object, or nil if an error occurs.
 */
+ (id)objectWithString:(NSString *)jsonString options:(NSJSONReadingOptions)opt error:(NSError **)error;

@end
