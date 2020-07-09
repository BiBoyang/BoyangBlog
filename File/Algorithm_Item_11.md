
# 面试真题：字符串压缩与解压缩

这里实际上是两道题，不过正好是一对相反的过程。

# 字符串压缩
字符串压缩。利用字符重复出现的次数，编写一种方法，实现基本的字符串压缩功能。比如，字符串aabcccccaaa会变为a2b1c5a3。若“压缩”后的字符串没有变短，则返回原先的字符串。你可以假设字符串中只包含大小写英文字母（a至z）。

示例1:
```
 输入："aabcccccaaa"
 输出："a2b1c5a3"
```

示例2:
```
 输入："abbccd"
 输出："abbccd"
 解释："abbccd"压缩后为"a1b2c2d1"，比原字符串长度更长。
```
## 解答
我们从左往右遍历字符串，用 ch 记录当前要压缩的字符，count 记录 ch 出现的次数，如果当前枚举到的字符 s[i]等于 ch ，我们就更新 count 的计数，即 count = count + 1，否则我们按题目要求将 ch 以及 count 更新到答案字符串 ans 里，即 ans = ans + ch + count，完成对ch 字符的压缩。随后更新 ch 为 S[i]，count 为 1，表示将压缩的字符更改为 S[i]。

在遍历结束之后，我们就得到了压缩后的字符串 ans，并将其长度与原串长度进行比较。如果长度没有变短，则返回原串，否则返回压缩后的字符串。

```C++
class Solution {
public:
    string compressString(string S) {        
        string ans = "";
        int count = 1;
        char ch = S[0];
        for (int i = 1; i < S.size(); ++i){
            if (ch == S[i]){
                count++;
            } else {
                ans += ch + to_string(count); 
                ch = S[i];
                count = 1;
            }
        }
        ans += ch + to_string(count);

        if(ans.size() >= S.size()) {
            return S;
        } else {
           return  ans;
        }
    }
};
```
* 时间复杂度：O(n)；
* 空间复杂度：O(1)。

# 字符串解压缩

有一种简易压缩算法：针对由全部小写字母组成的字符串，将其中连续超过两个相同字目的部分压缩成连续个数加该字母，其他部分保持原样不变。

例如，字符串：aaabccccd 经过压缩成为字符串：3ab4cd。请您编写一个unZip函数，根据输入的字符串，判断其是否为合法压缩过的字符串。 
若输入合法，则输出解压后的字符串，否则输出：!error 来报告错误。

测试：3ab4cd合法，aa4b合法,caa4b合法,3aa4b不合法,22aa不合法,2a4b不合法,22a合法,3a3a不合法

据说是某厂的面试题。

## 解答

分步骤从左至右遍历
1. 先判断是否是数字，如果是，则将其提取出来，使用inPutNum 进行计数。
2. 接着判断是否是字母，如果是，则取出 inPutNum ，这里会有两种情况：
3. 如果 inPutNum 大于 0，则先判断是否有连续两个相同字母，若有，则error；若无，则继续往下，依照 inPutNum 的个数，将inPut[i] 加入 outPutString中。
4. 如果 inPutNum 等于 0，则判断是否有连续三个字符相等，若是error；若不是，则将inPut[i] 加入 outPutString中


```C++
#include <iostream>
#include <string.h>
using namespace std;
void unZip(string inPut) {
    int len = (int)inPut.length();
    if(len == 0) return;
    int inPutNum = 0;
    string outPutString = "";
    for(int i = 0;i<len;i++) {
        if(inPut[i] - '0' >= 0 && inPut[i] - '0' <= 9) {
            inPutNum = inPutNum * 10 + inPut[i] - '0';
        } else if(inPut[i] >= 'a' && inPut[i] <= 'z') {
            if(inPutNum > 0) {
                if(inPut[i] == inPut[i+1]) {
                    cout << "!Error" << endl;
                    return;
                }
                for(int j = 0;j < inPutNum;j++) {
                    outPutString += inPut[i];
                }
                inPutNum = 0;
            } else {
                //三个字符重复
                if(inPut[i] == inPut[i+1]) {
                    if(inPut[i+1] == inPut[i+2]) {
                        cout << "!Error" << endl;
                        return;
                    }
                }
                outPutString += inPut[i];
            }
        }
    }
    cout << "" << outPutString<< endl;
}


int main(int argc, const char * argv[]) {
    // insert code here...
    
    string str1 = "10ab4cdd";
    string str2 = "3abb4cd";
    string str3 = "3a4bb4cd";
    string str4 = "3abbb4cd";
    string str5 = "1abb4cd";

    unZip(str1);//aaaaaaaaaabccccdd
    unZip(str2);//aaabbccccd
    unZip(str3);//!Error
    unZip(str4);//!Error
    unZip(str5);//abbccccd
    
    return 0;
}
```