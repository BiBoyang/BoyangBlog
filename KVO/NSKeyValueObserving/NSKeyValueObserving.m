/** Implementation of GNUSTEP key value observing
   Copyright (C) 2005 Free Software Foundation, Inc.

   Written by Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 2005-2008

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date$ $Revision$
*/

#import "common.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSKeyValueCoding.h"
#import "Foundation/NSKeyValueObserving.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSMethodSignature.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSSet.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/Unicode.h"
#import "GNUstepBase/GSLock.h"
#import "GSInvocation.h"

#if defined(USE_LIBFFI)
#import "cifframe.h"
#endif

/*
 * IMPLEMENTATION NOTES
 *
 * Originally, I wanted to do KVO via a proxy, with class pointer swizzling
 * to turn the original instance into an instance of the proxy class.
 * However, I couldn't figure a way to get decent performance out of
 * this model, as every message to the instance would have to be
 * forwarded through the proxy class methods to the original class
 * methods.
 *
 * So, instead I arrived at the mechanism of creating a subclass of
 * each class being observed, with a few subclass methods overriding
 * those of the original, but most remaining the same.
 * The same class pointer swizzling technique was used to convert between the
 * original class and the superclass.
 * This subclass basically overrides several standard methods with
 * those from a template class, and then overrides any setter methods
 * with a another generic setter.
  
 最初，我想通过一个代理来做KVO，通过类指针的swizzling，把原来的实例变成代理类的实例，但是，我想不出一个办法来让这个模型有更好的性能，因为每个发送到实例的消息都必须通过代理类方法转发到原来的类方法。
 因此，我找到了创建每个类的子类的机制，其中一些子类方法重写了原来的子类方法，但大多数方法保持不变。
 相同的类指针swizzling技术用于在原类和父类之间进行转换。
 这个子类基本上用模板类中的方法重写几个标准方法，然后用另一个泛型setter重写任何setter方法。
 
 */

NSString *const NSKeyValueChangeIndexesKey = @"indexes";
NSString *const NSKeyValueChangeKindKey = @"kind";
NSString *const NSKeyValueChangeNewKey = @"new";
NSString *const NSKeyValueChangeOldKey = @"old";
NSString *const NSKeyValueChangeNotificationIsPriorKey = @"notificationIsPrior";

static NSRecursiveLock    *kvoLock = nil;
static NSMapTable    *classTable = 0;//NSMapTable如果对key 和 value是弱引用，当key 和 value被释放销毁后，NSMapTable中对应的数据也会被清除。
static NSMapTable    *infoTable = 0;
static NSMapTable       *dependentKeyTable;
static Class        baseClass;
static id               null;

#pragma mark----- setup
static inline void
setup() {
    if (nil == kvoLock) {
        //这是一个全局的递归锁NSRecursiveLock
        [gnustep_global_lock lock];
        if (nil == kvoLock) {
            kvoLock = [NSRecursiveLock new];
            /*
             * NSCreateMapTable创建的是一个NSMapTable，一个弱引用key-value容器，
             */
            null = [[NSNull null] retain];
            classTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                          NSNonOwnedPointerMapValueCallBacks, 128);
            infoTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                         NSNonOwnedPointerMapValueCallBacks, 1024);
            dependentKeyTable = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                                 NSOwnedPointerMapValueCallBacks, 128);
            baseClass = NSClassFromString(@"GSKVOBase");
        }
        [gnustep_global_lock unlock];
    }
}
/*
 * This is the template class whose methods are added to KVO classes to
 * override the originals and make the swizzled class look like the
 * original class.
 这是一个模板类，它的方法被添加到KVO类中以覆盖原始类并使swizzle类看起来像原始类。
 */
@interface    GSKVOBase : NSObject
@end

/*
 * This holds information about a subclass replacing a class which is
 * being observed.
  它保存有关子类替换正在观察的类的信息。
 */
@interface    GSKVOReplacement : NSObject
{
    Class         original;       /* The original class 原有类*/
    Class         replacement;    /* The replacement class 替换类*/
    NSMutableSet  *keys;          /* The observed setter keys 被观察者的key*/
}
- (id) initWithClass: (Class)aClass;
- (void) overrideSetterFor: (NSString*)aKey;
- (Class) replacement;
@end

/*
 * This is a placeholder class which has the abstract setter method used
 * to replace all setter methods in the original.
 这是一个占位符类，它使用抽象setter方法替换原始的所有setter方法
 */
@interface    GSKVOSetter : NSObject
- (void) setter: (void*)val;
- (void) setterChar: (unsigned char)val;
- (void) setterDouble: (double)val;
- (void) setterFloat: (float)val;
- (void) setterInt: (unsigned int)val;
- (void) setterLong: (unsigned long)val;
#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val;
#endif
- (void) setterShort: (unsigned short)val;
- (void) setterRange: (NSRange)val;
- (void) setterPoint: (NSPoint)val;
- (void) setterSize: (NSSize)val;
- (void) setterRect: (NSRect)rect;
@end

/* An instance of this records all the information for a single observation.
  一个实例记录了一次观察的所有信息。
 */
@interface    GSKVOObservation : NSObject
{
@public
    NSObject      *observer;      // Not retained (zeroing weak pointer)-- 未保留（将弱指针归零）
    void          *context;
    int           options;
}
@end

/* An instance of thsi records the observations for a key path and the
 * recursion state of the process of sending notifications.
  此实例记录对密钥路径的观察结果以及发送通知过程的递归状态。
 */
@interface    GSKVOPathInfo : NSObject
{
@public
    unsigned              recursion;
    unsigned              allOptions;
    NSMutableArray        *observations;
    NSMutableDictionary   *change;
}
- (void) notifyForKey: (NSString *)aKey ofInstance: (id)instance prior: (BOOL)f;
@end

/*
 * Instances of this class are created to hold information about the
 * observers monitoring a particular object which is being observed.
 * 创建此类的实例是为了保存有关监视正在观察的特定对象的观察者的信息
 */
@interface    GSKVOInfo : NSObject
{
    NSObject            *instance;    // Not retained.
    NSRecursiveLock            *iLock;
    NSMapTable            *paths;
}
- (GSKVOPathInfo *) lockReturningPathInfoForKey: (NSString *)key;
- (void*) contextForObserver: (NSObject*)anObserver ofKeyPath: (NSString*)aPath;
- (id) initWithInstance: (NSObject*)i;
- (NSObject*) instance;
- (BOOL) isUnobserved;
- (void) unlock;

