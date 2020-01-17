# iOS中isEqual和Hash的笔记（一）
## hashABC
hash是一种用于处理查找时非常高效的数据结构。时间复杂度一般情况下可以直接认为是O(1)。
散列技术是在记录的存储位置和它的关键字之间确立一个对应关系 *f*，使得关键字 `key`对应的存储位置 `f(key)`。函数 `f`被称之为哈希函数(hash function)，使用哈希技术将数据存储在一块连续的地址区域中，该连续的存储空间我们称之为散列表，也就是哈希表（hash table）。
我们在存储的时候，是用过哈希函数计算得到哈希地址，并按照哈希地址存储该记录；查找的时候，通过通过同样的哈希函数计算记录的哈希地址，并按照地址访问该记录。
如果两个值在一个地址，就是 **冲突（collision）**。
解决冲突的方法主要是下边几种

> * 开放定址法
> * 再散列函数法
> * 链地址法（拉链法）
> * 公共溢出区法

假如在理想的状态下完全没有冲突，哈希表是所有查找中性能最高的，但是在极端情况下（全是一个地址），就是一个链表（链地址法）了。
测量性能我们主要是以下边几个标准：

> * 散列表是否均匀
> * 处理冲突的方式
> * 散列表的负载因子
 负载因子 = 表中记录个数 / 散列表的长度
 
 优点：在理想的状态下，查找、插入、删除操作的效率是最高的，是O(1)，树的相同操作也是需要O(n)的时间级的。
 缺点：要时刻注意散列表的负载因子，准备扩容；要在面对真实的场景的时候，采用正确的冲突处理方法。
 
## 对象等同性
哈希表在iOS中使用时相当多的，比如说weak的地址就是由一个哈希表实现的，NSDictionary和NSSet的底层实现也是哈希表，NSObject也有hash值（但是要特别注意，这几种的hash实现并不相同）。与其说巧合，不如说这表明了在移动开发中的一种思想：

> 响应时间是比内存空间相对更重要的东西。

  移动端的App是面向用户的，用户体验最直观的体现就是时间！响应时间、动画流畅度、屏幕帧数等等，都是这一思想的体现，而在很多优秀的第三方，也都使用了这一思路。当然，这一思想的主要也会造成很多问题，比如说内存暴涨以及OOM问题，这就是另外的问题了。
  
  
  话回正题。
  “==”代表的是两个对象的指针的直接对比两个对象的指针，也就是内存地址；而“isEqual”是对比对象的值。以下边代码为例：
  ```C++
    NSString *stringA = @"BiBoyang";
    NSMutableString *stringB = [stringA mutableCopy];
    
    BOOL equalA = (stringA == stringB);//0
    BOOL equalB = [stringA isEqual:stringB];//1
    BOOL equalC = [stringA isEqualToString:stringB];//1
  ```
可以发现，在比较对象的指针的时候，是不相同的；但是在直接对比对象的值的时候，是相等的。

在 `NSObject.h`中，我们可以看到这种两个重要的方法。
```C++
- (BOOL)isEqual:(id)object;
@property (readonly) NSUInteger hash;
```
这里需要注意的是，如果isEqual判断两个对象相等，则两个对象的hash值相同；反之则不然。这里是在其他语言，比如Java中也是一样的，不过在NSString中存在特殊情况，在下边我会讲到。

## 如何自我实现isEqual
```C++
@interface Person : NSObject
@property (nonatomic, copy) NSString *firstName;
@property (nonatomic, copy) NSDate *lastName;
@end

......

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:[Person class]]) {
        return NO;
    }

    return [self isEqualToPerson:(Person *)object];
}

- (BOOL)isEqualToPerson:(Person *)person {
    if (!person) {
        return NO;
    }

    BOOL haveEqualFirstName = (!self.firstName && !person.firstName) || [self.firstName isEqualToString:person.firstName];
    BOOL haveEqualLastName = (!self.lastName && !person.lastName) || [self.lastName isEqualToDate:person.lastName];

    return haveEqualFirstName && haveEqualLastName;
}

```
可以逐步判断，先进行指针的判断：如果两个指针相等，那么就是指向一个对象，所以必定相等。然后在进行各个数据的判断。

然后要说到hash方法。
第一种方法：
```C++
-(NSUInteger)hash{
    return 1337;
}
```
这种方法我们很容易产生性能问题。我们如果使用链地址法的话，是先找到对应的箱子，再去箱子里遍历链表（这里的实现应该是数组）。

