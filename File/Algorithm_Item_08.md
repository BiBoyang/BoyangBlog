# 字符串匹配算法 🚧

字符串匹配算法详解。

给定一个 haystack 字符串和一个 needle 字符串，在 haystack 字符串中找出 needle 字符串出现的第一个位置 (从0开始)。如果不存在，则返回  -1。

设定假如匹配成功，haystack 从 i 位置开始匹配，needle 从 j 位置开始匹配；haystack 长度为 M，needle 长度为 N。


# 双指针暴力

这种查找非常易于理解。主要分为两个步骤：

1. 如果当前字符匹配成功，即 `haystack[i] == needle[j]`，则继续往后匹配；
2. 如果匹配失败，即 `haystack[i] ！= needle[j]`，则 i++，j = 0。

画图举例。假定 haystack 为 **ACCBBADC**，needle 为 **CBB**。

第一步。haystack[0] 为 A，needle[0] 为 C ，不匹配，则执行步骤 2。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_01.png?raw=true)

第二步。haystack[1] 为 C，needle[0] 为 C ，匹配，则执行步骤 1，向后匹配。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_02.png?raw=true)

第三步。haystack[2] 为 C，needle[1] 为 B ，不匹配，则执行步骤 2。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_03.png?raw=true)

第四步。haystack[2] 为 C，needle[0] 为 C ，匹配，则执行步骤 1，向后匹配。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_04.png?raw=true)

第五步。haystack[2] 为 B，needle[1] 为 B ，匹配，则执行步骤 1，向后匹配。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_05.png?raw=true)

第六步。haystack[3] 为 C，needle[2] 为 C ，匹配，匹配成功。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_06.png?raw=true)

代码如下。

```C++
class Solution {
public:
    int strStr(string haystack, string needle) {
        int len1 = haystack.size(), len2 = needle.size();
        for(int i = 0; i < len1 - len2 + 1; ++i){
            bool flag = true;
            for(int j = 0; j < len2; ++j){
                if(haystack[i+j] != needle[j]){
                    flag = false;
                    break;
                }
            }
            if(flag){
                return i;
            }
        }
        return -1;
    }

};
```

这个时间复杂度在最坏的情况下，是 `O((M-N)N)`,假如 `N = (M / 2)`，则运行时间是`O( N^2 )`，最优情况为 `O(N)`。

那么有没有更快的方法呢？答案是肯定的，继续往下看。

# Knuth–Morris–Pratt 算法

Knuth–Morris–Pratt 算法，即 KMP 算法，是由 Knuth、Morris、Pratt 三人设计的线性时间字符串匹配算法。

KMP 算法主要有两步：
1. 计算、构建 next 数组；
2. 根据 next 数组直接匹配。

有了 next 数组之后，计算过程也是分为两步：
1. 如果 `j = -1`，或者字符匹配成功，即 `haystack[i] == needle[j]`，都让 i++、j++，继续匹配下一个字符；
2. 如果j != -1，且当前字符匹配失败（即 `haystack[i] != needle[j]`），则令 i 不变，`j = next[j]`。这意味着失配时，needle 相对于 haystack 向右移动了 `j - next [j]` 位。

KMP 算法的核心，在于一个叫做**部分匹配表（The Partial Match Table）**的东西，理解 KMP 算法最重要的是理解 PMT 里数字的含义。


画图举例。假定 haystack 为 **abcaabbab**，needle 为 **abbab**。

第一步，先求得前后缀数组。

要先说明，这里说的前缀、后缀，是字符串的前后缀，即字符串 A = 字符串 B + 非空字符串 S，那么 B 可以被称为 A 的前缀。举例，”String“ 的前缀有 “S”、“St”、“Str”、“Stri”、“Strin”。后缀同理。

| needle字符串  | a | ab  | abb | abba | abbab |
|---|---|---|---|---|---|
| 最长相同前后缀 | 无 | 无 | 无 | a| ab|
| PMT  | 0 | 0  | 0 | 1| 2 |

如果在第 j 位失配，则影响 j 指针回溯的位置的其实是第 j −1 位的 PMT 值。

第二步，为了编程方便，在数组前添加 -1。得到 next 数组。

| needle字符串分割  | a | b  | b | a | b |
|---|---|---|---|---|---|
| next 数组  | -1 | 0 | 0 | 0| 1|

