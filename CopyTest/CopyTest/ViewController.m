//
//  ViewController.m
//  CopyTest
//
//  Created by 毕博洋 on 2020/7/10.
//  Copyright © 2020 毕博洋. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (nonatomic,strong) NSMutableString *mutableStringA;
@property (nonatomic,copy) NSString *stringA;


@property (nonatomic,strong) NSMutableString *stringB;

@property (nonatomic,copy) NSMutableString *stringC;

@property (nonatomic,strong) NSString *stringD;

@property (nonatomic,copy) NSString *stringE;

@property (nonatomic, copy) NSArray *arrayA;
@property (nonatomic, strong) NSMutableArray *arrayB;


@end

@implementation ViewController

#define BYLog(_var) ({ NSString *name = @#_var; NSLog(@"%@: %@ -> %p : %@", name, [_var class], _var, _var); })


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    int a = 0;
    
    NSLog(@"不可变对象----------------------");

    self.stringA = [NSString stringWithFormat:@"Boyangggggggggggggggggggggggggggggg"];
    
    BYLog(self.stringA);
    
    if(a == 0) {
        
    self.stringB = [self.stringA copy];//使用copy的话是不可以修改的
    BYLog(self.stringB);

    self.stringC = [self.stringA copy];//属性关键字是copy 所以本身不能再修改；不管是copy或者mutableCopy
    BYLog(self.stringC);
    
    self.stringD = [self.stringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
    BYLog(self.stringD);

    self.stringE = [self.stringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
    BYLog(self.stringE);
    
    } else {
        
        
        self.stringB = [self.stringA mutableCopy];//使用copy的话是可以修改的
        BYLog(self.stringB);
        [self.stringB appendString:@"test"];

        self.stringC = [self.stringA mutableCopy];
        BYLog(self.stringC);
//        [self.stringC appendString:@"test"];
            
        self.stringD = [self.stringA mutableCopy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringD);
//        [self.stringD appendString:@"test"];

        self.stringE = [self.stringA mutableCopy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringE);
//        [self.stringE appendString:@"test"];
        
    }
    
    
    NSLog(@"可变对象----------------------");

    self.mutableStringA = [NSMutableString stringWithFormat:@"Boyangggggggggggggggggggggggggggggg"];
    BYLog(self.mutableStringA);
    
    if(a == 0) {
        self.stringB = [self.mutableStringA copy];//使用copy的话是不可以修改的
        BYLog(self.stringB);

        self.stringC = [self.mutableStringA copy];//属性关键字是copy 所以本身不能再修改；不管是copy或者mutableCopy
        BYLog(self.stringC);
            
        self.stringD = [self.mutableStringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringD);

        self.stringE = [self.mutableStringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringE);
        
    } else {
        
        self.stringB = [self.mutableStringA mutableCopy];//使用copy的话是可以修改的
        BYLog(self.stringB);
        [self.stringB appendString:@"test"];

        self.stringC = [self.mutableStringA mutableCopy];//属性关键字是copy 所以本身不能再修改；不管是copy或者mutableCopy
        BYLog(self.stringC);
//        [self.stringC appendString:@"test"];
            
        self.stringD = [self.mutableStringA mutableCopy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringD);
//        [self.stringD appendString:@"test"];

        self.stringE = [self.mutableStringA mutableCopy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringE);
//        [self.stringE appendString:@"test"];
        
    }
    
    
    
    
}
@end

