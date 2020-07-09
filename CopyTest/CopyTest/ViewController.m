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



@property (nonatomic, strong) NSMutableArray *mutableArrayA;
@property (nonatomic, copy) NSArray *arrayA;

@property (nonatomic, strong) NSMutableArray *arrayB;
@property (nonatomic, copy) NSMutableArray *arrayC;
@property (nonatomic, strong) NSArray *arrayD;
@property (nonatomic, copy) NSArray *arrayE;



@property (nonatomic, strong) NSMutableDictionary *mutableDictionaryA;
@property (nonatomic, copy) NSDictionary *dictionaryA;

@property (nonatomic, strong) NSMutableDictionary *dictionaryB;
@property (nonatomic, copy) NSMutableDictionary *dictionaryC;
@property (nonatomic, strong) NSDictionary *dictionaryD;
@property (nonatomic, copy) NSDictionary *dictionaryE;


@end

@implementation ViewController

#define BYLog(_var) ({ NSString *name = @#_var; NSLog(@"%@: %@ -> %p : %@", name, [_var class], _var, _var); })


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    int a = 1 ;
    
    /*
    NSLog(@"不可变对象----------------------");

    self.stringA = [NSString stringWithFormat:@"Bo"];
    
    BYLog(self.stringA);
    
    if(a == 0) {

    NSLog(@"使用 copy ----------------------");
    self.stringB = [self.stringA copy];//使用copy的话是不可以修改的
    BYLog(self.stringB);

    self.stringC = [self.stringA copy];//属性关键字是copy 所以本身不能再修改；不管是copy或者mutableCopy
    BYLog(self.stringC);

    self.stringD = [self.stringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
    BYLog(self.stringD);

    self.stringE = [self.stringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
    BYLog(self.stringE);

    } else {

        NSLog(@"使用 mutableCopy ----------------------");
        self.stringB = [self.stringA mutableCopy];
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

    self.mutableStringA = [NSMutableString stringWithFormat:@"Bo"];
    BYLog(self.mutableStringA);
    
    if(a == 0) {
        NSLog(@"使用 copy ----------------------");
        
        self.stringB = [self.mutableStringA copy];//使用copy的话是不可以修改的
        BYLog(self.stringB);

        self.stringC = [self.mutableStringA copy];//属性关键字是copy 所以本身不能再修改；不管是copy或者mutableCopy
        BYLog(self.stringC);
            
        self.stringD = [self.mutableStringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringD);

        self.stringE = [self.mutableStringA copy];//直接警告 No visible @interface for 'NSString' declares the selector 'appendString:'
        BYLog(self.stringE);
        
    } else {
        NSLog(@"使用 mutableCopy ----------------------");
        
        self.stringB = [self.mutableStringA mutableCopy];//使用mutableCopy的话是可以修改的
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
    
    
    self.arrayA = @[@"value1",@"value2",@"value3"];
    
    BYLog(self.arrayA);
    NSLog(@"%p-%p-%p", self.arrayA[0], self.arrayA[1], self.arrayA[2]);
    NSLog(@"不可变对象----------------------");

    if(a == 0) {
        NSLog(@"使用 copy ----------------------");
        self.arrayB = [self.arrayA copy];
        BYLog(self.arrayB);
        NSLog(@"%p-%p-%p", self.arrayB[0], self.arrayB[1], self.arrayB[2]);
        
        self.arrayC = [self.arrayA copy];
        BYLog(self.arrayC);
        NSLog(@"%p-%p-%p", self.arrayC[0], self.arrayC[1], self.arrayC[2]);
        
        self.arrayD = [self.arrayA copy];
        BYLog(self.arrayD);
        NSLog(@"%p-%p-%p", self.arrayD[0], self.arrayD[1], self.arrayD[2]);
        
        self.arrayE = [self.arrayA copy];
        BYLog(self.arrayE);
        NSLog(@"%p-%p-%p", self.arrayE[0], self.arrayE[1], self.arrayE[2]);
        
    } else {
        NSLog(@"使用 mutableCopy ----------------------");
        self.arrayB = [self.arrayA mutableCopy];
        BYLog(self.arrayB);
        NSLog(@"%p-%p-%p", self.arrayB[0], self.arrayB[1], self.arrayB[2]);
        
        self.arrayC = [self.arrayA mutableCopy];
        BYLog(self.arrayC);
        NSLog(@"%p-%p-%p", self.arrayC[0], self.arrayC[1], self.arrayC[2]);
        
        self.arrayD = [self.arrayA mutableCopy];
        BYLog(self.arrayD);
        NSLog(@"%p-%p-%p", self.arrayD[0], self.arrayD[1], self.arrayD[2]);
        
        self.arrayE = [self.arrayA mutableCopy];
        BYLog(self.arrayE);
        NSLog(@"%p-%p-%p", self.arrayE[0], self.arrayE[1], self.arrayE[2]);
        
        
    }
    
    
    self.mutableArrayA = [[NSMutableArray alloc]init];
    NSMutableString *mstr3 = [[NSMutableString alloc]initWithString:@"value3"];
    NSMutableString *mstr4 = [[NSMutableString alloc]initWithString:@"value4"];
    NSMutableString *mstr5 = [[NSMutableString alloc]initWithString:@"value5"];
    
    [self.mutableArrayA addObject:mstr3];
    [self.mutableArrayA addObject:mstr4];
    [self.mutableArrayA addObject:mstr5];
    
    BYLog(self.mutableArrayA);
    NSLog(@"%p-%p-%p", self.mutableArrayA[0], self.mutableArrayA[1], self.mutableArrayA[2]);

    NSLog(@"可变对象----------------------");
    if(a == 0) {
        NSLog(@"使用 copy ----------------------");
        self.arrayB = [self.mutableArrayA copy];
        BYLog(self.arrayB);
        NSLog(@"%p-%p-%p", self.arrayB[0], self.arrayB[1], self.arrayB[2]);
        
        self.arrayC = [self.mutableArrayA copy];
        BYLog(self.arrayC);
        NSLog(@"%p-%p-%p", self.arrayC[0], self.arrayC[1], self.arrayC[2]);
        
        self.arrayD = [self.mutableArrayA copy];
        BYLog(self.arrayD);
        NSLog(@"%p-%p-%p", self.arrayD[0], self.arrayD[1], self.arrayD[2]);
        
        self.arrayE = [self.mutableArrayA copy];
        BYLog(self.arrayE);
        NSLog(@"%p-%p-%p", self.arrayE[0], self.arrayE[1], self.arrayE[2]);
        
        
        
    } else {
        NSLog(@"使用 mutableCopy ----------------------");
        self.arrayB = [self.mutableArrayA mutableCopy];
        BYLog(self.arrayB);
        NSLog(@"%p-%p-%p", self.arrayB[0], self.arrayB[1], self.arrayB[2]);
        
        
        self.arrayC = [self.mutableArrayA mutableCopy];
        BYLog(self.arrayC);
        NSLog(@"%p-%p-%p", self.arrayC[0], self.arrayC[1], self.arrayC[2]);
        
        self.arrayD = [self.mutableArrayA mutableCopy];
        BYLog(self.arrayD);
        NSLog(@"%p-%p-%p", self.arrayD[0], self.arrayD[1], self.arrayD[2]);
        
        self.arrayE = [self.mutableArrayA mutableCopy];
        BYLog(self.arrayE);
        NSLog(@"%p-%p-%p", self.arrayE[0], self.arrayE[1], self.arrayE[2]);
        
    }
    */
    
    self.dictionaryA = @{@"A":@"aa",@"B":@"bb"};
        
    BYLog(self.dictionaryA);
    NSLog(@"%p-%p", self.dictionaryA[@"A"], self.dictionaryA[@"B"]);
    NSLog(@"不可变字典----------------------");

    if(a == 0) {
        
        NSLog(@"使用 copy ----------------------");
        self.dictionaryB = [self.dictionaryA copy];
        BYLog(self.dictionaryB);
        NSLog(@"%p-%p", self.dictionaryB[@"A"], self.dictionaryB[@"B"]);
        
        self.dictionaryC = [self.dictionaryA copy];
        BYLog(self.dictionaryC);
        NSLog(@"%p-%p", self.dictionaryC[@"A"], self.dictionaryC[@"B"]);
       
        self.dictionaryD = [self.dictionaryA copy];
        BYLog(self.dictionaryD);
        NSLog(@"%p-%p", self.dictionaryD[@"A"], self.dictionaryD[@"B"]);
        
        self.dictionaryE = [self.dictionaryA copy];
        BYLog(self.dictionaryE);
        NSLog(@"%p-%p", self.dictionaryE[@"A"], self.dictionaryE[@"B"]);
    
    } else {
        
        NSLog(@"使用 mutableCopy ----------------------");

        self.dictionaryB = [self.dictionaryA mutableCopy];
        BYLog(self.dictionaryB);
        NSLog(@"%p-%p", self.dictionaryB[@"A"], self.dictionaryB[@"B"]);
         
        self.dictionaryC = [self.dictionaryA mutableCopy];
        BYLog(self.dictionaryC);
        NSLog(@"%p-%p", self.dictionaryC[@"A"], self.dictionaryC[@"B"]);
        
        self.dictionaryD = [self.dictionaryA mutableCopy];
        BYLog(self.dictionaryD);
        NSLog(@"%p-%p", self.dictionaryD[@"A"], self.dictionaryD[@"B"]);
         
        self.dictionaryE = [self.dictionaryA mutableCopy];
        BYLog(self.dictionaryE);
        NSLog(@"%p-%p", self.dictionaryE[@"A"], self.dictionaryE[@"B"]);
        
        
    }
    
    
    
    
}
@end