@end

@interface NSKeyValueObservationForwarder : NSObject
{
    id                                    target;
    NSKeyValueObservationForwarder        *child;
    void                                  *contextToForward;
    id                                    observedObjectForUpdate;
    NSString                              *keyForUpdate;
    id                                    observedObjectForForwarding;
    NSString                              *keyForForwarding;
    NSString                              *keyPathToForward;
}

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context;

- (void) keyPathChanged: (id)objectToObserve;
@end

@implementation    GSKVOBase

- (void) dealloc {
    // Turn off KVO for self ... then call the real dealloc implementation.
    // 自行关闭KVO， 然后调用真正的dealloc实现。
    [self setObservationInfo: nil];
    //修改对象所属的类 为新创建的类
    object_setClass(self, [self class]);
    [self dealloc];
    GSNOSUPERDEALLOC;
}
//这个方法实际上改写了class的方法，使得在使用class的时候还是获取的原有的class，而非中间类
- (Class) class {
  return class_getSuperclass(object_getClass(self));
}
//同上，外部调用的时候依然返回原来的类
- (Class) superclass {
    return class_getSuperclass(class_getSuperclass(object_getClass(self)));
}

- (void) setValue: (id)anObject forKey: (NSString*)aKey {
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);

    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

    if ([[self class] automaticallyNotifiesObserversForKey: aKey]) {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
        } else {
            imp(self,_cmd,anObject,aKey);
        }
}

- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey {
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);

    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

    if ([[self class] automaticallyNotifiesObserversForKey: aKey]) {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    } else {
        imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey {
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);

    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

    if ([[self class] automaticallyNotifiesObserversForKey: aKey]) {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    } else {
        imp(self,_cmd,anObject,aKey);
    }
}

- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey {
    Class        c = [self class];
    void        (*imp)(id,SEL,id,id);

    imp = (void (*)(id,SEL,id,id))[c instanceMethodForSelector: _cmd];

    if ([[self class] automaticallyNotifiesObserversForKey: aKey]) {
        [self willChangeValueForKey: aKey];
        imp(self,_cmd,anObject,aKey);
        [self didChangeValueForKey: aKey];
    } else {
        imp(self,_cmd,anObject,aKey);
    }
}

@end

/*
 * Get a key name from a selector (setKey: or _setKey:) by
 * taking the key part and making the first letter lowercase.
 从选择器（setKey:或_setKey:）中获取密钥名，方法是获取密钥部分并使第一个字母小写
 */
static NSString *newKey(SEL _cmd) {
    const char    *name = sel_getName(_cmd);
    unsigned    len;
    NSString    *key;
    unsigned    i;
    if (0 == _cmd || 0 == (name = sel_getName(_cmd))) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Missing selector name"];
    }
    len = strlen(name);
    if (*name == '_') {
        name++;
        len--;
    }
    if (len < 5 || name[len-1] != ':' || strncmp(name, "set", 3) != 0) {
        [NSException raise: NSInvalidArgumentException
                    format: @"Invalid selector name"];
    }
    name += 3;            // Step past 'set'
    len -= 4;            // allow for 'set' and trailing ':'
    for (i = 0; i < len; i++) {
        if (name[i] & 0x80) {
            break;
        }
    }
    if (i == len) {
        char    buf[len];
        /* Efficient key creation for ascii keys
         *  高效的ascii密钥创建
         */
        for (i = 0; i < len; i++) buf[i] = name[i];
        if (isupper(buf[0])) {
            buf[0] = tolower(buf[0]);
        }
        key = [[NSString alloc] initWithBytes: buf
                                       length: len
                                     encoding: NSASCIIStringEncoding];
   } else {
       unichar        u;
       NSMutableString    *m;
       NSString        *tmp;

       /*
        * Key creation for unicode strings.
        * 为unicode字符串创建密钥。
        */
       m = [[NSMutableString alloc] initWithBytes: name
                                           length: len
                                         encoding: NSUTF8StringEncoding];
       u = [m characterAtIndex: 0];
       u = uni_tolower(u);
       tmp = [[NSString alloc] initWithCharacters: &u length: 1];
       [m replaceCharactersInRange: NSMakeRange(0, 1) withString: tmp];
       [tmp release];
       key = m;
   }
    return key;
}


static GSKVOReplacement *replacementForClass(Class c) {
    GSKVOReplacement *r;
    //创建
    setup();
    //递归锁
    [kvoLock lock];
    //从全局classTable中获取GSKVOReplacement实例
    r = (GSKVOReplacement*)NSMapGet(classTable, (void*)c);
    //如果没有信息(不存在)，就创建一个保存到全局classTable中
    if (r == nil) {
        r = [[GSKVOReplacement alloc] initWithClass: c];
        NSMapInsert(classTable, (void*)c, (void*)r);
    }
    //递归锁解锁
    [kvoLock unlock];
    return r;
}

#if defined(USE_LIBFFI)
static void
cifframe_callback(ffi_cif *cif, void *retp, void **args, void *user) {
    id            obj;
    SEL           sel;
    NSString    *key;
    Class        c;
    void        (*imp)(id,SEL,void*);

    obj = *(id *)args[0];
    sel = *(SEL *)args[1];
    c = [obj class];
    
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: sel];
    key = newKey(sel);
    if ([c automaticallyNotifiesObserversForKey: key] == YES) {
        // pre setting code here
        [obj willChangeValueForKey: key];
        ffi_call(cif, (void*)imp, retp, args);
        // post setting code here
        [obj didChangeValueForKey: key];
    } else {
        ffi_call(cif, (void*)imp, retp, args);
    }
    RELEASE(key);
}
#endif

@implementation    GSKVOReplacement
- (void) dealloc {
    DESTROY(keys);
    [super dealloc];
}

