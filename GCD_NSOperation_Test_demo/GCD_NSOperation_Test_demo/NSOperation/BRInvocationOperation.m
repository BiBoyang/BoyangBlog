//
//  BRInvocationOperation.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2020/1/15.
//  Copyright © 2020 毕博洋. All rights reserved.
//

#import "BRInvocationOperation.h"

@implementation BRInvocationOperation

+ (void)InvocationOperation {
    
    // 1.创建 NSInvocationOperation 对象
    NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(task1) object:nil];

    // 2.调用 start 方法开始执行操作
    [op start];
}


- (void)task1 {
    for (int i = 0; i < 2; i++) {
        [NSThread sleepForTimeInterval:2]; // 模拟耗时操作
        NSLog(@"1---%@", [NSThread currentThread]); // 打印当前线程
    }
}




@end