代码如下。这是模式 needle 对于自己的匹配。

```C++
vector<int> getNext(string str) {
    int len = str.size();
    vector<int> next;
    next.push_back(-1);
    int j = 0,k = -1;
    while(j < len) {
        if(k == -1 || str[j] == str[k]) {
            j++;
            k++;
            next.push_back(k);
        }else {
            k = next[k];
        }
    }   
    return next;
}
```

取得 next 数组之后，即执行后续计算的两步。剩余代码代码如下。

```C++
int strStr(string haystack, string needle) {
    if(needle.empty()) return 0;
    int i = 0;
    int j = 0;
    vector<int> next;
    next = getNext(needle);
    while((i < haystack.size();) && (j < needle.size())) {
        if((j == -1) || (haystack[i] == needle[j])) {
            i++;
            j++;
        }else {
            j = next[j];
        }
    }
    if(j == needle.size()) {
        return i - j;
    } else {
        return -1;
    }
}
```



依旧以上面的为例。

先求得 `abbab`的 next 数组为 **[-1,0,0,0,1]**。

第一步，先从头开始匹配，发现 haystack[0] == needle[0]，并继续向后。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_07.png?raw=true)

第二步，发现，haystack[2] != needle[2]，则 j 赋值为 0(next[2])。 

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_08.png?raw=true)

第三步，needle 向右移动 2 位之后，发现 haystack[2] != needle[0]，则 j 赋值为 -1 (next[0])。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_09.png?raw=true)

第四步，之后 i 变成 3，j 变成 0，相当于 needle 向右移动 1 位。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_10.png?raw=true)

第五步，needle 向右移动 1 位后，haystack[3] == needle[0]，继续向后。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_11.png?raw=true)

第六步，发现，haystack[4] != needle[1]，则 j 赋值为 0 (next[1])。

![](https://github.com/BiBoyang/BoyangBlog/blob/master/Image/string_matches_12.png?raw=true)

needle 向右移动 1 位之后，haystack[4] == needle[0]，并继续向右。



### 优化 getNext

在上述第二步失配，然后进入第三步也继续失配，这里就浪费了一次移动。

这里的问题，是因为在第一次失配（haystack[i] != needle[j]）的时候，执行了 j = next[j]，而再下一步，则会是 needle[next[j]] 去比较 haystack[i]，但是 上一步已经有了结果，必然会继续失配，所以必然不可以让 needle[j] = needle[next[j]]。

所以我们要在 getNext 函数中做修改。
```C++
vector<int> getNext(string str) {
    int len = str.size();
    vector<int> next;
    next.push_back(-1);
    int j = 0,k = -1;
    while(j < len) {
        if(k == -1 || str[j] == str[k]) {
            j++;
            k++;
            if(str[j]!=str[k]){
                next.push_back(k);
            }else {
                next.push_back(next[k]);
            }
        }else {
            k = next[k];
        }
    }   
    return next;
}
```





# BM 算法

# Sunday 算法

```C++
class Solution {
public:
    int strStr(string haystack, string needle) {
        if(needle.empty())
            return 0;
        
        int slen = haystack.size();
        int tlen = needle.size();
        int i = 0,j = 0;//i指向源串首位 j指向子串首位
        int k;
        int m = tlen;//第一次匹配时 源串中参与匹配的元素的下一位
        
        for(;i<slen;) {
            if(haystack[i]!=needle[j]) {
                for(k = tlen-1;k >= 0;k--)//遍历查找此时子串与源串[i+tlen+1]相等的最右位置
                {
                    if(needle[k]==haystack[m])
                        break;
                }
                i = m-k;//i为下一次匹配源串开始首位 Sunday算法核心：最大限度跳过相同元素
                j = 0;//j依然为子串首位
                m = i+tlen;//m为下一次参与匹配的源串最后一位元素的下一位
                if(m>slen)//当下一次参与匹配的源串字数的最后一位的下一位超过源串长度时
                    return -1;
            } else {
                if(j == tlen - 1)//若j为子串末位 匹配成功 返回源串此时匹配首位
                    return i-j;
                i++;
                j++;
            }
        }
        return -1;//当超过源串长度时 
    }
};

```


