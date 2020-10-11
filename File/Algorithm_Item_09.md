# 动态规划战个痛快之线性动态规划（一）：递增子序列问题

* 线性动态规划的主要特点是状态的推导是按照问题规模 i 从小到大依次推过去的，较大规模的问题的解依赖较小规模的问题的解。


<!--这里有几种典型的例题：
* 最长上升子序列(LIS):Longest IncreasingSubsequence
* 最长连续序列(LCS):Longest Consecutive Sequence
* 最长连续递增序列(LCIS):Longest Continuous Increasing Subsequence
* 最长公共子序列(LCS): Longest Common Subsequence

-->


## 连续递增序列
先从最简单的开始说起。给定一个未经排序的整数数组 nums，找到最长且连续的的递增序列，并返回该序列的长度。

我们可以非常清楚的知道，每一位的递增子序列，都是从前面一步一步加上来的。

假定一维数组 dp 表示数组每一位的最长长度，则可以很清楚的知道，如果 nums[i - 1] < nums[i]，则 dp[i] = dp[i - 1] + 1。那么就可以做出状态转移方程。

![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/leetcode_0674_00.png?raw=true)

同样的，也就可以写出核心代码：
```C++
if(nums[i - 1] < nums[i]) {
    dp[i] = dp[i - 1] + 1;
}
```


## 求连续序列长度

如果把限制条件里的连续去除，只需要找到其中最长上升子序列的长度，那该如何呢？

同样，用一维数组 dp 表示数组中每一位的最长长度。如果 nums[j] < nums[i]，则
dp[i] = max(dp[j] + 1,dp[i])，状态转移方程如下：

![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/leetcode_0300.png?raw=true)

核心代码如下：
```C++
for(int i = 1;i < nums.size();i++) {
    for(int j = 0;j < i;j++) {
        if(nums[j] < nums[i]) {
            dp[i] = max(dp[i],dp[j]+1);
        }
    }
}
```

继续，我们得到了最长上升子序列的长度，那么，如果想要获取拥有最长上升子序列的长度的子串的数量呢？

对于 nums[i]，我们可以设定当前的最长序列长度 lengths[i]，以及当前的该长度的序列数量 counts[i]。

假设，0 < j < i,那么我们只需要考虑 nums[i] > nums[j] 这一种情况，只有这样才会形成递增序列；如果 nums[i] <= nums[j]，则说明递增长度为 1 。

然后我们判断 lengths[i] 和 length[j] + 1 的大小。
* 如果 lengths[i] < lengths[j] + 1，则说明当前产生了一个**新**的最长序列长度（因为我们已经知道nums[i] > nums[j]），则 lengths[i] 则会更新为 lengths[j] + 1，序列的数量，也会延续下来，并不发生改变。
* 如果 lengths[i] == lengths[j] + 1，则说明当前这个长度**已经有过了**。我们则需要将这两个数量结合起来，加到一起，即 counts[i] == counts[i] + counts[j]。

然后再遍历一次 lengths，找到这个长度数组中，和最大长度相同的那个位置，

做一个表格展示一下。假定数组是 [1,2,4,3,5,4,1]。


| 数组  | 1  | 2  | 4  |  3 |  5 | 4  |  1 |
|---|---|---|---|---|---|---|---|
| index  | 0  | 1  | 2  | 3  | 4  | 5  | 6  |
| lengths  | 1  | 2  | 3  | 3  |  <font color=#FF0000 >**4**</font> |  <font color=#FF0000 >**4**</font> |  1 |
| counts  | 1  |  1 |  1 | 2  |  <font color=#FF0000 >**2**</font> |  <font color=#FF0000 >**1**</font> |  1 |

可以发现，是 index 为 4、5 位的长度最长，则将 counts[4] + counts[5]，得到的结果替换为新的 counts[5]。

核心代码如下：
```C++
for(int i = 1;i < len;i++) {
    for(int j = 0;j < i;j++) {
        if(nums[i] > nums[j]) {
            if(lengths[i] < lengths[j] + 1) {
                lengths[i] = max(lengths[i],lengths[j] + 1);
                counts[i] = counts[j];
            } else if(lengths[i] == lengths[j] + 1) {
                counts[i] = counts[i] + counts[j];
            }
        }
    }
    maxLength = max(maxLength,lengths[i]);
}
```

里面有些代码可以继续优化，完整代码如下：

```C++
class Solution {
public:
    int findNumberOfLIS(vector<int>& nums) {
        int len = nums.size();
        if(len == 0) return 0;
        vector<int> lengths(len,1);
        vector<int> counts(len,1);
        int maxLength = 1;
        int res = 0;
        // 0 < j < i
        for(int i = 1;i < len;i++) {
            for(int j = 0;j < i;j++) {
                if(nums[i] > nums[j]) {
                    if(lengths[i] < lengths[j] + 1) {
                        lengths[i] = lengths[j] + 1;
                        counts[i] = counts[j];
                    } else if(lengths[i] == lengths[j] + 1) {
                        counts[i] = counts[i] + counts[j];
                    }
                }
            }
            maxLength = max(maxLength,lengths[i]);
        }
        for(int i = 0;i < len;i++) {
            if(maxLength == lengths[i]) {
                res += counts[i];
            }
        }
        return res;
    }
};
```

## 俄罗斯套娃信封问题
俄罗斯套娃信封，是一个条件比较复杂的 LIS 问题。

题目是这样的：给了一些有明确宽度（w 表示）和高度（h 表示）的信封，当信封 a 的宽度和高度都比信封 b 大的时候，就可以将信封 b 放入到信封 a 中，以此类推，如同俄罗斯套娃一样。计算最多能有多少个信封组成这样一个组合。

### 难点

非常容易发现，这道题其实就是递增子序列问题的一个变种，难点不在于得到需要使用动态规划这个结论，而在于如何处理数据。

第一步的处理方法其实非常容易想到：将 w 按照从小到大排序，那么对于 w 就是一个递增序列了。

关键在于第二步，我们要将 w 相同的书籍，按照 h 从大到小顺序排列。

由于 w 相等，那么只有 h 由大到小排序才不会计算重复的子序列（即 w 相等，只有 h 由大到小排序才不会重复计算套娃信封）。比如 [1,4]、[4,6]、[4,7]，若按h由小到大排序降维之后的数组为[4,6,7]，这样形成的可套娃的序列长度为3，这个是不正确的，因为只有(w2 > w1,h2 > h1)才能进行套娃。若我们按h由大到小排序之后降维之后的数组为 [4,7,6]，这样可形成两个长度为2的可套娃子序列 [3,4]、[4,7] 和 [3,4]、[4,6]，这样便满足条件了。

接着就按照正常的流程，计算 dp[i] 即可。

```C++
class Solution {
public:
    int maxEnvelopes(vector<vector<int>>& envelopes) {
        int len = envelopes.size();
        if(len == 0) return 0;
        int res = 0;
        vector<int> dp(len,1);

        sort(envelopes.begin(),envelopes.end(),[](const vector<int>& a,const vector<int>& b){
            if(a[0] == b[0]) {
                return a[1] > b[1];
            } else{
                 return a[0] < b[0];
            }
        });
        // 0 < j < i
        for(int i = 0;i < len;i++){
            for(int j = 0;j < i;j++){
                if(envelopes[j][1] < envelopes[i][1]){
                    dp[i] = max(dp[i],dp[j] + 1);
                }
            }
            res=max(res,dp[i]);
        }
        return res;
    }
};

```


