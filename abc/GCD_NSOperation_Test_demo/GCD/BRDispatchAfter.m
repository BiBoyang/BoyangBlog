//
//  BRDispatchAfter.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2018/1/13.
//  Copyright © 2018 毕博洋. All rights reserved.
//

#import "BRDispatchAfter.h"

@implementation BRDispatchAfter

-(void)dispatchAfter {
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5* NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"wait 5 sec");
    });
    
    
    
}

@end
