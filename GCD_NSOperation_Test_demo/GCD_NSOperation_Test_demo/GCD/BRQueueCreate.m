//
//  BRQueueCreate.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2018/1/13.
//  Copyright © 2018 毕博洋. All rights reserved.
//

#import "BRQueueCreate.h"

@implementation BRQueueCreate

-(void)mainQueue {
    
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"Is main thread? %d", [NSThread isMainThread]);
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSLog(@"Is main thread? %d", [NSThread isMainThread]);
    });
    
    
    dispatch_queue_t queue = dispatch_queue_create("testQueue", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(queue, ^{
        sleep(1);
        NSLog(@"ConcurrentQueue");
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"mainQueue");
        });
    });
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(5);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"mainQueue");
        });
    });
    
    

    
    
    
    
    dispatch_queue_t mySerialDispatchQueue = dispatch_queue_create("com.example.gcd.mySerialDispatchQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(mySerialDispatchQueue, ^{
        [self bk0];
    });
    dispatch_async(mySerialDispatchQueue, ^{
        [self bk1];
    });
    dispatch_async(mySerialDispatchQueue, ^{
        [self bk2];
    });
    
    dispatch_queue_t mainDispatchQueue = dispatch_get_main_queue();
    
    dispatch_async(mainDispatchQueue, ^{
        [self bk4];
    });
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"main");
    });
    
}

-(void)bk0 {
    NSLog(@"bk0");
    
}


-(void)bk1 {
    NSLog(@"bk1");
    
}
-(void)bk2 {
    NSLog(@"bk2");
    
}

-(void)bk4 {
    NSLog(@"bk4");
    
}


@end
