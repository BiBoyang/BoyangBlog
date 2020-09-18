# 字符串匹配算法 🚧

# 双指针暴力
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



# RK 算法

# KMP 算法

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


