//
//  UIImage+SDWebImage.h
//  SDWebImage
//
//  Created by 刘德平 on 2017/10/12.
//  Copyright © 2017年 Dailymotion. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (SDWebImage)

- (UIImage *)sd_imageByBlurRadius:(CGFloat)blurRadius
                        tintColor:(UIColor *)tintColor
                         tintMode:(CGBlendMode)tintBlendMode
                       saturation:(CGFloat)saturation
                        maskImage:(UIImage *)maskImage;

@end
