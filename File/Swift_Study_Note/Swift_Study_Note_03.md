# Swift学习笔记(三)：字符串

Swift 的 String 类型与 Foundation NSString 类进行了无缝桥接。Foundation 还对 String 进行扩展使其可以访问 NSString 类型中定义的方法。这意味着调用那些 NSString 的方法，你无需进行任何类型转换。

# 字符串字面量
```C++
let someString = "Some string literal value"

```

如果你需要一个字符串是跨越多行的，那就使用多行字符串字面量 — 由一对三个双引号包裹着的具有固定顺序的文本字符集：
```C++
let quotation = """
The White Rabbit put on his spectacles.  "Where shall I begin,
please your Majesty?" he asked.

"Begin at the beginning," the King said gravely, "and go on
till you come to the end; then stop."
"""
```

# 初始化空字符串
```C
var emptyString = ""               // 空字符串字面量
var anotherEmptyString = String()  // 初始化方法
// 两个字符串均为空并等价。
```

你可以通过检查 Bool 类型的 isEmpty 属性来判断该字符串是否为空：
```
if emptyString.isEmpty {
    print("Nothing to see here")
}
// 打印输出：“Nothing to see here”
```

# 字符串是值类型
在 Swift 中 String 类型是值类型。如果你创建了一个新的字符串，那么当其进行常量、变量赋值操作，或在函数/方法中传递时，会进行值拷贝。在前述任一情况下，都会对已有字符串值创建新副本，并对该新副本而非原始字符串进行传递或赋值操作。

Swift 默认拷贝字符串的行为保证了在函数/方法向你传递的字符串所属权属于你，无论该值来自于哪里。你可以确信传递的字符串不会被修改，除非你自己去修改它。

在实际编译时，Swift 编译器会优化字符串的使用，使实际的复制只发生在绝对必要的情况下，这意味着你将字符串作为值类型的同时可以获得极高的性能。

# 使用
你可通过 for-in 循环来遍历字符串，获取字符串中每一个字符的值：
```C++
for character in "Dog!🐶" {
    print(character)
}
// D
// o
// g
// !
// 🐶
```

你也可以通过加法赋值运算符（+=）将一个字符串添加到一个已经存在字符串变量上：
```C++
var instruction = "look over"
instruction += string2
// instruction 现在等于 "look over there"
```
你可以用 append() 方法将一个字符附加到一个字符串变量的尾部：
```C++
let exclamationMark: Character = "!"
welcome.append(exclamationMark)
// welcome 现在等于 "hello there!"
```

# 计算数量
如果想要获得一个字符串中 Character 值的数量，可以使用 count 属性：
```C++
let unusualMenagerie = "Koala 🐨, Snail 🐌, Penguin 🐧, Dromedary 🐪"
print("unusualMenagerie has \(unusualMenagerie.count) characters")
// 打印输出“unusualMenagerie has 40 characters”
```

# 修改字符串