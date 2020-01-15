//
//  BRDispatchGroup.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2018/1/15.
//  Copyright © 2018 毕博洋. All rights reserved.
//

#import "BRDispatchGroup.h"

@implementation BRDispatchGroup

+ (void)dispatchGroup {
    dispatch_queue_t queue = dispatch_queue_create("queue_test", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_async(group, queue, ^{
        NSLog(@"任务1");
        sleep(3);
        NSLog(@"任务2");
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"任务完成");
        NSLog(@"%d",[NSThread isMainThread]);
    });
    
    
}



@end
