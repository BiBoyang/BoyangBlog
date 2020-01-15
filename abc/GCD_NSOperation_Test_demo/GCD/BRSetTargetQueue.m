//
//  BRSetTargetQueue.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2018/1/13.
//  Copyright © 2018 毕博洋. All rights reserved.
//

#import "BRSetTargetQueue.h"

@implementation BRSetTargetQueue

-(void)setTargetQueue {
    dispatch_queue_t mySerialDispatchQueue = dispatch_queue_create("com.example.gcd.mySerialDispatchQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t globalDispatchQueueBackground = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_set_target_queue(mySerialDispatchQueue, globalDispatchQueueBackground);
    
    
    
}



@end
