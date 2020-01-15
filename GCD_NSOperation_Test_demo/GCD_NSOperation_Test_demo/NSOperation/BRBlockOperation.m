//
//  BRBlockOperation.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2020/1/15.
//  Copyright © 2020 毕博洋. All rights reserved.
//

#import "BRBlockOperation.h"

@implementation BRBlockOperation

+ (void)blockOperation {
    
    NSBlockOperation *op = [NSBlockOperation blockOperationWithBlock:^{
        for (int i = 0; i < 2; i++) {
            [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
            NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
        }
    }];
    [op start];
    
    
}

@end