- (id) initWithClass: (Class)aClass {
    NSValue        *template;
    NSString        *superName;
    NSString        *name;

    if ([aClass instanceMethodForSelector: @selector(takeValue:forKey:)] != [NSObject instanceMethodForSelector: @selector(takeValue:forKey:)]) {
        NSLog(@"WARNING The class '%@' (or one of its superclasses) overrides"
              @" the deprecated takeValue:forKey: method.  Using KVO to observe"
              @" this class may interfere with this method.  Please change the"
              @" class to override -setValue:forKey: instead.",
              NSStringFromClass(aClass));
        }
    if ([aClass instanceMethodForSelector: @selector(takeValue:forKeyPath:)] != [NSObject instanceMethodForSelector: @selector(takeValue:forKeyPath:)]) {
        NSLog(@"WARNING The class '%@' (or one of its superclasses) overrides"
              @" the deprecated takeValue:forKeyPath: method.  Using KVO to observe"
              @" this class may interfere with this method.  Please change the"
              @" class to override -setValue:forKeyPath: instead.",
              NSStringFromClass(aClass));
    }
    original = aClass;

    /*
     * Create subclass of the original, and override some methods
     * with implementations from our abstract base class.
     *  创建原始类的子类，并使用抽象基类中的实现重写某些方法。
     */
    superName = NSStringFromClass(original);
    name = [@"GSKVO" stringByAppendingString: superName];
    template = GSObjCMakeClass(name, superName, nil);
    GSObjCAddClasses([NSArray arrayWithObject: template]);
    replacement = NSClassFromString(name);
    //这个baseClass是GSKVOBase
    GSObjCAddClassBehavior(replacement, baseClass);
    
    /*
     * Create the set of setter methods overridden.
     * 创建重写的setter方法集。
     */
    keys = [NSMutableSet new];

    return self;
}

- (void) overrideSetterFor: (NSString*)aKey {
    if ([keys member: aKey] == nil) {
        NSMethodSignature    *sig;
        SEL        sel;
        IMP        imp;
        const char    *type;
        NSString          *suffix;
        NSString          *a[2];
        unsigned          i;
        BOOL              found = NO;
        NSString        *tmp;
        unichar u;

        suffix = [aKey substringFromIndex: 1];
        u = uni_toupper([aKey characterAtIndex: 0]);
        tmp = [[NSString alloc] initWithCharacters: &u length: 1];
        a[0] = [NSString stringWithFormat: @"set%@%@:", tmp, suffix];
        a[1] = [NSString stringWithFormat: @"_set%@%@:", tmp, suffix];
        [tmp release];
        for (i = 0; i < 2; i++) {
            /*
             * Replace original setter with our own version which does KVO
             * notifications.
             * 用我们自己的KVO通知版本替换原始setter。
             */
            sel = NSSelectorFromString(a[i]);
            if (sel == 0) {
                continue;
            }
            sig = [original instanceMethodSignatureForSelector: sel];
            if (sig == 0) {
                continue;
            }
            /*
             * A setter must take three arguments (self, _cmd, value).
             * The return value (if any) is ignored.
             * setter必须有三个参数（self，_cmd，value）。
             * 将忽略返回值（如果有）。
             */
            if ([sig numberOfArguments] != 3) {
                continue;    // Not a valid setter method.
            }

            /*
             * Since the compiler passes different argument types
             * differently, we must use a different setter method
             * for each argument type.
             * FIXME ... support structures
             * Unsupported types are quietly ignored ... is that right?
             * 由于编译器传递不同的参数类型不同，我们必须为每个参数类型使用不同的setter方法。
             
             */
            type = [sig getArgumentTypeAtIndex: 2];
            switch (*type) {
                case _C_CHR:
                case _C_UCHR:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterChar:)];
                break;
                case _C_SHT:
                case _C_USHT:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterShort:)];
                break;
                case _C_INT:
                case _C_UINT:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterInt:)];
                break;
                case _C_LNG:
                case _C_ULNG:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterLong:)];
                break;
#ifdef  _C_LNG_LNG
                case _C_LNG_LNG:
                case _C_ULNG_LNG:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterLongLong:)];
                break;
#endif
                case _C_FLT:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterFloat:)];
                break;
                case _C_DBL:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterDouble:)];
                break;
#if __GNUC__ > 2 && defined(_C_BOOL)
                case _C_BOOL:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterChar:)];
                break;
#endif
                case _C_ID:
                case _C_CLASS:
                case _C_PTR:
                    imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setter:)];
                break;
                case _C_STRUCT_B:
                    if (GSSelectorTypesMatch(@encode(NSRange), type)) {
                        imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterRange:)];
                  } else if (GSSelectorTypesMatch(@encode(NSPoint), type)) {
                      imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterPoint:)];
                  } else if (GSSelectorTypesMatch(@encode(NSSize), type)) {
                      imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterSize:)];
                  } else if (GSSelectorTypesMatch(@encode(NSRect), type)) {
                      imp = [[GSKVOSetter class] instanceMethodForSelector: @selector(setterRect:)];
                  } else {
#if defined(USE_LIBFFI)
                      GSCodeBuffer    *b;

                      b = cifframe_closure(sig, cifframe_callback);
                      [b retain];
                      imp = [b executable];
#else
                      imp = 0;
#endif
                  }
                    break;
                default:
                    imp = 0;
                    break;
            }
            if (imp != 0) {
                //添加到对象所属的新类中
                if (class_addMethod(replacement, sel, imp, [sig methodType])) {
                    found = YES;
                } else {
                    NSLog(@"Failed to add setter method for %s to %s",sel_getName(sel), class_getName(original));
                }
            }
        }
        if (found == YES) {
            [keys addObject: aKey];
        } else {
            NSMapTable *depKeys = NSMapGet(dependentKeyTable, original);
            if (depKeys) {
                NSMapEnumerator enumerator = NSEnumerateMapTable(depKeys);
                NSString *mainKey;
                NSHashTable *dependents;

                while (NSNextMapEnumeratorPair(&enumerator, (void **)(&mainKey),(void**)&dependents)) {
                    NSHashEnumerator dependentKeyEnum;
                    NSString *dependentKey;

                    if (!dependents) continue;
                    dependentKeyEnum = NSEnumerateHashTable(dependents);
                    while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum))) {
                        if ([dependentKey isEqual: aKey]) {
                            [self overrideSetterFor: mainKey];
                            // Mark the key as used
                            [keys addObject: aKey];
                            found = YES;
                        }
                    }
                    NSEndHashTableEnumeration(&dependentKeyEnum);
                }
                NSEndMapTableEnumeration(&enumerator);
            }
            if (!found) {
                NSDebugLLog(@"KVC", @"class %@ not KVC compliant for %@",original, aKey);
                /*
                 [NSException raise: NSInvalidArgumentException
                           format: @"class not KVC complient for %@", aKey];
                 */
            }
        }
    }
}

