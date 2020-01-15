//
//  BRDispatchApply.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2018/1/13.
//  Copyright © 2018 毕博洋. All rights reserved.
//

#import "BRDispatchApply.h"

@implementation BRDispatchApply

-(void)dispatchApply {
    
    dispatch_queue_t queue = dispatch_queue_create("myqueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_apply(1000, queue, ^(size_t index) {
        NSLog(@"apply is %zu",index);
    });
 
    //在某些数量很大并且不需要顺序的遍历操作中可以使用，会自动控制线程
    
    
}

-(void)forin{
    
    for (int i = 0; i<1000; i ++) {
        NSLog(@"log %d",i);
    }
}




@end
