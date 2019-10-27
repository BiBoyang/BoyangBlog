# SDWebImage源码解读 (三)
####### SDWebImage (v4.4.1)-SDWebImageDownloader
```
- (nullable SDWebImageDownloadToken *)downloadImageWithURL:(nullable NSURL *)url
                                                   options:(SDWebImageDownloaderOptions)options
                                                  progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                                                 completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, nil, NO);
        }
        return nil;
    }
    
    LOCK(self.operationsLock);
    NSOperation<SDWebImageDownloaderOperationInterface> *operation = [self.URLOperations objectForKey:url];
    // There is a case that the operation may be marked as finished, but not been removed from `self.URLOperations`.
    if (!operation || operation.isFinished) {
        //创建下载队列
        operation = [self createDownloaderOperationWithUrl:url options:options];
        
        __weak typeof(self) wself = self;
        operation.completionBlock = ^{
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            LOCK(sself.operationsLock);
            [sself.URLOperations removeObjectForKey:url];
            UNLOCK(sself.operationsLock);
        };
        [self.URLOperations setObject:operation forKey:url];
        // Add operation to operation queue only after all configuration done according to Apple's doc.
        // `addOperation:` does not synchronously execute the `operation.completionBlock` so this will not cause deadlock.
        [self.downloadQueue addOperation:operation];
    }
    UNLOCK(self.operationsLock);

    id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock];
    
    SDWebImageDownloadToken *token = [SDWebImageDownloadToken new];
    token.downloadOperation = operation;
    token.url = url;
    token.downloadOperationCancelToken = downloadOperationCancelToken;

    return token;
}
```
下载图片的代码如上。
这里的会对url先进行判空，如果是空的，就直接返回。
然后会创建一个
```
//下载url作为key value是具体的下载operation 用字典来存储，方便cancel等操作
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, NSOperation<SDWebImageDownloaderOperationInterface> *> *URLOperations;
```


这里我们会去创建一个新的方法；
```
- (NSOperation<SDWebImageDownloaderOperationInterface> *)createDownloaderOperationWithUrl:(nullable NSURL *)url
                                                                                  options:(SDWebImageDownloaderOptions)options {
    NSTimeInterval timeoutInterval = self.downloadTimeout;
    //超时时间
    if (timeoutInterval == 0.0) {
        timeoutInterval = 15.0;
    }

    // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests if told otherwise
    //为了防止潜在的重复缓存(NSURLCache + SDImageCache)，如果被告知，我们会禁用图像请求的缓存。
    NSURLRequestCachePolicy cachePolicy = options & SDWebImageDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData;
    //创建request 设置请求缓存策略 下载时间
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:cachePolicy
                                                            timeoutInterval:timeoutInterval];
    
    request.HTTPShouldHandleCookies = (options & SDWebImageDownloaderHandleCookies);
    //HTTPShouldUsePipelining设置为YES, 则允许不必等到response, 就可以再次请求. 这个会很大的提高网络请求的效率,但是也可能会出问题
    //因为客户端无法正确的匹配请求与响应, 所以这依赖于服务器必须保证,响应的顺序与客户端请求的顺序一致.如果服务器不能保证这一点, 那可能导致响应和请求混乱.
    request.HTTPShouldUsePipelining = YES;
    if (self.headersFilter) {
        request.allHTTPHeaderFields = self.headersFilter(url, [self allHTTPHeaderFields]);
    }
    else {
        request.allHTTPHeaderFields = [self allHTTPHeaderFields];
    }
    
    NSOperation<SDWebImageDownloaderOperationInterface> *operation = [[self.operationClass alloc] initWithRequest:request inSession:self.session options:options];
    operation.shouldDecompressImages = self.shouldDecompressImages;
    
    //身份认证 当移动端和服务器在传输过程中，服务端有可能在返回Response时附带认证，询问 HTTP 请求的发起方是谁，这时候发起方应提供正确的用户名和密码（即认证信息）。这时候就需要NSURLCredential身份认证
    if (self.urlCredential) {
        operation.credential = self.urlCredential;
    } else if (self.username && self.password) {
        operation.credential = [NSURLCredential credentialWithUser:self.username password:self.password persistence:NSURLCredentialPersistenceForSession];
    }
    
    if (options & SDWebImageDownloaderHighPriority) {
        operation.queuePriority = NSOperationQueuePriorityHigh;
    } else if (options & SDWebImageDownloaderLowPriority) {
        operation.queuePriority = NSOperationQueuePriorityLow;
    }
    
    //设置下载的顺序 是按照队列还是栈
    if (self.executionOrder == SDWebImageDownloaderLIFOExecutionOrder) {
        // Emulate LIFO execution order by systematically adding new operations as last operation's dependency
        //通过依赖来模拟LIFO
        [self.lastAddedOperation addDependency:operation];
        self.lastAddedOperation = operation;
    }

    return operation;
}
```
在这里，通过调用
```
    NSOperation<SDWebImageDownloaderOperationInterface> *operation = [[self.operationClass alloc] initWithRequest:request inSession:self.session options:options];
```

