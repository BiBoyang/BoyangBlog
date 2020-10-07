# 动态规划战个痛快（一）：线性动态规划（一）：递增子序列问题

线性动态规划的主要特点是状态的推导是按照问题规模 i 从小到大依次推过去的，较大规模的问题的解依赖较小规模的问题的解。


这里有几种典型的例题：
* 最长上升子序列(LIS):Longest IncreasingSubsequence
* 最长连续序列(LCS):Longest Consecutive Sequence
* 最长连续递增序列(LCIS):Longest Continuous Increasing Subsequence
* 最长公共子序列(LCS): Longest Common Subsequence



# 最长连续递增序列

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

接着，如果把限制条件里的连续去除，只需要找到其中最长上升子序列的长度，那该如何呢？

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


