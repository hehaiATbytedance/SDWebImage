//
//  SDImageCoder.m
//  SDWebImage
//
//  Created by 刘德平 on 2017/10/12.
//  Copyright © 2017年 Dailymotion. All rights reserved.
//

#import "SDImageCoder.h"
#import <pthread.h>


CGColorSpaceRef SDCGColorSpaceGetDeviceRGB() {
    static CGColorSpaceRef space;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        space = CGColorSpaceCreateDeviceRGB();
    });
    return space;
}

CGImageRef SDCGImageCreateDecodedCopy(CGImageRef imageRef, BOOL decodeForDisplay) {
    if (!imageRef) return NULL;
    size_t width = CGImageGetWidth(imageRef);
    size_t height = CGImageGetHeight(imageRef);
    if (width == 0 || height == 0) return NULL;
    
    if (decodeForDisplay) { //decode with redraw (may lose some precision)
        CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef) & kCGBitmapAlphaInfoMask;
        BOOL hasAlpha = NO;
        if (alphaInfo == kCGImageAlphaPremultipliedLast ||
            alphaInfo == kCGImageAlphaPremultipliedFirst ||
            alphaInfo == kCGImageAlphaLast ||
            alphaInfo == kCGImageAlphaFirst) {
            hasAlpha = YES;
        }
        // BGRA8888 (premultiplied) or BGRX8888
        // same as UIGraphicsBeginImageContext() and -[UIView drawRect:]
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Host;
        bitmapInfo |= hasAlpha ? kCGImageAlphaPremultipliedFirst : kCGImageAlphaNoneSkipFirst;
        CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, 0, SDCGColorSpaceGetDeviceRGB(), bitmapInfo);
        if (!context) return NULL;
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef); // decode
        CGImageRef newImage = CGBitmapContextCreateImage(context);
        CFRelease(context);
        return newImage;
        
    } else {
        CGColorSpaceRef space = CGImageGetColorSpace(imageRef);
        size_t bitsPerComponent = CGImageGetBitsPerComponent(imageRef);
        size_t bitsPerPixel = CGImageGetBitsPerPixel(imageRef);
        size_t bytesPerRow = CGImageGetBytesPerRow(imageRef);
        CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(imageRef);
        if (bytesPerRow == 0 || width == 0 || height == 0) return NULL;
        
        CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
        if (!dataProvider) return NULL;
        CFDataRef data = CGDataProviderCopyData(dataProvider); // decode
        if (!data) return NULL;
        
        CGDataProviderRef newProvider = CGDataProviderCreateWithCFData(data);
        CFRelease(data);
        if (!newProvider) return NULL;
        
        CGImageRef newImage = CGImageCreate(width, height, bitsPerComponent, bitsPerPixel, bytesPerRow, space, bitmapInfo, newProvider, NULL, false, kCGRenderingIntentDefault);
        CFRelease(newProvider);
        return newImage;
    }
}

@implementation SDImageCoder
{
    pthread_mutex_t _lock;
    BOOL _sourceTypeDetected;
    CGImageSourceRef _source;
}

- (BOOL)updateData:(NSData *)data final:(BOOL)final
{
    BOOL result = NO;
    pthread_mutex_lock(&_lock);
    result = [self _updateData:data final:final];
    pthread_mutex_unlock(&_lock);
    return result;
}

- (UIImage *)imageAtIndex:(NSInteger)index decodeForDisplay:(BOOL)decodeForDisplay
{
    pthread_mutex_lock(&_lock);
    _image = [self _imageAtIndex:index decodeForDisplay:decodeForDisplay];
    pthread_mutex_unlock(&_lock);
    return _image;
}

- (NSDictionary *)framePropertiesAtIndex:(NSUInteger)index
{
    NSDictionary *result = nil;
    pthread_mutex_lock(&_lock);
    result = [self _framePropertiesAtIndex:index];
    pthread_mutex_unlock(&_lock);
    return result;
}

- (NSDictionary *)_framePropertiesAtIndex:(NSUInteger)index
{
    if (!_source) return nil;
    CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_source, index, NULL);
    if (!properties) return nil;
    return CFBridgingRelease(properties);
}

- (UIImage *)_imageAtIndex:(NSInteger)index decodeForDisplay:(BOOL)decodeForDisplay
{
    BOOL decoded = NO;
    CGImageRef imageRef = [self _newUnlendedImageAtIndex:index decoded:&decoded];
    if (!imageRef) return nil;
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:2 orientation:UIImageOrientationUp];
    CFRelease(imageRef);
    return image;
}

- (CGImageRef)_newUnlendedImageAtIndex:(NSInteger)index decoded:(BOOL *)decoded
{
    CGImageRef imageRef = CGImageSourceCreateImageAtIndex(_source, index, (CFDictionaryRef)@{(id)kCGImageSourceShouldCache:@(YES)});
    if (imageRef) {
        CGImageRef imageRefExtended = SDCGImageCreateDecodedCopy(imageRef, YES);
        if (imageRefExtended) {
            CFRelease(imageRef);
            imageRef = imageRefExtended;
            if (decoded) *decoded = YES;
        }
    }
    return imageRef;
}

- (BOOL)_updateData:(NSData *)data final:(BOOL)final
{
    if (_finalized) return NO;
    if (data.length < _data.length) return NO;
    _finalized = final;
    _data = data;
    
    SDImageFormat imageType = [NSData sd_imageFormatForImageData:data];
    if (_sourceTypeDetected) {
        if (_imageType != imageType) {
            return NO;
        } else {
            [self _updateSource];
        }
    } else {
        if (_data.length > 16) {
            _imageType = imageType;
            _sourceTypeDetected = YES;
            [self _updateSource];
        }
    }
    return YES;
}

- (void)_updateSource
{
    [self _updateSourceImageIO];
}

- (void)_updateSourceImageIO
{
    if (!_source) {
        if (_finalized) {
            _source = CGImageSourceCreateWithData((__bridge CFDataRef)_data, NULL);
        } else {
            _source = CGImageSourceCreateIncremental(NULL);
            if (_source) CGImageSourceUpdateData(_source, (__bridge CFDataRef)_data, false);
        }
    } else {
        CGImageSourceUpdateData(_source, (__bridge CFDataRef)_data, _finalized);
    }
    if (!_source) return;
    _framesCount = CGImageSourceGetCount(_source);
}

@end