#### SDWebImageDownloaderOperation
来创建一个新的NSOperation。因为是NSOperation，所以它会直接调用**start**方法。所以接下来，会在`SDWebImageDownloaderOperation`类中，通过重写start方法来处理下载和缓存的关系。
在这里方法里，核心是围绕
```
@property (strong, nonatomic, nonnull) NSMutableArray<SDCallbacksDictionary *> *callbackBlocks;
```
这个方法来进行一套回调，在获取到网络回调的时候，会先遍历数组，然后会根据url来作为key，获取这里所有key对应的回调。
这里为了保证不出线程冲突，使用了dispatch_semaphore_wait这个lock。
>* 这里使用这个有意思的，有dictionary属性array的原因，是因为array是有序的。可以变相的使这个兼具array和dictionary的特性。利用dictionary的hash能力，保证同一个url只会下载一次。

在NSOperation中，有三个状态来表示任务状态
* **isExecuting** - 代表任务正在执行中
* **isFinished** - 代表任务已经完成
* **isCancelled** - 代表任务已经取消执行

并使用这两个BOOL，来辅助。
```
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
@property (assign, nonatomic, getter = isFinished) BOOL finished;
```
在start方法中，假如我们配置的允许后台下载，我们可以继续在后台下载图片
```
        //如调用者配置了在后台可以继续下载图片，那么在这里继续下载
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            __weak __typeof__ (self) wself = self;
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;

                if (sself) {
                    [sself cancel];

                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
```

