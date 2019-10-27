# SDWebImage源码解读 (二)
###### SDWebImage (v4.4.1)-SDWebImageManager
以在一个UIImageView上加载网络图片为例，看看要经历那些流程。
第一步，调用
```
- (void)sd_setImageWithURL:(nullable NSURL *)url;
```
>* 这里运用了一个代码技巧，Designated Initializer，我们可以称之为"全能初始化法"。提供了一个初始化方法，其他方法均调用此方法。



第二步，调用
```
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(SDWebImageOptions)options
                  progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                 completed:(nullable SDExternalCompletionBlock)completedBlock;
```
第三步，调用
```   
/**
 * @param url            图片地址链接
 * @param placeholder    占位图
 * @param options        下载图片的枚举。包括优先级、是否写入硬盘等
 * @param operationKey   一个记录当前对象正在加载操作的key、保证只有最新的操作在进行、默认为类名。
                         所以如果你想下载多个图片并且都展示一下、可以尝试自定义几个operationKey来操作。（我猜）
 * @param setImageBlock  给开发者自定义set图片的callback
 * @param progressBlock  下载进度callback
 * @param completedBlock 下载完成的callback（sd已经给你set好了、只是会把图片给你罢了）
 * @param context        一些额外的上下文字典。比如你可以搞一个专属的imageManager进来干活。
 */

- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock;
```
这个方法是加载图片的最后一步。
```
- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock
                           context:(nullable NSDictionary<NSString *, id> *)context {
    
    NSString *validOperationKey = operationKey ?: NSStringFromClass([self class]);//省略版三目运算，实际上直接执行后边这个方法
    
    [self sd_cancelImageLoadOperationWithKey:validOperationKey];//取消之前的下载任务
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);//动态添加属性
    
    if (!(options & SDWebImageDelayPlaceholder)) {
        //如果模式不是 SDWebImageDelayPlaceholder, 则先设置占位图
        dispatch_main_async_safe(^{
            [self sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock];
        });
    }
    
    if (url) {
#if SD_UIKIT
        // check if activityView is enabled or not
        if ([self sd_showActivityIndicatorView]){
            [self sd_addActivityIndicator];
        }
#endif
        
        // reset the progress
        self.sd_imageProgress.totalUnitCount = 0;
        self.sd_imageProgress.completedUnitCount = 0;
        
        SDWebImageManager *manager = [context objectForKey:SDWebImageExternalCustomManagerKey];//创建一个空的单例
        if (!manager) {
            manager = [SDWebImageManager sharedManager];//创建单例
        }
        
        __weak __typeof(self)wself = self;
        SDWebImageDownloaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            wself.sd_imageProgress.totalUnitCount = expectedSize;
            wself.sd_imageProgress.completedUnitCount = receivedSize;
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        id <SDWebImageOperation> operation = [manager loadImageWithURL:url options:options progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            //图片下载&读取完成
            __strong __typeof (wself) sself = wself;
            if (!sself) { return; }
#if SD_UIKIT
            [sself sd_removeActivityIndicator];//移除进度条
#endif
            // if the progress not been updated, mark it to complete state
            if (finished && !error && sself.sd_imageProgress.totalUnitCount == 0 && sself.sd_imageProgress.completedUnitCount == 0) {
                sself.sd_imageProgress.totalUnitCount = SDWebImageProgressUnitCountUnknown;
                sself.sd_imageProgress.completedUnitCount = SDWebImageProgressUnitCountUnknown;
            }
            BOOL shouldCallCompletedBlock = finished || (options & SDWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & SDWebImageAvoidAutoSetImage)) ||
                                      (!image && !(options & SDWebImageDelayPlaceholder)));
            SDWebImageNoParamsBlock callCompletedBlockClojure = ^{
                if (!sself) { return; }
                if (!shouldNotSetImage) {
                    [sself sd_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    //操作完成的回调
                    completedBlock(image, error, cacheType, url);
                }
            };
            
            // case 1a: we got an image, but the SDWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the SDWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClojure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the SDWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & SDWebImageDelayPlaceholder) {
                // case 2b: we got no image and the SDWebImageDelayPlaceholder flag is set
                //如果没有image，则使用占位图
                targetImage = placeholder;
                targetData = nil;
            }
            
#if SD_UIKIT || SD_MAC
            // check whether we should use the image transition
            SDWebImageTransition *transition = nil;
            if (finished && (options & SDWebImageForceTransition || cacheType == SDImageCacheTypeNone)) {
                transition = sself.sd_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
#if SD_UIKIT || SD_MAC
                [sself sd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
#else
                [sself sd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock];
#endif
                callCompletedBlockClojure();
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
        //没有url的情况
        dispatch_main_async_safe(^{
#if SD_UIKIT
            [self sd_removeActivityIndicator];
#endif
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}

```

