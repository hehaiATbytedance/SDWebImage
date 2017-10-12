//
//  SDImageCoder.h
//  SDWebImage
//
//  Created by 刘德平 on 2017/10/12.
//  Copyright © 2017年 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSData+ImageContentType.h"

@interface SDImageCoder : NSObject

@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, readonly, getter=isFinalized) BOOL finalized;
@property (nonatomic, readonly) SDImageFormat imageType;
@property (nonatomic, strong, readonly) UIImage *image;
@property (nonatomic, readonly) NSUInteger framesCount;

- (BOOL)updateData:(NSData *)data final:(BOOL)final;

- (UIImage *)imageAtIndex:(NSInteger)index decodeForDisplay:(BOOL)decodeForDisplay;

- (NSDictionary *)framePropertiesAtIndex:(NSUInteger)index;

@end
