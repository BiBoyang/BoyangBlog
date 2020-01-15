//
//  ViewController.m
//  GCD_NSOperation_Test_demo
//
//  Created by 毕博洋 on 2019/10/13.
//  Copyright © 2018 毕博洋. All rights reserved.
//

#import "ViewController.h"

#import "BRQueueCreate.h"
#import "BRDispatchAfter.h"
#import "BRDispatchApply.h"
#import "BRDispatchGroup.h"
#import "BRDispatchSemaphore.h"

#import "BRInvocationOperation.h"
#import "BRBlockOperation.h"
#import "BROperation.h"

#import "BRDispatchTimerController.h"

@interface ViewController ()

@property (nonatomic, strong) dispatch_source_t timer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
//    [[BRQueueCreate alloc]mainQueue];
    
//    [[BRDispatchAfter alloc]dispatchAfter];
    
//    [[BRDispatchApply alloc]dispatchApply];//0.438246
//    [[BRDispatchApply alloc]forin];//0.438547
    
//    [BRDispatchGroup dispatchGroup];
    
//    [BRDispatchSemaphore semaphore];
    
//    [BROperation addDependency];

    
    [self setupView];
    
    [self createTimer];
    
    
}

- (void)createTimer {
    
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    uint64_t interval = (uint64_t)(1.0 * NSEC_PER_SEC);
    
    // 设置参数
    dispatch_source_set_timer(self.timer, start, interval, 0);

    // 设置回调，即设置需要定时器定时执行的操作
    dispatch_source_set_event_handler(self.timer, ^{

        NSLog(@"------");

    });
    
    dispatch_resume(self.timer);
}

//暂停
-(void) pauseTimer{
    if(_timer){
        dispatch_suspend(_timer);
    }
}
//恢复
-(void) resumeTimer{
    if(_timer){
        dispatch_resume(_timer);
    }
}
//销毁
-(void) stopTimer{
    if(_timer){
        dispatch_source_cancel(_timer);
        _timer = nil;
    }
}


-(void)setupView {
    
    UIButton *button1 = [[UIButton alloc]init];
    button1.frame  = CGRectMake(100, 100, 100, 30);
    [self.view addSubview:button1];
    button1.backgroundColor = [UIColor redColor];
    [button1 addTarget:self action:@selector(pauseTimer) forControlEvents:(UIControlEventTouchUpInside)];
    
    
    
    UIButton *button2 = [[UIButton alloc]init];
    button2.frame  = CGRectMake(100, 200, 100, 30);
    [self.view addSubview:button2];
    button2.backgroundColor = [UIColor redColor];
    [button2 addTarget:self action:@selector(resumeTimer) forControlEvents:(UIControlEventTouchUpInside)];

    
    UIButton *button3 = [[UIButton alloc]init];
    button3.frame  = CGRectMake(100, 300, 100, 30);
    [self.view addSubview:button3];
    button3.backgroundColor = [UIColor redColor];
    [button3 addTarget:self action:@selector(stopTimer) forControlEvents:(UIControlEventTouchUpInside)];

    
}






@end