- (Class) replacement {
    return replacement;
}
@end

/*
 * This class
 */
#pragma mark ----- setter方法
@implementation    GSKVOSetter
- (void) setter: (void *)val {
    NSString    *key;
    Class        c = [self class];//GSKVOSetter继承的事NSObject，所以这里获取的还是原有的父类，并未被改写
    void        (*imp)(id,SEL,void*);
    //获取真正的函数地址--原始的setter方法
    imp = (void (*)(id,SEL,void*))[c instanceMethodForSelector: _cmd];

    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES) {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    } else {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterChar: (unsigned char)val {
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned char);

    imp = (void (*)(id,SEL,unsigned char))[c instanceMethodForSelector: _cmd];

    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES) {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    } else {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterDouble: (double)val {
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,double);

    imp = (void (*)(id,SEL,double))[c instanceMethodForSelector: _cmd];

    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES) {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    } else {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterFloat: (float)val {
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,float);

    imp = (void (*)(id,SEL,float))[c instanceMethodForSelector: _cmd];

    key = newKey(_cmd);
    if ([c automaticallyNotifiesObserversForKey: key] == YES) {
        // pre setting code here
        [self willChangeValueForKey: key];
        (*imp)(self, _cmd, val);
        // post setting code here
        [self didChangeValueForKey: key];
    } else {
        (*imp)(self, _cmd, val);
    }
    RELEASE(key);
}

