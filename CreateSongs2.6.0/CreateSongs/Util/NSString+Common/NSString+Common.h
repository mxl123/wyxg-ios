//
//  NSString+Common.h
//  CardByYou
//
//  Created by qianfeng on 15/12/14.
//  Copyright © 2015年 XuLiangMa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSString (Common)

+ (NSString *)changeJsonStringToTrueJsonString:(NSString *)json;

NSString * URLEncodedString(NSString *str);


+ (NSString *)md5HexDigest:(NSString*)input;

NSString * MD5Hash(NSString *aString);
//
//- (NSString *) MD5Hash;
- (CGSize)getWidth:(NSString *)str andFont:(UIFont *)font;

- (NSString *)intervalSinceNow: (NSString *) theDate;


@end
