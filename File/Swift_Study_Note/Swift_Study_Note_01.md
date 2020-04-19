# Swift学习笔记(一)：开始
# let 和 var
```swift
//常量 let 变量 var
let maxiunmUnmber:Int = 10

var currentLog = 10

```



# 分号
swift并不强制要求‘；’，甚至有的代码规范就要求别写

# Int

Swift 提供了8、16、32和64位的有符号和无符号整数类型。这些整数类型和 C 语言的命名方式很像，比如8位无符号整数类型是 UInt8，32位有符号整数类型是 Int32 。就像 Swift 的其他类型一样，整数类型采用大写命名法。

可以直接访问min、max来获取最大最小值

```swift
let minValue1 = Int.min
let minValue2 = UInt.min
let minValue3 = UInt8.min
let minValue4 = UInt16.min
let minValue5 = UInt32.min
let minValue6 = UInt64.min

let maxValue1 = Int.max
let maxValue2 = UInt.max
let maxValue3 = UInt8.max
let maxValue4 = UInt16.max
let maxValue5 = UInt32.max
let maxValue6 = UInt64.max
```

Int 有符号，UInt无符号，最好统一使用Int，避免转换问题

# 类型判断


Swift有类型判断，可以自动判断类型，但是最好还是标明


# 元组
有点类似 C++ 的 pair。

 元组（tuples）把多个值组合成一个复合值。元组内的值可以是任意类型，并不要求是相同类型。
```swift
let http404Error = (404,"Not Found")

let (statusCode,statusMessage) = http404Error
print("The status code is \(statusCode)")

//如果你只需要一部分元组值，分解的时候可以把要忽略的部分用下划线（_）标记：

let (justNeedStatusCode,_) = http404Error

print("justNeedStatusCode is \(justNeedStatusCode)")
```

# 可选类型 optionals

使用可选类型（optionals）来处理值可能缺失的情况。可选类型表示两种可能： 或者有值， 你可以解析可选类型访问这个值， 或者根本没有值。
```swfit
let possibleNumber = "123"
let convertedNumber = Int(possibleNumber)
// convertedNumber 被推测为类型 "Int?"， 或者类型 "optional Int"

```
因为该构造器可能会失败，所以它返回一个可选类型（optional）Int，而不是一个 Int。一个可选的 Int 被写作 Int? 而不是 Int。问号暗示包含的值是可选类型，也就是说可能包含 Int 值也可能不包含值。（不能包含其他任何值比如 Bool 值或者 String 值。只能是 Int 或者什么都没有。）

### nil
你可以给可选变量赋值为 nil 来表示它没有值：
```swift
var serverResponseCode: Int? = 404
// serverResponseCode 包含一个可选的 Int 值 404
serverResponseCode = nil
// serverResponseCode 现在不包含值
```

### if 语句以及强制解析

你可以使用 if 语句和 nil 比较来判断一个可选值是否包含值。你可以使用“相等”(==)或“不等”(!=)来执行比较。
```swift
if convertedNumber != nil {
    print("convertedNumber contains some integer value.")
}
// 输出“convertedNumber contains some integer value.”
```

当你确定可选类型确实包含值之后，你可以在可选的名字后面加一个感叹号（!）来获取值。这个惊叹号表示“我知道这个可选有值，请使用它。”这被称为可选值的强制解析（forced unwrapping）：
```swift
if convertedNumber != nil {
    print("convertedNumber has an integer value of \(convertedNumber!).")
}
// 输出“convertedNumber has an integer value of 123.”
```

### 隐式解析可选类型

有时候在程序架构中，第一次被赋值之后，可以确定一个可选类型总会有值。在这种情况下，每次都要判断和解析可选值是非常低效的，因为可以确定它总会有值。
这种类型的可选状态被定义为隐式解析可选类型（implicitly unwrapped optionals）。把想要用作可选的类型的后面的问号（String?）改成感叹号（String!）来声明一个隐式解析可选类型。
```swift
let possibleString: String? = "An optional string."
let forcedString: String = possibleString! // 需要感叹号来获取值

let assumedString: String! = "An implicitly unwrapped optional string."
let implicitString: String = assumedString  // 不需要感叹号
```