整个过程可以分为以下几部分。
**取消该控件之前的下载任务**->**将图片url作为属性关联到UIImageView**->**设置占位图**->**设置进度条**->**SDWebImageManager获取图片（同时将operation加入到SDOperationsDictionary）**->**成功/失败回调**

## SDWebImageManager获取图片获取图片
```
- (id <SDWebImageOperation>)loadImageWithURL:(nullable NSURL *)url
                                     options:(SDWebImageOptions)options
                                    progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                                   completed:(nullable SDInternalCompletionBlock)completedBlock {
    // Invoking this method without a completedBlock is pointless
    NSAssert(completedBlock != nil, @"If you mean to prefetch the image, use -[SDWebImagePrefetcher prefetchURLs] instead");

    // Very common mistake is to send the URL using NSString object instead of NSURL. For some strange reason, Xcode won't
    //非常奇怪的错误。
    // throw any warning for this type mismatch. Here we failsafe this error by allowing URLs to be passed as NSString.
    //为该类型不匹配抛出任何警告。这里我们通过允许URL作为NSString来传递这个错误。
    if ([url isKindOfClass:NSString.class])
    {
        url = [NSURL URLWithString:(NSString *)url];
    }

    // Prevents app crashing on argument type error like sending NSNull instead of NSURL
    if (![url isKindOfClass:NSURL.class])
    {
        url = nil;
    }
    //创建下载操作的对象
    SDWebImageCombinedOperation *operation = [SDWebImageCombinedOperation new];
    operation.manager = self;

    BOOL isFailedUrl = NO;
    if (url)
    {
        //加锁，这里原来使用@synchronized，后来换成dispatch_semaphore_wait，为了性能
        LOCK(self.failedURLsLock);
        isFailedUrl = [self.failedURLs containsObject:url];
        UNLOCK(self.failedURLsLock);
    }

    if (url.absoluteString.length == 0 || (!(options & SDWebImageRetryFailed) && isFailedUrl)) {
        //发出失败的回调
        [self callCompletionBlockForOperation:operation completion:completedBlock error:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorFileDoesNotExist userInfo:nil] url:url];
        return operation;
    }

    LOCK(self.runningOperationsLock);
    //将操作添加到正在进行的操作数池
    [self.runningOperations addObject:operation];
    UNLOCK(self.runningOperationsLock);
    
    //默认就是url作为key
    NSString *key = [self cacheKeyForURL:url];
    
    SDImageCacheOptions cacheOptions = 0;
    if (options & SDWebImageQueryDataWhenInMemory) cacheOptions |= SDImageCacheQueryDataWhenInMemory;
    if (options & SDWebImageQueryDiskSync) cacheOptions |= SDImageCacheQueryDiskSync;
    if (options & SDWebImageScaleDownLargeImages) cacheOptions |= SDImageCacheScaleDownLargeImages;
    
    __weak SDWebImageCombinedOperation *weakOperation = operation;
#pragma mark -----在本地查找缓存
    //通过key、查找本地图片
    operation.cacheOperation = [self.imageCache queryCacheOperationForKey:key options:cacheOptions done:^(UIImage *cachedImage, NSData *cachedData, SDImageCacheType cacheType) {
        __strong __typeof(weakOperation) strongOperation = weakOperation;
        if (!strongOperation || strongOperation.isCancelled)
        {
            //操作被取消、移除操作池
            [self safelyRemoveOperationFromRunning :strongOperation];
            return;
        }
        
        // Check whether we should download image from network
        //本地没有图片 || 刷新缓存
        BOOL shouldDownload = (!(options & SDWebImageFromCacheOnly))
            && (!cachedImage || options & SDWebImageRefreshCached)
            && (![self.delegate respondsToSelector:@selector(imageManager:shouldDownloadImageForURL:)] || [self.delegate imageManager:self shouldDownloadImageForURL:url]);
        if (shouldDownload) {
            if (cachedImage && options & SDWebImageRefreshCached) {
                //有本地图片。但需要被刷新
                // If image was found in the cache but SDWebImageRefreshCached is provided, notify about the cached image
                // AND try to re-download it in order to let a chance to NSURLCache to refresh it from server.
                //发出刷新图片的回调
                [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            }

            // download if no image or requested to refresh anyway, and download allowed by delegate
            //下面是根据调用者传进来的option，来匹配设置了哪些，就给downloaderOptions赋值哪些option

            SDWebImageDownloaderOptions downloaderOptions = 0;
            if (options & SDWebImageLowPriority) downloaderOptions |= SDWebImageDownloaderLowPriority;
            if (options & SDWebImageProgressiveDownload) downloaderOptions |= SDWebImageDownloaderProgressiveDownload;
            if (options & SDWebImageRefreshCached) downloaderOptions |= SDWebImageDownloaderUseNSURLCache;
            if (options & SDWebImageContinueInBackground) downloaderOptions |= SDWebImageDownloaderContinueInBackground;
            if (options & SDWebImageHandleCookies) downloaderOptions |= SDWebImageDownloaderHandleCookies;
            if (options & SDWebImageAllowInvalidSSLCertificates) downloaderOptions |= SDWebImageDownloaderAllowInvalidSSLCertificates;
            if (options & SDWebImageHighPriority) downloaderOptions |= SDWebImageDownloaderHighPriority;
            if (options & SDWebImageScaleDownLargeImages) downloaderOptions |= SDWebImageDownloaderScaleDownLargeImages;
            
            if (cachedImage && options & SDWebImageRefreshCached) {
                // force progressive off if image already cached but forced refreshing
                downloaderOptions &= ~SDWebImageDownloaderProgressiveDownload;
                // ignore image read from NSURLCache if image if cached but force refreshing
                downloaderOptions |= SDWebImageDownloaderIgnoreCachedResponse;
            }
            
            // `SDWebImageCombinedOperation` -> `SDWebImageDownloadToken` -> `downloadOperationCancelToken`, which is a `SDCallbacksDictionary` and retain the completed block below, so we need weak-strong again to avoid retain cycle
            //下载图片
            __weak typeof(strongOperation) weakSubOperation = strongOperation;
            strongOperation.downloadToken = [self.imageDownloader downloadImageWithURL:url options:downloaderOptions progress:progressBlock completed:^(UIImage *downloadedImage, NSData *downloadedData, NSError *error, BOOL finished) {
                __strong typeof(weakSubOperation) strongSubOperation = weakSubOperation;
                if (!strongSubOperation || strongSubOperation.isCancelled) {
                    // Do nothing if the operation was cancelled
                    // See #699 for more details
                    // if we would call the completedBlock, there could be a race condition between this block and another completedBlock for the same object, so if this one is called second, we will overwrite the new data
                } else if (error) {
                    [self callCompletionBlockForOperation:strongSubOperation completion:completedBlock error:error url:url];
                    BOOL shouldBlockFailedURL;
                    // Check whether we should block failed url
                    if ([self.delegate respondsToSelector:@selector(imageManager:shouldBlockFailedURL:withError:)]) {
                        shouldBlockFailedURL = [self.delegate imageManager:self shouldBlockFailedURL:url withError:error];
                    } else {
                        shouldBlockFailedURL = (   error.code != NSURLErrorNotConnectedToInternet
                                                && error.code != NSURLErrorCancelled
                                                && error.code != NSURLErrorTimedOut
                                                && error.code != NSURLErrorInternationalRoamingOff
                                                && error.code != NSURLErrorDataNotAllowed
                                                && error.code != NSURLErrorCannotFindHost
                                                && error.code != NSURLErrorCannotConnectToHost
                                                && error.code != NSURLErrorNetworkConnectionLost);
                    }
                    
                    if (shouldBlockFailedURL)
                    {
                        LOCK(self.failedURLsLock);
                        //失败记录
                        [self.failedURLs addObject:url];
                        UNLOCK(self.failedURLsLock);
                    }
                }
                else
                {
                    if ((options & SDWebImageRetryFailed))
                    {
                        //失败重新下载
                        LOCK(self.failedURLsLock);
                        //从失败记录移除
                        [self.failedURLs removeObject:url];
                        UNLOCK(self.failedURLsLock);
                    }
                    //是否磁盘缓存
                    BOOL cacheOnDisk = !(options & SDWebImageCacheMemoryOnly);
                    
                    // We've done the scale process in SDWebImageDownloader with the shared manager, this is used for custom manager and avoid extra scale.
                    if (self != [SDWebImageManager sharedManager] && self.cacheKeyFilter && downloadedImage) {
                        //缩放
                        downloadedImage = [self scaledImageForKey:key image:downloadedImage];
                    }

                    if (options & SDWebImageRefreshCached && cachedImage && !downloadedImage) {
                        // Image refresh hit the NSURLCache cache, do not call the completion block
                        //成功下载图片、自定义实现了图片处理的代理
                    } else if (downloadedImage && (!downloadedImage.images || (options & SDWebImageTransformAnimatedImage)) && [self.delegate respondsToSelector:@selector(imageManager:transformDownloadedImage:withURL:)])
                    {
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                            @autoreleasepool {
                                //获取转换用户后的图片
                                UIImage *transformedImage = [self.delegate imageManager:self transformDownloadedImage:downloadedImage withURL:url];
                                //用户处理成功
                                if (transformedImage && finished)
                                {
                                    BOOL imageWasTransformed = ![transformedImage isEqual:downloadedImage];
                                    NSData *cacheData;
                                    // pass nil if the image was transformed, so we can recalculate the data from the image
                                    if (self.cacheSerializer) {
                                        cacheData = self.cacheSerializer(transformedImage, (imageWasTransformed ? nil : downloadedData), url);
                                    } else  {
                                        cacheData = (imageWasTransformed ? nil : downloadedData);
                                    }
                                    //用户处理的后若未生成新的图片、则保存下载的二进制文件。
                                    //不然则由imageCache内部生成二进制文件保存
                                    [self.imageCache storeImage:transformedImage imageData:cacheData forKey:key toDisk:cacheOnDisk completion:nil];
                                }
                                //回调
                                [self callCompletionBlockForOperation:strongSubOperation completion:completedBlock image:transformedImage data:downloadedData error:nil cacheType:SDImageCacheTypeNone finished:finished url:url];
                            }
                        });
                    } else {
                        //下载成功且未自定义代理--默认保存
                        if (downloadedImage && finished) {
                            if (self.cacheSerializer) {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                    @autoreleasepool {
                                        NSData *cacheData = self.cacheSerializer(downloadedImage, downloadedData, url);
                                        [self.imageCache storeImage:downloadedImage imageData:cacheData forKey:key toDisk:cacheOnDisk completion:nil];
                                    }
                                });
                            } else {
                                [self.imageCache storeImage:downloadedImage imageData:downloadedData forKey:key toDisk:cacheOnDisk completion:nil];
                            }
                        }
                        //回调
                        [self callCompletionBlockForOperation:strongSubOperation completion:completedBlock image:downloadedImage data:downloadedData error:nil cacheType:SDImageCacheTypeNone finished:finished url:url];
                    }
                }

                if (finished) {
                    [self safelyRemoveOperationFromRunning:strongSubOperation];
                }
            }];
        } else if (cachedImage) {
            //本地有图片--回调、关闭当前操作
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:cachedImage data:cachedData error:nil cacheType:cacheType finished:YES url:url];
            [self safelyRemoveOperationFromRunning:strongOperation];
        } else {
            // Image not in cache and download disallowed by delegate
            //本地没有、也不下载--回调、关闭当前操作
            [self callCompletionBlockForOperation:strongOperation completion:completedBlock image:nil data:nil error:nil cacheType:SDImageCacheTypeNone finished:YES url:url];
            [self safelyRemoveOperationFromRunning:strongOperation];
        }
    }];

    return operation;
}

```
这里的开头部分，我们需要去判断url的合法性
```
    if ([url isKindOfClass:NSString.class])
    {
        url = [NSURL URLWithString:(NSString *)url];
    }
    ......
    if (![url isKindOfClass:NSURL.class])
    {
        url = nil;
    }
```
然后去创建下载操作的对象，这里我们需要再判断一次，url是否在失败清单上。
这里的失败列表是NSMutableSet来创建的，原因么，因为hash的原因，判断一个元素在不在里面非常高效。
同样的道理，如果url没有问题，就需要添加到正在进行操作的set中。

