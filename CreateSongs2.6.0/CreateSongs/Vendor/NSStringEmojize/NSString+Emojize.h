//
//  NSString+Emojize.h
//  Field Recorder
//
//  Created by Jonathan Beilin on 11/5/12.
//  Copyright (c) 2014 DIY. All rights reserved.
//
//  Inspired by https://github.com/larsschwegmann/Emoticonizer

#import <Foundation/Foundation.h>

@interface NSString (Emojize)

- (NSString *)emojizedString;
- (NSString *)preEmojizedString;
- (NSString *)removeEmojiString;
+ (NSString *)emojizedStringWithString:(NSString *)text;
+ (NSString *)stringContainsEmoji:(NSString *)string;
+ (NSDictionary *)emojiAliases;
+ (NSMutableDictionary *)preEmojiAliases;

@end