- (void) setterInt: (unsigned int)val {
    NSString    *key;
    Class        c = [self class];
    void        (*imp)(id,SEL,unsigned int);

  imp = (void (*)(id,SEL,unsigned int))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterLong: (unsigned long)val
{
  NSString    *key;
  Class        c = [self class];
  void        (*imp)(id,SEL,unsigned long);

  imp = (void (*)(id,SEL,unsigned long))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

#ifdef  _C_LNG_LNG
- (void) setterLongLong: (unsigned long long)val
{
  NSString    *key;
  Class        c = [self class];
  void        (*imp)(id,SEL,unsigned long long);

  imp = (void (*)(id,SEL,unsigned long long))
    [c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}
#endif

- (void) setterShort: (unsigned short)val
{
  NSString    *key;
  Class        c = [self class];
  void        (*imp)(id,SEL,unsigned short);

  imp = (void (*)(id,SEL,unsigned short))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterRange: (NSRange)val
{
  NSString  *key;
  Class     c = [self class];
  void      (*imp)(id,SEL,NSRange);

  imp = (void (*)(id,SEL,NSRange))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterPoint: (NSPoint)val
{
  NSString  *key;
  Class     c = [self class];
  void      (*imp)(id,SEL,NSPoint);

  imp = (void (*)(id,SEL,NSPoint))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterSize: (NSSize)val
{
  NSString  *key;
  Class     c = [self class];
  void      (*imp)(id,SEL,NSSize);

  imp = (void (*)(id,SEL,NSSize))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    }
  else
    {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}

- (void) setterRect: (NSRect)val {
    NSString  *key;
    Class     c = [self class];
  void      (*imp)(id,SEL,NSRect);

  imp = (void (*)(id,SEL,NSRect))[c instanceMethodForSelector: _cmd];

  key = newKey(_cmd);
  if ([c automaticallyNotifiesObserversForKey: key] == YES)
    {
      // pre setting code here
      [self willChangeValueForKey: key];
      (*imp)(self, _cmd, val);
      // post setting code here
      [self didChangeValueForKey: key];
    } else {
      (*imp)(self, _cmd, val);
    }
  RELEASE(key);
}
@end


@implementation    GSKVOObservation
@end

@implementation    GSKVOPathInfo
- (void) dealloc {
    [change release];
    [observations release];
    [super dealloc];
}

- (id) init {
    change = [NSMutableDictionary new];
    observations = [NSMutableArray new];
    return self;
}

- (void) notifyForKey: (NSString *)aKey
           ofInstance: (id)instance
                prior: (BOOL)f {
    unsigned      count;
    id            oldValue;
    id            newValue;

    if (f == YES) {
        if ((allOptions & NSKeyValueObservingOptionPrior) == 0) {
            return;   // Nothing to do.
        }
        [change setObject: [NSNumber numberWithBool: YES]
                   forKey: NSKeyValueChangeNotificationIsPriorKey];
    } else {
        [change removeObjectForKey: NSKeyValueChangeNotificationIsPriorKey];
    }

    oldValue = [[change objectForKey: NSKeyValueChangeOldKey] retain];
    if (oldValue == nil) {
        oldValue = null;
    }
    newValue = [[change objectForKey: NSKeyValueChangeNewKey] retain];
    if (newValue == nil) {
        newValue = null;
    }
    /* Retain self so that we won't be deallocated during the
     * notification process.
     * 保留self，这样我们就不会在通知过程中被释放。
     */
    [self retain];
    count = [observations count];
    while (count-- > 0) {
        GSKVOObservation  *o = [observations objectAtIndex: count];
        if (f == YES) {
            if ((o->options & NSKeyValueObservingOptionPrior) == 0) {
                continue;
            }
        } else {
            if (o->options & NSKeyValueObservingOptionNew) {
                [change setObject: newValue
                           forKey: NSKeyValueChangeNewKey];
            }
        }

        if (o->options & NSKeyValueObservingOptionOld) {
            [change setObject: oldValue
                       forKey: NSKeyValueChangeOldKey];
        }

        [o->observer observeValueForKeyPath: aKey
                                   ofObject: instance
                                     change: change
                                    context: o->context];
    }
    [change setObject: oldValue forKey: NSKeyValueChangeOldKey];
    [oldValue release];
    [change setObject: newValue forKey: NSKeyValueChangeNewKey];
    [newValue release];
    [self release];
}
@end

@implementation    GSKVOInfo

- (NSObject*) instance
{
  return instance;
}

/* Locks receiver and returns path info on success, otherwise leaves
 * receiver unlocked and returns nil.
 * The returned path info is retained and autoreleased in case something
 * removes it from the receiver while it's being used by the caller.
 * 锁接收器并在成功时返回路径信息，否则保持接收器未锁定并返回零。
 * 返回的路径信息将被保留并自动删除，以防调用方在使用它时有东西将其从接收器中删除。
 */
- (GSKVOPathInfo*) lockReturningPathInfoForKey: (NSString*)key {
    GSKVOPathInfo *pathInfo;

    [iLock lock];
    pathInfo = AUTORELEASE(RETAIN((GSKVOPathInfo*)NSMapGet(paths, (void*)key)));
    if (pathInfo == nil) {
        [iLock unlock];
    }
    return pathInfo;
}

- (void)unlock {
    [iLock unlock];
}

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    GSKVOPathInfo         *pathInfo;
    GSKVOObservation      *observation;
    unsigned              count;

    if ([anObserver respondsToSelector:@selector(observeValueForKeyPath:ofObject:change:context:)] == NO) {
        return;
    }
    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo == nil) {
        pathInfo = [GSKVOPathInfo new];
        // use immutable object for map key
        aPath = [aPath copy];
        NSMapInsert(paths, (void*)aPath, (void*)pathInfo);
        [pathInfo release];
        [aPath release];
    }

    observation = nil;
    pathInfo->allOptions = 0;
    count = [pathInfo->observations count];
    while (count-- > 0) {
        GSKVOObservation      *o;
        o = [pathInfo->observations objectAtIndex: count];
        if (o->observer == anObserver) {
            o->context = aContext;
            o->options = options;
            observation = o;
        }
        pathInfo->allOptions |= o->options;
    }
    if (observation == nil) {
        observation = [GSKVOObservation new];
        GSAssignZeroingWeakPointer((void**)&observation->observer,(void*)anObserver);
        observation->context = aContext;
        observation->options = options;
        [pathInfo->observations addObject: observation];
        [observation release];
        pathInfo->allOptions |= options;
    }
    if (options & NSKeyValueObservingOptionInitial) {
        /* If the NSKeyValueObservingOptionInitial option is set,
         * we must send an immediate notification containing the
         * existing value in the NSKeyValueChangeNewKey
         * 如果设置了NSKeyValueObservingOptionInitial, 我们必须立即发出包含现有value的通知。
         */
        [pathInfo->change setObject: [NSNumber numberWithInt: 1] forKey:  NSKeyValueChangeKindKey];
        if (options & NSKeyValueObservingOptionNew) {
            id    value;
            value = [instance valueForKeyPath: aPath];
            if (value == nil) {
                value = null;
            }
            [pathInfo->change setObject: value
                                 forKey: NSKeyValueChangeNewKey];
        }
        [anObserver observeValueForKeyPath: aPath
                                  ofObject: instance
                                    change: pathInfo->change
                                   context: aContext];
        }
    [iLock unlock];
}

//重写的dealloc
- (void) dealloc {
    if (paths != 0) NSFreeMapTable(paths);
    RELEASE(iLock);
    [super dealloc];
}

- (id) initWithInstance: (NSObject*)i {
    instance = i;
    paths = NSCreateMapTable(NSObjectMapKeyCallBacks,
    NSObjectMapValueCallBacks, 8);
    iLock = [NSRecursiveLock new];
    return self;
}
//是否被观察
- (BOOL) isUnobserved {
    BOOL    result = NO;

    [iLock lock];
    if (NSCountMapTable(paths) == 0) {
        result = YES;
    }
    [iLock unlock];
    return result;
}

/*
 * removes the observer
 * 释放观察者
 */
- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath {
    GSKVOPathInfo    *pathInfo;

    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo != nil) {
        unsigned  count = [pathInfo->observations count];

        pathInfo->allOptions = 0;
        while (count-- > 0) {
            GSKVOObservation      *o;

            o = [pathInfo->observations objectAtIndex: count];
            if (o->observer == anObserver || o->observer == nil) {
                [pathInfo->observations removeObjectAtIndex: count];
                if ([pathInfo->observations count] == 0) {
                    NSMapRemove(paths, (void*)aPath);
                }
            } else {
                pathInfo->allOptions |= o->options;
            }
        }
    }
    [iLock unlock];
}

- (void *) contextForObserver: (NSObject*)anObserver
                    ofKeyPath: (NSString*)aPath {
    GSKVOPathInfo    *pathInfo;
    void          *context = 0;

    [iLock lock];
    pathInfo = (GSKVOPathInfo*)NSMapGet(paths, (void*)aPath);
    if (pathInfo != nil) {
        unsigned  count = [pathInfo->observations count];
        while (count-- > 0) {
            GSKVOObservation      *o;

            o = [pathInfo->observations objectAtIndex: count];
            if (o->observer == anObserver) {
                context = o->context;
                break;
            }
        }
    }
    [iLock unlock];
    return context;
}
@end

@implementation NSKeyValueObservationForwarder

- (id) initWithKeyPath: (NSString *)keyPath
              ofObject: (id)object
            withTarget: (id)aTarget
               context: (void *)context {
    NSString * remainingKeyPath;
    NSRange dot;

    target = aTarget;
    keyPathToForward = [keyPath copy];
    contextToForward = context;

    dot = [keyPath rangeOfString: @"."];
    if (dot.location == NSNotFound) {
        [NSException raise: NSInvalidArgumentException
                    format: @"NSKeyValueObservationForwarder was not given a key path"];
    }
    
    keyForUpdate = [[keyPath substringToIndex: dot.location] copy];
    remainingKeyPath = [keyPath substringFromIndex: dot.location + 1];
    
    observedObjectForUpdate = object;
    [object addObserver: self
             forKeyPath: keyForUpdate
                options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                context: target];
    dot = [remainingKeyPath rangeOfString: @"."];
    if (dot.location != NSNotFound) {
         child = [[NSKeyValueObservationForwarder alloc] initWithKeyPath: remainingKeyPath
                                                                ofObject: [object valueForKey: keyForUpdate]
                                                              withTarget: self
                                                                 context: NULL];
        observedObjectForForwarding = nil;
    } else {
        keyForForwarding = [remainingKeyPath copy];
        observedObjectForForwarding = [object valueForKey: keyForUpdate];
        [observedObjectForForwarding addObserver: self
                                      forKeyPath: keyForForwarding
                                         options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                         context: target];
        child = nil;
    }
    return self;
}

- (void) finalize {
    if (child) {
        [child finalize];
    }
    if (observedObjectForUpdate) {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
    }
    if (observedObjectForForwarding) {
        [observedObjectForForwarding removeObserver: self
                                         forKeyPath:keyForForwarding];
    }
    DESTROY(self);
}

- (void) dealloc {
    [keyForUpdate release];
    [keyForForwarding release];
    [keyPathToForward release];
    
    [super dealloc];
}
#pragma mark ----- 递归访问上一层的对象
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)anObject
                         change: (NSDictionary *)change
                        context: (void *)context {
  if (anObject == observedObjectForUpdate) {
      [self keyPathChanged: nil];
    } else {
      [target observeValueForKeyPath: keyPathToForward
                            ofObject: observedObjectForUpdate
                              change: change
                             context: contextToForward];
    }
}

- (void) keyPathChanged: (id)objectToObserve {
    if (objectToObserve != nil) {
        [observedObjectForUpdate removeObserver: self forKeyPath: keyForUpdate];
        observedObjectForUpdate = objectToObserve;
        [objectToObserve addObserver: self
                          forKeyPath: keyForUpdate
                             options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                             context: target];
    }
    if (child != nil) {
        [child keyPathChanged:[observedObjectForUpdate valueForKey: keyForUpdate]];
    } else {
        NSMutableDictionary *change;
        change = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt: 1]
                                                    forKey:NSKeyValueChangeKindKey];
        if (observedObjectForForwarding != nil) {
            id oldValue;
            oldValue = [observedObjectForForwarding valueForKey: keyForForwarding];
            [observedObjectForForwarding removeObserver: self
                                             forKeyPath:keyForForwarding];
            if (oldValue) {
                [change setObject: oldValue
                           forKey: NSKeyValueChangeOldKey];
            }
        }
        observedObjectForForwarding = [observedObjectForUpdate valueForKey:keyForUpdate];
        if (observedObjectForForwarding != nil) {
            id newValue;
            [observedObjectForForwarding addObserver: self
                                          forKeyPath: keyForForwarding
                                             options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                             context: target];
            //prepare change notification
            newValue = [observedObjectForForwarding valueForKey: keyForForwarding];
            if (newValue) {
                [change setObject: newValue
                           forKey: NSKeyValueChangeNewKey];
            }
        }
        [target observeValueForKeyPath: keyPathToForward
                              ofObject: observedObjectForUpdate
                                change: change
                               context: contextToForward];
        }
}

