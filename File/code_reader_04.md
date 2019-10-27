# SDWebImage源码解读 (四)
###### SDWebImage (v4.4.1)-SDWebImageCache
```

#pragma mark--------本地查找缓存,注意，这里设计变化很大，原本是先判断内存图片，现在是开启磁盘队列的里面判断内存图片
// 先查询内存缓存，如果没有，然后再异步查找磁盘缓存
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(SDImageCacheOptions)options done:(nullable SDCacheQueryCompletedBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, SDImageCacheTypeNone);
        }
        return nil;
    }
    //1.先检查内存缓存
    // First check the in-memory cache...
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    //如果图片在内存中，并且没有强制要求查询磁盘，就返回
    BOOL shouldQueryMemoryOnly = (image && !(options & SDImageCacheQueryDataWhenInMemory));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, SDImageCacheTypeMemory);
        }
        //返回nil 因为不是异步操作
        return nil;
    }
    // 2.开启异步队列，读取磁盘缓存
    NSOperation *operation = [NSOperation new];
    void(^queryDiskBlock)(void) =  ^{
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            return;
        }
        //有大量中间临时变量产生时，避免内存使用峰值过高，需要及时释放内存
        @autoreleasepool {
            NSData *diskData = [self diskImageDataBySearchingAllPathsForKey:key];
            UIImage *diskImage;
            SDImageCacheType cacheType = SDImageCacheTypeDisk;
            //如果有图片，说明有磁盘中有缓存
            if (image)
            {
                // the image is from in-memory cache
                diskImage = image;
                cacheType = SDImageCacheTypeMemory;
            }
            else if (diskData)
            {
                //如果没有内存缓存，但是如果有磁盘数据，就解码图像数据
                // decode image data only if in-memory cache missed
                diskImage = [self diskImageForKey:key data:diskData options:options];
                // 3.如果解码成功，并且需要缓存到内存中，就添加到内存中
                if (diskImage && self.config.shouldCacheImagesInMemory)
                {
                    //计算图片像素点作为cost，添加到内存中
                    NSUInteger cost = SDCacheCostForImage(diskImage);
                    [self.memCache setObject:diskImage forKey:key cost:cost];
                }
            }
            
            if (doneBlock)
            {
                //如果设置了同步查询磁盘缓存，回调也要回调主线程
                if (options & SDImageCacheQueryDiskSync) {
                    doneBlock(diskImage, diskData, cacheType);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock(diskImage, diskData, cacheType);
                    });
                }
            }
        }
    };
    
    if (options & SDImageCacheQueryDiskSync) {
        queryDiskBlock();
    } else {
        dispatch_async(self.ioQueue, queryDiskBlock);
    }
    return operation;
}

```
这里我们逐步分析一下：
最开始，先去判断一下key(也就是图片url)是否为空。然后再去检查内存缓存，如果图片在内存中，并且没有强制要求查询磁盘，就返回。
这里出现了一种特殊情况，如果是要求了强制检查磁盘缓存。即使内存缓存有数据，也会继续去查找数据。
这里是往上查找`SDImageCacheQueryDataWhenInMemory`->`SDWebImageQueryDataWhenInMemory`
它的注释为
```
    /**
     * By default, we do not query disk data when the image is cached in memory. This mask can force to query disk data at the same time.
     * This flag is recommend to be used with `SDWebImageQueryDiskSync` to ensure the image is loaded in the same runloop.
     */
     正常情况下，当图像存在内存中的时候，我们不会查询磁盘数据。这个选项可以强制查询磁盘数据。
     此标志建议与“SDWebImageQueryDiskSync”一起使用，以确保图像加载在同一个运行循环中。
```

然后我们要去查找磁盘数据
```
// 查找磁盘缓存中图片二进制数据
- (nullable NSData *)diskImageDataBySearchingAllPathsForKey:(nullable NSString *)key {
    // 读取磁盘缓存（沙盒）
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }

    // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
    // checking the key with and without the extension
    // 如果沙盒里没有，就去掉扩展名试试，因为获取磁盘文件路径添加了扩展名（存的时候怎么存的？？？）

    data = [NSData dataWithContentsOfFile:defaultPath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }
    //如果还是没有，就读取bundle中的数据 （addReadOnlyCachePath 获取到的那个）
    NSArray<NSString *> *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
        if (imageData) {
            return imageData;
        }

        // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
        // checking the key with and without the extension
        imageData = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
        if (imageData) {
            return imageData;
        }
    }

    return nil;
}
```
这里获取磁盘数据的方法调用流程为`diskImageDataBySearchingAllPathsForKey`->`defaultCachePathForKey`->`cachePathForKey:inPath`->`cachedFileNameForKey`。
从后往前看:
```
//图片存储路径
- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}
```
我猜想这里使用MD5的原因：
> 一方面可能是因为安全策略的原因。但是更重要的是保证存储的key的读取安全。
 比如说，有一个这样的图片url**http://img.com/bby**。按照SDWebImage的存储策略，可能会形成类似这样的key:**/var/Applications/[application]/documents/http://img.com/bby**，甚至可能更混乱的路径。
 
## 缓存图片
  ```
  //根据key去异步缓存image，toDisk为NO不存储在磁盘 多加一个imageData图片data
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    if (!image || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    // if memory cache is enabled
    if (self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = SDCacheCostForImage(image);
        [self.memCache setObject:image forKey:key cost:cost];
    }
    
    if (toDisk)
    {
        //异步串行队列
        dispatch_async(self.ioQueue, ^{
            @autoreleasepool {
                NSData *data = imageData;
                if (!data && image) {
                    // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                    SDImageFormat format;
                    if (SDCGImageRefContainsAlpha(image.CGImage)) {
                        format = SDImageFormatPNG;
                    } else {
                        format = SDImageFormatJPEG;
                    }
                    data = [[SDWebImageCodersManager sharedInstance] encodedDataWithImage:image format:format];
                }
                [self _storeImageDataToDisk:data forKey:key];
            }
            
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        });
    } else {
        if (completionBlock) {
            completionBlock();
        }
    }
}

// Make sure to call form io queue by caller
- (void)_storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:_diskCachePath]) {
        [self.fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    // get cache Path for image key
    NSString *cachePathForKey = [self defaultCachePathForKey:key];
    // transform to NSUrl
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
    
    [imageData writeToURL:fileURL options:self.config.diskCacheWritingOptions error:nil];
    
    // disable iCloud backup
    if (self.config.shouldDisableiCloud) {
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

  ```
  可以发现，缓存数据需要在串行队列 **ioQueue** 中同步执行，主要任务就是新建存储图片数据的文件夹，并使用 **[_fileManager createFileAtPath:cachePathForKey contents:imageData attributes:nil]** 把imageData写入该路径下。

## 判断图片类型
使用这个方法来判断
```
BOOL SDCGImageRefContainsAlpha(CGImageRef imageRef) {
    if (!imageRef) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}
```
这个方法实际上是判断图片是否包含alpha通道
>* jpeg是有损压缩，可能会造成图片的破坏，并且没有alpha通道；
>* PNG是一种无损压缩。不会破坏图片，可以有透明效果。 
  