在这里，将url直接做为key。
```
    NSString *key = [self cacheKeyForURL:url];
```
然后，去看如何在本次查找缓存,这个同样是个非常复杂的方法。如果取消了操作，就把当前操作剔除出正在进行操作的set中。
这里有个有个不大眼熟的代码
```
if (cachedImage && options & SDWebImageRefreshCached) 
{
    // force progressive off if image already cached but forced refreshing
    downloaderOptions &= ~SDWebImageDownloaderProgressiveDownload;
    // ignore image read from NSURLCache if image if cached but force refreshing
                downloaderOptions |= SDWebImageDownloaderIgnoreCachedResponse;
            }
```
> x|=y; 等价于x=x|y; 为位运算里面的或
 x&=~y 等价于 x=x&(~y); 先对y取反 再和x做与运算



如果本地没有图片，或者需要刷新缓存，这里就需要去下载图片了。这里有个很有意思的点
> `SDWebImageCombinedOperation` -> `SDWebImageDownloadToken` -> `downloadOperationCancelToken`, which is a `SDCallbacksDictionary` and retain the completed block below, so we need weak-strong again to avoid retain cycle

这里产生了一个retain cycle。所以添加了一个循环
```
 __weak typeof(strongOperation) weakSubOperation = strongOperation;
         ......
__strong typeof(weakSubOperation) strongSubOperation = weakSubOperation;
```
下载成功之后，在全局队列将数据转换成为图片，并且存入缓存。