第二种方法：
```C++
-  (NSUIntger)hash {
  NSUIntger stringToHash = [NSString stringWithFormat:"%@:%@",_firstName,_lastName];
  return [stringToHash hash];
}
```
这种方法是将对象的各种属性塞入另一个字符串中，然后返回该对象的hash，很明显，这里需要再创建一次字符串，性能上还是有问题。

第三种方法：
```C++
-  (NSUIntger)hash {
  NSUIntger firstNameHash = [_firstName hash];
  NSUIntger lastNameHash = [_lastName hash];
  NSUIntger ageHash = _age;
  return firstNameHash ^ lastNameHash ^ ageHash;
}
```
这种方法既能保持较高效率，又能使生成的哈希码至少位于一定范围内，而不会过于频繁的重复。

现实中，一般是第二种和第三种都有（事实上，这两种方法各有优劣，要根据实际情况选择）。

## 为什么单独的hash无法保证对象相等

这个其实是一个很有趣的问题，和语言有很大的关系。在iOS中，因为可变字典和集合的关系，hash实际上是需要动态扩容的。iOS的动态扩容方法是一个很艰深的问题了,这里不讨论。      
我们知道一个事实就可以了，hash如果负载因子过多，实际上是很容易发生冲突的。冲突的处理就会造成新的操作，这也是hash函数往往效率不理想的原因。
这也可以说明，在Objective-C中，如果有两个字典，分别存储100条数据和10000条数据，虽然理论上时间是相等的，但是实际上，大的那个会更慢一些，或者严谨点说，慢的概率会大一点。
[深入理解哈希表](https://github.com/bestswifter/blog/blob/master/articles/hashtable.md)
不过，我下边说的是一种NSString的hash很有趣的东西。
我们打开[	CF-1153.18.tar.gz](https://opensource.apple.com/tarballs/CF/CF-1153.18.tar.gz)。
在`CFString.h`中，有一段很有意思的话
```C++
/* String hashing: Should give the same results whatever the encoding; so we hash UniChars.
If the length is less than or equal to 96, then the hash function is simply the 
following (n is the nth UniChar character, starting from 0):
   
  hash(-1) = length
  hash(n) = hash(n-1) * 257 + unichar(n);
  Hash = hash(length-1) * ((length & 31) + 1)

If the length is greater than 96, then the above algorithm applies to 
characters 0..31, (length/2)-16..(length/2)+15, and length-32..length-1, inclusive;
thus the first, middle, and last 32 characters.

Note that the loops below are unrolled; and: 257^2 = 66049; 257^3 = 16974593; 257^4 = 4362470401;  67503105 is 257^4 - 256^4
If hashcode is changed from UInt32 to something else, this last piece needs to be readjusted.  
!!! We haven't updated for LP64 yet

NOTE: The hash algorithm used to be duplicated in CF and Foundation; but now it should only be in the four functions below.

Hash function was changed between Panther and Tiger, and Tiger and Leopard.
*/
```
这句话的大意是：这个字符串的大小如果小于等于96，则保证hash的安全；如果大小大于96了，则无法保证安全，它只会对前32，中32，后32进行hash。
也就是这个宏的由来 
```C++
#define HashEverythingLimit 96
```
也就是说会大大增加冲突的概率。
在源码中我们可以查看到
```C++
CFHashCode __CFStringHash(CFTypeRef cf) {
    /* !!! We do not need an IsString assertion here, as this is called by the CFBase runtime only */
    CFStringRef str = (CFStringRef)cf;
    const uint8_t *contents = (uint8_t *)__CFStrContents(str);
    CFIndex len = __CFStrLength2(str, contents);

    if (__CFStrIsEightBit(str)) {
        contents += __CFStrSkipAnyLengthByte(str);
        return __CFStrHashEightBit(contents, len);
    } else {
        return __CFStrHashCharacters((const UniChar *)contents, len, len);
    }
}

```
两个具体方法的实现如下
```C++
#define HashNextFourUniChars(accessStart, accessEnd, pointer) \
    {result = result * 67503105 + (accessStart 0 accessEnd) * 16974593  + (accessStart 1 accessEnd) * 66049  + (accessStart 2 accessEnd) * 257 + (accessStart 3 accessEnd); pointer += 4;}

#define HashNextUniChar(accessStart, accessEnd, pointer) \
    {result = result * 257 + (accessStart 0 accessEnd); pointer++;}


/* In this function, actualLen is the length of the original string; but len is the number of characters in buffer. The buffer is expected to contain the parts of the string relevant to hashing.
*/
CF_INLINE CFHashCode __CFStrHashCharacters(const UniChar *uContents, CFIndex len, CFIndex actualLen) {
    CFHashCode result = actualLen;
    if (len <= HashEverythingLimit) {
        const UniChar *end4 = uContents + (len & ~3);
        const UniChar *end = uContents + len;
        while (uContents < end4) HashNextFourUniChars(uContents[, ], uContents); 	// First count in fours
        while (uContents < end) HashNextUniChar(uContents[, ], uContents);		// Then for the last <4 chars, count in ones...
    } else {
        const UniChar *contents, *end;
	contents = uContents;
        end = contents + 32;
        while (contents < end) HashNextFourUniChars(contents[, ], contents);
	contents = uContents + (len >> 1) - 16;
        end = contents + 32;
        while (contents < end) HashNextFourUniChars(contents[, ], contents);
	end = uContents + len;
        contents = end - 32;
        while (contents < end) HashNextFourUniChars(contents[, ], contents);
    }
    return result + (result << (actualLen & 31));
}

/* This hashes cString in the eight bit string encoding. It also includes the little debug-time sanity check.
*/
CF_INLINE CFHashCode __CFStrHashEightBit(const uint8_t *cContents, CFIndex len) {
#if defined(DEBUG)
    if (!__CFCharToUniCharFunc) {	// A little sanity verification: If this is not set, trying to hash high byte chars would be a bad idea
        CFIndex cnt;
        Boolean err = false;
        if (len <= HashEverythingLimit) {
            for (cnt = 0; cnt < len; cnt++) if (cContents[cnt] >= 128) err = true;
        } else {
            for (cnt = 0; cnt < 32; cnt++) if (cContents[cnt] >= 128) err = true;
            for (cnt = (len >> 1) - 16; cnt < (len >> 1) + 16; cnt++) if (cContents[cnt] >= 128) err = true;
            for (cnt = (len - 32); cnt < len; cnt++) if (cContents[cnt] >= 128) err = true;
        }
        if (err) {
            // Can't do log here, as it might be too early
            fprintf(stderr, "Warning: CFHash() attempting to hash CFString containing high bytes before properly initialized to do so\n");
        }
    }
#endif
    CFHashCode result = len;
    if (len <= HashEverythingLimit) {
        const uint8_t *end4 = cContents + (len & ~3);
        const uint8_t *end = cContents + len;
        while (cContents < end4) HashNextFourUniChars(__CFCharToUniCharTable[cContents[, ]], cContents); 	// First count in fours
        while (cContents < end) HashNextUniChar(__CFCharToUniCharTable[cContents[, ]], cContents);		// Then for the last <4 chars, count in ones...
    } else {
	const uint8_t *contents, *end;
	contents = cContents;
        end = contents + 32;
        while (contents < end) HashNextFourUniChars(__CFCharToUniCharTable[contents[, ]], contents);
	contents = cContents + (len >> 1) - 16;
        end = contents + 32;
        while (contents < end) HashNextFourUniChars(__CFCharToUniCharTable[contents[, ]], contents);
	end = cContents + len;
        contents = end - 32;
        while (contents < end) HashNextFourUniChars(__CFCharToUniCharTable[contents[, ]], contents);
    }
    return result + (result << (len & 31));
}

```
我又写了一个代码做了实验，实现代码如下：
```C++
//注意，bbb的第33位进行了修改
NSString *strA = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccccddddddddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
NSString *strB = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaabbabbbbbbbbbbbbbbbbbbbbbbbbbbbccccccccccccccccccccccccccccccddddddddddddddddddddddddddddddeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
    
BOOL equalA = (strA == strB);//False
BOOL equalB = [strA isEqual:strB];//False
BOOL equalC = ([strA hash] == [strB hash]);//True
```
是不是很神奇？strA的hash值居然和strB的哈希值是不同的！
由此可见，NSString的hash值，确实有点靠不住。

## 下一步计划
Objective-C的hash实现实际上全部写在 *CFBasicHash*中，找个机会一定要看一下。
