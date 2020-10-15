# 动态规划战个痛快之线性动态规划（二）：最大子数组和系列 🚧

<!--最大子序和
乘积最大子数组
环形子数组的最大和 —— 环形数组的处理
最大子矩阵 —— 思路类似一维的最大子数组和
矩形区域不超过 K 的最大数值和
-->

## 最大子序和 

先从最简单的说起，有一个整数数组 nums，找到里面和最大的那个连续子数组，并返回最大和。

这道题非常简单，对于一个连续子数组的最大和，假设为 dp[i],则
dp[i] = max(dp[i] + nums[i],nums[i])。

核心代码如下：
```C++
for(int i = 1;i < len;i++) {
    dp[i] = max(dp[i - 1] + nums[i],nums[i]);
    res = max(dp[i],res);
}
```

看完简单了，我们接着来看另外一道类似的题。

还是给定一个整数数组，找到里面乘积最大的连续子数组。

最开始的思路可能还是会按照最大子序和的方式，使用状态转移方程 dp[i] = max(dp[i] + nums[i],nums[i]) 来求得结果，但是这个结果是有一个非常大的缺点的：没有考虑到负数的情况，有时候本来是一个负数的时候，乘以一个负数就会变得最大，所以我们要做两套方案来准备。

分别设置两个动态规划数组，maxDP 和 minDP，分别进行记录结果。则状态转移方程变成了
* maxDP[i] = max( max (maxDP[i - 1] * nums[i],nums[i]),minDP[i - 1] * nums[i]);
* minDP[i] = min( min (maxDP[i - 1] * nums[i],nums[i]),minDP[i - 1] * nums[i]);

就可以解决了。

```C++
class Solution {
public:
    int maxProduct(vector<int>& nums) {
        int len = nums.size();
        if(len == 0) return 0;
        int res = nums[0];
        vector<int> maxDP(len);
        vector<int> minDP(len);
        maxDP[0] = nums[0];
        minDP[0] = nums[0];
        for(int i = 1;i < len;i++) {
            maxDP[i] = max( max (maxDP[i - 1] * nums[i],nums[i]),minDP[i - 1] * nums[i]);
            minDP[i] = min( min (maxDP[i - 1] * nums[i],nums[i]),minDP[i - 1] * nums[i]);
            res = max(maxDP[i],res);
        }
        return res;
    }
};
```


# 环形子数组

如果给定一个整数数组，是头尾相连的一个环呢？那该如何找到这个最大的字段和？

即，这里是一个环形数组，意味着数组的末端将会与开头相连呈环状。并且，**子数组最多只能包含固定缓冲区 A 中的每个元素一次，不能重复占用。**
