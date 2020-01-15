//
//  BRDispatchSemaphore.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2020/1/15.
//  Copyright © 2020 毕博洋. All rights reserved.
//

#import "BRDispatchSemaphore.h"

@implementation BRDispatchSemaphore

+(void)semaphore {

        dispatch_group_t group = dispatch_group_create();
    // 创建信号量，并且设置值为10
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(10);
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        for (int i = 0; i < 100; i++){
            //信号-1
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            dispatch_group_async(group, queue, ^{
                NSLog(@"%i",i);
                sleep(2);
                //信号+1，
                dispatch_semaphore_signal(semaphore);
            });
        }
    
    
    
}

@end
