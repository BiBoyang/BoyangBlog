//
//  Fish.m
//  KVO_demo
//
//  Created by 毕博洋 on 2019/12/11.
//  Copyright © 2019 毕博洋. All rights reserved.
//

#import "Fish.h"

@import ObjectiveC.objc;
@import ObjectiveC.runtime;

@implementation Fish

- (NSString *)description {
    NSLog(@"object address : %p \n", self);
    
    IMP colorIMP = class_getMethodImplementation(object_getClass(self), @selector(setColor:));
    IMP priceIMP = class_getMethodImplementation(object_getClass(self), @selector(setPrice:));
    NSLog(@"object setName: IMP %p object setAge: IMP %p \n", colorIMP, priceIMP);
    
    Class objectMethodClass = [self class];
    Class objectRuntimeClass = object_getClass(self);
    Class superClass = class_getSuperclass(objectRuntimeClass);
    NSLog(@"objectMethodClass : %@, ObjectRuntimeClass : %@, superClass : %@ \n", objectMethodClass, objectRuntimeClass, superClass);
    
    NSLog(@"object method list \n");
    unsigned int count;
    Method *methodList = class_copyMethodList(objectRuntimeClass, &count);
    for (NSInteger i = 0; i < count; i++) {
        Method method = methodList[i];
        NSString *methodName = NSStringFromSelector(method_getName(method));
        NSLog(@"method Name = %@\n", methodName);
    }
    
    return @"";
}

@end
