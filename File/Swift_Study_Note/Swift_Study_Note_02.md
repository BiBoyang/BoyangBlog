# Swift学习笔记(二)：运算符

* 与 C 语言和 Objective-C 不同，Swift 的赋值操作并不返回任何值。所以下面语句是无效的：
```swift
        if x = y {
            // 此句错误，因为 x = y 并不返回任何值
        }
```

# 加法可以用于字符串
```C++
var stringA : String = "Hello"
var stringB : String = stringA + "world"

print(">>\(stringB)")
        
```

# 求余运算符
求余运算符（a % b）是计算 b 的多少倍刚刚好可以容入 a，返回多出来的那部分（余数）。

求余运算符（%）在其他语言也叫取模运算符。但是严格说来，我们看该运算符对负数的操作结果，「求余」比「取模」更合适些。

# 三元运算符

三元运算符是以下代码的缩写形式：
```C+=
if question {
    answer1
} else {
    answer2
}
```

用swift来写就这样
```C++
let contentHeight = 40
let hasHeader = true
let rowHeight = contentHeight + (hasHeader ? 50 : 20)
// rowHeight 现在是 90
```

# 区间运算符
闭区间运算符（a...b）定义一个包含从 a 到 b（包括 a 和 b）的所有值的区间。a 的值不能超过 b。

```C++
for index in 1...5 {
    print("\(index) * 5 = \(index * 5)")
}
// 1 * 5 = 5
// 2 * 5 = 10
// 3 * 5 = 15
// 4 * 5 = 20
// 5 * 5 = 25
```

### 半开区间运算符
半开区间运算符（a..<b）定义一个从 a 到 b 但不包括 b 的区间。 之所以称为半开区间，是因为该区间包含第一个值而不包括最后的值。
```swift
let names = ["Anna", "Alex", "Brian", "Jack"]
let count = names.count
for i in 0..<count {
    print("第 \(i + 1) 个人叫 \(names[i])")
}
// 第 1 个人叫 Anna
// 第 2 个人叫 Alex
// 第 3 个人叫 Brian
// 第 4 个人叫 Jack
```

### 单侧区间

闭区间操作符有另一个表达形式，可以表达往一侧无限延伸的区间 —— 例如，一个包含了数组从索引 2 到结尾的所有值的区间。在这些情况下，你可以省略掉区间操作符一侧的值。这种区间叫做单侧区间，因为操作符只有一侧有值。例如：
```C++
for name in names[2...] {
    print(name)
}
// Brian
// Jack

for name in names[...2] {
    print(name)
}
// Anna
// Alex
// Brian
```


# 逻辑运算符
* 逻辑非（!a）
* 逻辑与（a && b）
* 逻辑或（a || b）

逻辑非运算符（!a）对一个布尔值取反，使得 true 变 false，false 变 true。

逻辑与运算符（a && b）表达了只有 a 和 b 的值都为 true 时，整个表达式的值才会是 true。

逻辑或运算符（a || b）是一个由两个连续的 | 组成的中置运算符。它表示了两个逻辑表达式的其中一个为 true，整个表达式就为 true。


# 位运算符

**按位取反运算符**（~）对一个数值的全部比特位进行取反：

```C++
let initialBits: UInt8 = 0b00001111
let invertedBits = ~initialBits // 等于 0b11110000
```

**按位与运算符**（&） 对两个数的比特位进行合并。它返回一个新的数，只有当两个数的对应位都为 1 的时候，新数的对应位才为 1：

```C++
let firstSixBits: UInt8 = 0b11111100
let lastSixBits: UInt8  = 0b00111111
let middleFourBits = firstSixBits & lastSixBits // 等于 00111100
```

**按位或运算符**（|）可以对两个数的比特位进行比较。它返回一个新的数，只要两个数的对应位中有任意一个为 1 时，新数的对应位就为 1：

```C++
let someBits: UInt8 = 0b10110010
let moreBits: UInt8 = 0b01011110
let combinedbits = someBits | moreBits // 等于 11111110
```

**按位异或运算符**，或称“排外的或运算符”（^），可以对两个数的比特位进行比较。它返回一个新的数，当两个数的对应位不相同时，新数的对应位就为 1，并且对应位相同时则为 0：
```C++
let firstBits: UInt8 = 0b00010100
let otherBits: UInt8 = 0b00000101
let outputBits = firstBits ^ otherBits // 等于 00010001
```
**按位左移运算符（<<） 和 按位右移运算符（>>）**可以对一个数的所有位进行指定位数的左移和右移，但是需要遵守下面定义的规则。

对一个数进行按位左移或按位右移，相当于对这个数进行乘以 2 或除以 2 的运算。将一个整数左移一位，等价于将这个数乘以 2，同样地，将一个整数右移一位，等价于将这个数除以 2。
```swift
let shiftBits: UInt8 = 4 // 即二进制的 00000100
shiftBits << 1           // 00001000
shiftBits << 2           // 00010000
shiftBits << 5           // 10000000
shiftBits << 6           // 00000000
shiftBits >> 2           // 00000001
```

# 溢出运算符

```C++
var potentialOverflow = Int16.max
// potentialOverflow 的值是 32767，这是 Int16 能容纳的最大整数
potentialOverflow += 1
// 这里会报错
```
当你希望的时候也可以选择让系统在数值溢出的时候采取截断处理，而非报错。Swift 提供的三个溢出运算符来让系统支持整数溢出运算。这些运算符都是以 & 开头的：
* 溢出加法 &+
* 溢出减法 &-
* 溢出乘法 &*

# 运算符函数
类和结构体可以为现有的运算符提供自定义的实现。这通常被称为运算符重载。
```C++
struct Vector2D {
    var x = 0.0, y = 0.0
}

extension Vector2D {
    static func + (left: Vector2D, right: Vector2D) -> Vector2D {
        return Vector2D(x: left.x + right.x, y: left.y + right.y)
    }
}
```