@end

@implementation NSObject (NSKeyValueObserving)

- (void) observeValueForKeyPath: (NSString*)aPath
                       ofObject: (id)anObject
                         change: (NSDictionary*)aChange
                        context: (void*)aContext {
    [NSException raise: NSInvalidArgumentException
                format: @"-%@ cannot be sent to %@ ..."
                @" create an instance overriding this",
                NSStringFromSelector(_cmd), NSStringFromClass([self class])];
    return;
}

@end

@implementation NSObject (NSKeyValueObserverRegistration)

#pragma mark ----- 注册观察者
- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    GSKVOInfo             *info;
    GSKVOReplacement      *r;
    NSKeyValueObservationForwarder *forwarder;
    NSRange               dot;

    //初始化
    setup();
    //使用递归锁保证线程安全--kvoLock是一个NSRecursiveLock
    [kvoLock lock];

    // Use the original class
    //从全局NSMapTable中获取某个类的KVO子类Class
    r = replacementForClass([self class]);

    /*
     * Get the existing observation information, creating it (and changing
     * the receiver to start key-value-observing by switching its class)
     * if necessary.
     */
    //从全局NSMapTable中获取某个类的观察者信息对象,并通过改变它的类来改变接收器以开始观察关键值
    info = (GSKVOInfo*)[self observationInfo];
    //如果没有信息(不存在)就创建一个观察者信息对象实例。
 
    if (info == nil) {
        info = [[GSKVOInfo alloc] initWithInstance: self];
        //保存到全局NSMapTable中。
        [self setObservationInfo: info];
        //将被观察的对象的isa修改为新的KVO子类Class
        object_setClass(self, [r replacement]);
    }
    /*
     * Now add the observer.
     * 开始处理观察者
     */
    dot = [aPath rangeOfString:@"."];
    //string里有没有.
    if (dot.location != NSNotFound) {
        //有.说明可能是成员变量
        forwarder = [[NSKeyValueObservationForwarder alloc]initWithKeyPath: aPath
                                                                  ofObject: self
                                                                withTarget: anObserver
                                                                   context: aContext];
        [info addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: forwarder];
    } else {
        //根据key 找到对应的setter方法，然后根据类型去获取GSKVOSetter类中相对应数据类型的setter方法
        [r overrideSetterFor: aPath];
        /* 这个是GSKVOInfo里的方法
         * 将keyPath 信息保存到GSKVOInfo中的paths中，方便以后直接从内存中取。
         */
         [info addObserver: anObserver
               forKeyPath: aPath
                  options: options
                  context: aContext];
    }
    //递归锁解锁
    [kvoLock unlock];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath {
    GSKVOInfo    *info;
    id            forwarder;

    /*
     * Get the observation information and remove this observation.
     */
    info = (GSKVOInfo*)[self observationInfo];//获取c观察者信息
    forwarder = [info contextForObserver: anObserver ofKeyPath: aPath];//从全局map里获取观察者的context
    [info removeObserver: anObserver forKeyPath: aPath];//去除info里的观察者信息
    if ([info isUnobserved] == YES) {
        /*
         * The instance is no longer being observed ... so we can
         * turn off key-value-observing for it.
         * 实例不再被观察。。。所以我们可以关闭它的键值观测。
         */
        //修改对象所属的类 为新创建的类
        object_setClass(self, [self class]);
        IF_NO_GC(AUTORELEASE(info);)
        [self setObservationInfo: nil];
    }
    if ([aPath rangeOfString:@"."].location != NSNotFound)
        [forwarder finalize];
}

@end

/**
 * NSArray objects are not observable, so the registration methods
 * raise an exception.
 * NSArray对象是不可见的，因此注册方法会引发异常。
 */
