//
//  ViewController.m
//  KVO_demo
//
//  Created by 毕博洋 on 2019/12/11.
//  Copyright © 2019 毕博洋. All rights reserved.
//

#import "ViewController.h"
#import "Fish.h"
@import ObjectiveC.objc;
@import ObjectiveC.runtime;
#import "SmallFish.h"

@interface ViewController ()

@property (nonatomic, strong) Fish *saury;
@property (nonatomic, strong) Fish *carpio;

@property (nonatomic, strong) SmallFish *smailSaury;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
     //添加监听
    
    self.saury = [[Fish alloc]init];
    [self.saury setValue:@"14.0" forKey:@"price"];
    [self.saury setValue:@"blue" forKey:@"color"];
    
    self.carpio = [[Fish alloc]init];
    
     
    [self.saury description];
    [self.carpio description];
    
     [self.saury addObserver:self forKeyPath:@"price" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:"bbb"];
     
     [self.saury addObserver:self forKeyPath:@"color" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:(__bridge void * _Nullable)([NSString stringWithFormat:@"yellow"])];
    
    
    [self.saury description];
    [self.carpio description];
    
    /*
    self.smailSaury = [[SmallFish alloc]init];
    [self.smailSaury setValue:@"14.0" forKey:@"price"];
    [self.smailSaury description];
    
    [self.smailSaury addObserver:self forKeyPath:@"price" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:"bbb"];
    
    
     [self.smailSaury description];
    */
    
    
    
    
    
    
    
     UIButton *abtn = [UIButton buttonWithType:UIButtonTypeCustom];
     abtn.frame = CGRectMake(80, 90.0, 80, 30);
     [abtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
     [abtn setTitle:@"Change" forState:UIControlStateNormal];
     [abtn addTarget:self action:@selector(change) forControlEvents:UIControlEventTouchUpInside];
     [self.view addSubview:abtn];
    
}



-(void)change {
    [self.saury setValue:@"34.0" forKey:@"price"];
    [self.saury setValue:@"red" forKey:@"color"];
//    [self.smailSaury setValue:@"34.0" forKey:@"price"];
    
}

-(void)dealloc {
    //移除监听
    [self.saury removeObserver:self forKeyPath:@"price" context:(__bridge void * _Nullable)([NSString stringWithFormat:@"yellow"])];
    [self.saury removeObserver:self forKeyPath:@"price" context:@"bbb"];
    
    
}



//实现监听
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
       
    NSLog(@"keyPath is %@",keyPath);
    NSLog(@"object is %@",object);
    NSLog(@"change is %@",change);
    

    if([keyPath isEqualToString:@"color"]) {
        NSString *str = (__bridge NSString *)(context);
        NSLog(@"___%@",str);
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}





@end