然后，正式的请求数据
```
        NSURLSession *session = self.unownedSession;
        //判断unownedSession是否为了nil，如果是nil则重新创建一个ownedSession
        if (!session) {
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            /**
             *  Create the session for this task
             *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
             *  method calls and completion handler calls.
             //delegateQueue为nil，所以回调方法默认在一个子线程的串行队列中执行
             */
            session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                    delegate:self
                                               delegateQueue:nil];
            self.ownedSession = session;
        }
        
        //获取网络请求的缓存数据
        if (self.options & SDWebImageDownloaderIgnoreCachedResponse)
        {
            // Grab the cached data for later check
            //获取缓存的数据以供以后检查。

            NSURLCache *URLCache = session.configuration.URLCache;
            if (!URLCache) {
                URLCache = [NSURLCache sharedURLCache];
            }
            NSCachedURLResponse *cachedResponse;
            // NSURLCache's `cachedResponseForRequest:` is not thread-safe, see https://developer.apple.com/documentation/foundation/nsurlcache#2317483
            @synchronized (URLCache) {
                cachedResponse = [URLCache cachedResponseForRequest:self.request];
            }
            if (cachedResponse) {
                self.cachedData = cachedResponse.data;
            }
        }
        //使用session来创建一个NSURLSessionDataTask类型下载任务
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
```
注意，这里的unownedSession是使用**weak**来修饰的，其实是因为它是从上一层传过来的值的赋值。我们并不需要关心它的生命周期。
而在cancel方法里
```
- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}

- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];
    //如果下载图片的任务仍在 则立即取消cancel，并且发送结束下载的通知
    if (self.dataTask) {
        [self.dataTask cancel];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:weakSelf];
        });

        // As we cancelled the task, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }

    [self reset];
}
......
//重新设置数据
- (void)reset {
    LOCK(self.callbacksLock);
    
    //删除回调块字典数组的所有元素
    [self.callbackBlocks removeAllObjects];
    UNLOCK(self.callbacksLock);
    self.dataTask = nil;
    
    //如果ownedSession存在，则手动调用invalidateAndCancel进行任务
    if (self.ownedSession) {
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}

```
我们可以发现，在cancel方法里，会在保证线程安全的情况下直接调用父类的cancel方法。
但是如果这个下载的任务还在的情况下，我们需要连带着把这个下载任务也取消掉。
而不管下载任务在不在，都要再去判断ownedSession是否存在，还有的话，就去调用 **[self.ownedSession invalidateAndCancel];**和**self.ownedSession = nil;**这两个方法来取消NSURLSession。
然后接下来，就是图像处理的一部分
#### NSURLSessionTaskDelegate
```
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!self.imageData)
    {
        //根据response返回的文件大小创建可变data
        self.imageData = [[NSMutableData alloc] initWithCapacity:self.expectedSize];
    }
    //向可变数据中添加接收到的数据
    [self.imageData appendData:data];

    //如果调用者配置了需要支持progressive下载，即展示已经下载的部分，并expectedSize返回的图片size大于0
    if ((self.options & SDWebImageDownloaderProgressiveDownload) && self.expectedSize > 0) {
        // Get the image data
        __block NSData *imageData = [self.imageData copy];
        // Get the total bytes downloaded
        const NSInteger totalSize = imageData.length;
        // Get the finish status
        //判断是否已经下载完成
        
        BOOL finished = (totalSize >= self.expectedSize);
        
        //如果不存在解压对象就去创建一个新的
        if (!self.progressiveCoder) {
            // We need to create a new instance for progressive decoding to avoid conflicts
            for (id<SDWebImageCoder>coder in [SDWebImageCodersManager sharedInstance].coders) {
                if ([coder conformsToProtocol:@protocol(SDWebImageProgressiveCoder)] &&
                    [((id<SDWebImageProgressiveCoder>)coder) canIncrementallyDecodeFromData:imageData]) {
                    self.progressiveCoder = [[[coder class] alloc] init];
                    break;
                }
            }
        }
        
        // progressive decode the image in coder queue
        dispatch_async(self.coderQueue, ^{
            //将imageData转化为image
            @autoreleasepool {
                UIImage *image = [self.progressiveCoder incrementallyDecodedImageWithData:imageData finished:finished];
                if (image) {
                    
                    //通过URL获取缓存的key
                    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
                    image = [self scaledImageForKey:key image:image];
                    if (self.shouldDecompressImages) {
                        //如果调用者选择了解压图片，那么在这里执行图片解压，这里注意，传入的data是一个**，指向指针的指针，要用&data表示
                        image = [[SDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&imageData options:@{SDWebImageCoderScaleDownLargeImagesKey: @(NO)}];
                    }
                    
                    // We do not keep the progressive decoding image even when `finished`=YES. Because they are for view rendering but not take full function from downloader options. And some coders implementation may not keep consistent between progressive decoding and normal decoding.
                    
                    [self callCompletionBlocksWithImage:image imageData:nil error:nil finished:NO];
                }
            }
        });
    }

    for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
        progressBlock(self.imageData.length, self.expectedSize, self.request.URL);
    }
}
```
这里图像的核心方法是如此
```
- (UIImage *)incrementallyDecodedImageWithData:(NSData *)data finished:(BOOL)finished {
    if (!_imageSource) {
        _imageSource = CGImageSourceCreateIncremental(NULL);
    }
    UIImage *image;
    
    // The following code is from http://www.cocoaintheshell.com/2011/05/progressive-images-download-imageio/
    // Thanks to the author @Nyx0uf
    
    // Update the data source, we must pass ALL the data, not just the new bytes
    CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)data, finished);
    
    if (_width + _height == 0) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, NULL);
        if (properties) {
            NSInteger orientationValue = 1;
            CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_height);
            val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_width);
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) CFNumberGetValue(val, kCFNumberNSIntegerType, &orientationValue);
            CFRelease(properties);
            
            // When we draw to Core Graphics, we lose orientation information,
            // which means the image below born of initWithCGIImage will be
            // oriented incorrectly sometimes. (Unlike the image born of initWithData
            // in didCompleteWithError.) So save it here and pass it on later.
#if SD_UIKIT || SD_WATCH
            _orientation = [SDWebImageCoderHelper imageOrientationFromEXIFOrientation:orientationValue];
#endif
        }
    }
    
    if (_width + _height > 0) {
        // Create the image
        CGImageRef partialImageRef = CGImageSourceCreateImageAtIndex(_imageSource, 0, NULL);
        
        if (partialImageRef) {
#if SD_UIKIT || SD_WATCH
            image = [[UIImage alloc] initWithCGImage:partialImageRef scale:1 orientation:_orientation];
#elif SD_MAC
            image = [[UIImage alloc] initWithCGImage:partialImageRef size:NSZeroSize];
#endif
            CGImageRelease(partialImageRef);
            image.sd_imageFormat = [NSData sd_imageFormatForImageData:data];
        }
    }
    
    if (finished) {
        if (_imageSource) {
            CFRelease(_imageSource);
            _imageSource = NULL;
        }
    }
    
    return image;
}
```
直接通过渲染绘制出UIImage。