@implementation NSArray (NSKeyValueObserverRegistration)
//处理异常情况
- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) addObserver: (NSObject*)anObserver
  toObjectsAtIndexes: (NSIndexSet*)indexes
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    [self notImplemented: _cmd];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath {
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) removeObserver: (NSObject*)anObserver
   fromObjectsAtIndexes: (NSIndexSet*)indexes
             forKeyPath: (NSString*)aPath {
    [self notImplemented: _cmd];
}

@end

/**
 * NSSet objects are not observable, so the registration methods
 * raise an exception.
 * NSSet对象是不可观察的，因此注册方法也出现异常。
 */
@implementation NSSet (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
          forKeyPath: (NSString*)aPath
             options: (NSKeyValueObservingOptions)options
             context: (void*)aContext {
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

- (void) removeObserver: (NSObject*)anObserver forKeyPath: (NSString*)aPath {
    [NSException raise: NSGenericException
                format: @"[%@-%@]: This class is not observable",
    NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
}

@end

@implementation NSObject (NSKeyValueObserverNotification)

- (void) willChangeValueForDependentsOfKey: (NSString *)aKey {
    NSMapTable *keys = NSMapGet(dependentKeyTable, [self class]);
    if (keys != nil) {
        NSHashTable       *dependents = NSMapGet(keys, aKey);
        if (dependents != 0) {
            NSString              *dependentKey;
            NSHashEnumerator      dependentKeyEnum;

            dependentKeyEnum = NSEnumerateHashTable(dependents);
            while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum))) {
                [self willChangeValueForKey: dependentKey];
            }
            NSEndHashTableEnumeration(&dependentKeyEnum);
        }
    }
}

- (void) didChangeValueForDependentsOfKey: (NSString *)aKey {
    NSMapTable *keys = NSMapGet(dependentKeyTable, [self class]);
    if (keys != nil) {
        NSHashTable *dependents = NSMapGet(keys, aKey);
        if (dependents != nil) {
            NSString              *dependentKey;
            NSHashEnumerator      dependentKeyEnum;

            dependentKeyEnum = NSEnumerateHashTable(dependents);
            while ((dependentKey = NSNextHashEnumeratorItem(&dependentKeyEnum))) {
                [self didChangeValueForKey: dependentKey];
            }
            NSEndHashTableEnumeration(&dependentKeyEnum);
        }
    }
}
#pragma mark ----- 改变value之前
- (void) willChangeValueForKey: (NSString*)aKey {
    GSKVOPathInfo *pathInfo;
    GSKVOInfo     *info;

    info = (GSKVOInfo *)[self observationInfo];
    if (info == nil) {
      return;
    }

    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil) {
        if (pathInfo->recursion++ == 0) {
            id    old = [pathInfo->change objectForKey: NSKeyValueChangeNewKey];
            if (old != nil) {
                /* We have set a value for this key already, so the value
                 * we set must now be the old value and we don't need to
                 * refetch it.
                 */
                [pathInfo->change setObject: old
                                     forKey: NSKeyValueChangeOldKey];
                [pathInfo->change removeObjectForKey: NSKeyValueChangeNewKey];
            } else if (pathInfo->allOptions & NSKeyValueObservingOptionOld) {
                /* We don't have an old value set, so we must fetch the
                 * existing value because at least one observation wants it.
                 */
                old = [self valueForKey: aKey];
                if (old == nil) {
                    old = null;
                }
                [pathInfo->change setObject: old
                                     forKey: NSKeyValueChangeOldKey];
            }
            [pathInfo->change setValue:
            [NSNumber numberWithInt: NSKeyValueChangeSetting]forKey: NSKeyValueChangeKindKey];

            [pathInfo notifyForKey: aKey
                        ofInstance: [info instance]
                             prior: YES];
        }
        [info unlock];
    }
    [self willChangeValueForDependentsOfKey: aKey];
}
#pragma mark -----改变value之后
- (void) didChangeValueForKey: (NSString*)aKey {
    GSKVOPathInfo *pathInfo;
    GSKVOInfo    *info;

    info = (GSKVOInfo *)[self observationInfo];
    if (info == nil) {
      return;
    }

    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil) {
        if (pathInfo->recursion == 1) {
            id    value = [self valueForKey: aKey];
            if (value == nil) {
                value = null;
            }
            [pathInfo->change setValue: value
                                forKey: NSKeyValueChangeNewKey];
            [pathInfo->change setValue:[NSNumber numberWithInt: NSKeyValueChangeSetting]
                                forKey: NSKeyValueChangeKindKey];
            [pathInfo notifyForKey: aKey
                        ofInstance: [info instance]
                             prior: NO];
        }
        if (pathInfo->recursion > 0) {
            pathInfo->recursion--;
        }
        [info unlock];
    }
    [self didChangeValueForDependentsOfKey: aKey];
}

- (void) didChange: (NSKeyValueChange)changeKind
   valuesAtIndexes: (NSIndexSet*)indexes
            forKey: (NSString*)aKey {
    GSKVOPathInfo *pathInfo;
    GSKVOInfo    *info;

    info = [self observationInfo];
    if (info == nil) {
      return;
    }

    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil) {
        if (pathInfo->recursion == 1) {
            NSMutableArray        *array;

            array = [self valueForKey: aKey];
            [pathInfo->change setValue: [NSNumber numberWithInt: changeKind]
                                forKey: NSKeyValueChangeKindKey];
            [pathInfo->change setValue: indexes
                                forKey: NSKeyValueChangeIndexesKey];
            
            if (changeKind == NSKeyValueChangeInsertion || changeKind == NSKeyValueChangeReplacement) {
                [pathInfo->change setValue: [array objectsAtIndexes: indexes]
                                    forKey: NSKeyValueChangeNewKey];
            }
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: NO];
        }
        if (pathInfo->recursion > 0) {
            pathInfo->recursion--;
        }
        [info unlock];
    }
    [self didChangeValueForDependentsOfKey: aKey];
}

- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet*)indexes
             forKey: (NSString*)aKey {
    GSKVOPathInfo *pathInfo;
    GSKVOInfo    *info;

    info = [self observationInfo];
    if (info == nil) {
      return;
    }

    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil) {
        if (pathInfo->recursion++ == 0) {
            NSMutableArray        *array;
            array = [self valueForKey: aKey];
            if (changeKind == NSKeyValueChangeRemoval || changeKind == NSKeyValueChangeReplacement) {
                [pathInfo->change setValue: [array objectsAtIndexes: indexes]
                                    forKey: NSKeyValueChangeOldKey];
            }
            [pathInfo->change setValue: [NSNumber numberWithInt: changeKind]
                                forKey: NSKeyValueChangeKindKey];
            [pathInfo notifyForKey: aKey
                        ofInstance: [info instance]
                             prior: YES];
        }
        [info unlock];
    }
    [self willChangeValueForDependentsOfKey: aKey];
}

