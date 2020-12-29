# 动态规划战个痛快之线性动态规划（二）：最大子数组和系列

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

我们要首先理解一个求最大子段和的 Kadane 算法。

如果假定 dp[i] 为以 nums[i] 为结尾的最大子段和。也就是
`dp[j]= max(nums[i] + nums[i+1] +⋯+ nums[j])`

那么说，nums[j+1] 最大字段和应该取决于 nums[j+1] 的大小。即：
`dp[j+1] = nums[j+1] + max(dp[j],0)`

可以写作代码：
```C++
vector<int> dpA(A.size());
dpA[0] = A[0];
for(int i = 1;i < A.size();i++) {
    dpA[i] = A[i] + max(dpA[i-1],0);
    ans = max(ans,dpA[i]);
}
```

这里，为了节约空间复杂度，我们可以进一步演化，将 dpA 数组变成一个变量。
```C++
cur = cur = A[0];
for(int i = 1;i < A.size();i++) {
    cur = A[i] + max(cur,0);
    ans = max(ans,cur);
}
``` 

然后回到问题上。

可以发现，这个问题实际上有两种情况。
1. 这个最大和的子数组在一个区间里；
2. 这个最大和的子数组在两个区间里。

对于情况 1，我们可以直接使用 Kadane 算法来解决。

对于情况 2，可以继续将子段分为两部分，即 包括 nums[len - 1] 在内的左区间，以及以外的右区间。

右区间实际上是求以 nums[0] 为开头的子段和，也是很简单的
```C++
int rightSum = 0;
for (int i = 0; i < len-2; ++i) {
    rightSum += A[i];
    ......
}
```

那么还剩下最后一块，即这个子段的左区间，它是包含 nums[len-1] 的，额外的元素一定在它的左侧，则这段变成了求以 nums[len-1] 为结尾的子段和。当然，还有一个限制条件： **子数组最多只能包含固定缓冲区 A 中的每个元素一次。**

我们先创建一个 rightSums，用以保存左区间里的以 nums[len-1] 结尾的每一段的和；然后在计算出这里面最大的那个并保存。

然后在最后计算的时候，我们将遍历 rightSum 将其与 leftMax 相加，以获取最大值。

注意，我们在遍历的过程中，相加的是 leftMax[i+2]，因为**子数组最多只能包含固定缓冲区 A 中的每个元素一次。**


```C++
class Solution {
public:
    int maxSubarraySumCircular(vector<int>& A) {
        int len = A.size();
        int ans = A[0],cur = A[0];
        //单区间
        for(int i = 1;i < len;i++) {
            cur = A[i] + max(cur,0);
            ans = max(ans,cur);
        }
        //双区间，左右以子段为标准
        vector<int> leftSums(len);
        leftSums[len-1] = A[len-1];
        vector<int> leftMax(len);
        leftMax[len-1] = A[len-1];

        for(int i = len -2;i >=0;i--){
            leftSums[i] = leftSums[i+1] + A[i];
            leftMax[i] = max(leftMax[i+1],leftSums[i]);
        }

        int rightSum = 0;
        for (int i = 0; i < len-2; ++i) {
            rightSum += A[i];
            ans = max(ans, rightSum + leftMax[i+2]);
        }
        return ans;


    }
};
```
