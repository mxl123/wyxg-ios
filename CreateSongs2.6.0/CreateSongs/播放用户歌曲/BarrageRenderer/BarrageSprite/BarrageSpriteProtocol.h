// Part of BarrageRenderer. Created by UnAsh.
// Blog: http://blog.exbye.com
// Github: https://github.com/unash/BarrageRenderer

// This code is distributed under the terms and conditions of the MIT license.

// Copyright (c) 2015年 UnAsh.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void(^BarrageClickAction)(void);

/// UIView 弹幕协议
@protocol BarrageViewProtocol <NSObject>

@required
@property(nonatomic,strong)UIColor * backgroundColor;
@property(nonatomic,assign)CGFloat borderWidth;
@property(nonatomic,strong)UIColor * borderColor;
/// 圆角,此属性十分影响绘制性能,谨慎使用
@property(nonatomic,assign)CGFloat cornerRadius;
/// 强制性大小,默认为CGSizeZero,大小自适应; 否则使用mandatorySize的值来设置view大小
@property(nonatomic,assign)CGSize mandatorySize;

@end

/// Action 弹幕协议
@protocol BarrageActionProtocol <NSObject>

/// 注入点击行为
@property(nonatomic,strong)BarrageClickAction clickAction;

@end

@protocol BarrageWithHeadProtocol <BarrageViewProtocol>
@required
@property(nonatomic,copy)NSString * text;
@required
@property (nonatomic, copy) NSString *imageUrl;
@required
@property (nonatomic, copy) NSString *userName;
@required
@property (nonatomic, copy) NSString *upCount;

@property(nonatomic,strong)UIColor * textColor; // 字体颜色
@property(nonatomic,assign)CGFloat fontSize;
@property(nonatomic,strong)NSString * fontFamily;
@property(nonatomic,retain)UIColor * shadowColor;
@property(nonatomic)CGSize shadowOffset;
@property(nonatomic,strong)NSAttributedString * attributedText;
@end
/// UILabel 弹幕协议
@protocol BarrageTextProtocol <BarrageViewProtocol>

@required
@property(nonatomic,copy)NSString * text;
@property(nonatomic,strong)UIColor * textColor; // 字体颜色
@property(nonatomic,assign)CGFloat fontSize;
@property(nonatomic,copy)NSString * fontFamily;
@property(nonatomic,strong)UIColor * shadowColor;
@property(nonatomic)CGSize shadowOffset;
@property(nonatomic,strong)NSAttributedString * attributedText;

@end

/// UIImageView 弹幕协议
@protocol BarrageImageProtocol <BarrageViewProtocol>

@required
@property(nonatomic,strong)UIImage * image;

@end