- (void) willChangeValueForKey: (NSString*)aKey
               withSetMutation: (NSKeyValueSetMutationKind)mutationKind
                  usingObjects: (NSSet*)objects {
    GSKVOPathInfo *pathInfo;
    GSKVOInfo    *info;

    info = [self observationInfo];
    if (info == nil) {
        return;
    }

    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil) {
        if (pathInfo->recursion++ == 0) {
            id    set = objects;

            if (nil == set) {
                set = [self valueForKey: aKey];
            }
            [pathInfo->change setValue: [set mutableCopy] forKey: @"oldSet"];
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: YES];
        }
        [info unlock];
    }
    [self willChangeValueForDependentsOfKey: aKey];
}

- (void) didChangeValueForKey: (NSString*)aKey
              withSetMutation: (NSKeyValueSetMutationKind)mutationKind
                 usingObjects: (NSSet*)objects {
    GSKVOPathInfo *pathInfo;
    GSKVOInfo    *info;

    info = [self observationInfo];
    if (info == nil) {
      return;
    }

    pathInfo = [info lockReturningPathInfoForKey: aKey];
    if (pathInfo != nil) {
        if (pathInfo->recursion == 1) {
            NSMutableSet  *oldSet;
            id            set = objects;

            oldSet = [pathInfo->change valueForKey: @"oldSet"];
            if (nil == set) {
                set = [self valueForKey: aKey];
            }
            [pathInfo->change removeObjectForKey: @"oldSet"];

            if (mutationKind == NSKeyValueUnionSetMutation) {
                set = [set mutableCopy];
                [set minusSet: oldSet];
                [pathInfo->change setValue:[NSNumber numberWithInt: NSKeyValueChangeInsertion]
                                    forKey: NSKeyValueChangeKindKey];
                [pathInfo->change setValue: set
                                    forKey: NSKeyValueChangeNewKey];
            } else if (mutationKind == NSKeyValueMinusSetMutation || mutationKind == NSKeyValueIntersectSetMutation) {
                [oldSet minusSet: set];
                [pathInfo->change setValue:[NSNumber numberWithInt: NSKeyValueChangeRemoval]
                                    forKey: NSKeyValueChangeKindKey];
                [pathInfo->change setValue: oldSet
                                    forKey: NSKeyValueChangeOldKey];
            } else if (mutationKind == NSKeyValueSetSetMutation)  {
                NSMutableSet      *old;
                NSMutableSet      *new;

                old = [oldSet mutableCopy];
                [old minusSet: set];
                new = [set mutableCopy];
                [new minusSet: oldSet];
                [pathInfo->change setValue:[NSNumber numberWithInt: NSKeyValueChangeReplacement]
                                    forKey: NSKeyValueChangeKindKey];
                [pathInfo->change setValue: old
                                    forKey: NSKeyValueChangeOldKey];
                [pathInfo->change setValue: new
                                    forKey: NSKeyValueChangeNewKey];
            }
            [pathInfo notifyForKey: aKey ofInstance: [info instance] prior: NO];
        }
        if (pathInfo->recursion > 0){
            pathInfo->recursion--;
        }
        [info unlock];
    }
    [self didChangeValueForDependentsOfKey: aKey];
}

@end

@implementation NSObject (NSKeyValueObservingCustomization)

+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)aKey {
  return YES;
}

+ (void) setKeys: (NSArray*)triggerKeys triggerChangeNotificationsForDependentKey: (NSString*)dependentKey {
  NSMapTable    *affectingKeys;
  NSEnumerator  *enumerator;
  NSString      *affectingKey;

  setup();
  affectingKeys = NSMapGet(dependentKeyTable, self);
  if (!affectingKeys)
    {
      affectingKeys = NSCreateMapTable(NSObjectMapKeyCallBacks,
        NSNonOwnedPointerMapValueCallBacks, 10);
      NSMapInsert(dependentKeyTable, self, affectingKeys);
    }
  enumerator = [triggerKeys objectEnumerator];
  while ((affectingKey = [enumerator nextObject]))
    {
      NSHashTable *dependentKeys = NSMapGet(affectingKeys, affectingKey);

      if (!dependentKeys)
        {
          dependentKeys = NSCreateHashTable(NSObjectHashCallBacks, 10);
          NSMapInsert(affectingKeys, affectingKey, dependentKeys);
        }
      NSHashInsert(dependentKeys, dependentKey);
    }
}

+ (NSSet*) keyPathsForValuesAffectingValueForKey: (NSString*)dependentKey
{
  NSString *selString = [NSString stringWithFormat: @"keyPathsForValuesAffecting%@",
                                  [dependentKey capitalizedString]];
  SEL sel = NSSelectorFromString(selString);
  NSMapTable *affectingKeys;
  NSEnumerator *enumerator;
  NSString *affectingKey;
  NSMutableSet *keyPaths;

  if ([self respondsToSelector: sel])
    {
      return [self performSelector: sel];
    }

  affectingKeys = NSMapGet(dependentKeyTable, self);
  keyPaths = [[NSMutableSet alloc] initWithCapacity: [affectingKeys count]];
  enumerator = [affectingKeys keyEnumerator];
  while ((affectingKey = [enumerator nextObject]))
    {
      [keyPaths addObject: affectingKey];
    }

  return AUTORELEASE(keyPaths);
}

//获取观察者信息
- (void*) observationInfo {
    void    *info;

    setup();
    [kvoLock lock];
    info = NSMapGet(infoTable, (void*)self);
    IF_NO_GC(AUTORELEASE(RETAIN((id)info));)
    [kvoLock unlock];
    return info;
}
//插入观察者信息
- (void) setObservationInfo: (void*)observationInfo {
    setup();
    [kvoLock lock];
    if (observationInfo == 0) {
        NSMapRemove(infoTable, (void*)self);
    } else {
        NSMapInsert(infoTable, (void*)self, observationInfo);
    }
    [kvoLock unlock];
}

@end


