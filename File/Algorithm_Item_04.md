# 二叉树的刷题之旅（三）：路径之和 
[路径总和](https://leetcode-cn.com/problems/path-sum/)<br>[路径总和II](https://leetcode-cn.com/problems/path-sum-ii/)<br>[路径总和III](https://leetcode-cn.com/problems/path-sum-iii/)<br>[二叉树中的最大路径和](https://leetcode-cn.com/problems/binary-tree-maximum-path-sum/)

# 正文
路径总和是二叉树系列的一种经典题型，即**通过一个值，来找到二叉树中的路径**。

## 根节点参与的情况下

先从头说起，给定一个二叉树和一个目标的和，判断该树中是否存在根节点到叶子节点的路径，这条路径上所有节点值相加等于目标和。

比如说，给了以下这个例子。

二叉树如下，以及目标和 **sum** = 22。

```C++
              5
             / \
            4   8
           /   / \
          11  13  4
         /  \      \
        7    2      1
```

返回 **true**， 因为存在目标和为 22 的根节点到叶子节点的路径 **5->4->11->2**。

想当然的，我们可以这么想，遍历整棵树：
1. 如果当前节点不是叶子，对它的所有孩子节点，递归调用 hasPathSum 函数，其中 sum 值减去当前节点的权值；
2. 如果当前节点是叶子，检查 sum 值是否为 0，也就是是否找到了给定的目标和。


```C++
class Solution {
public:
    bool isHasPath = false;
    void dfs(TreeNode *root,int sum) {
        if(root == NULL) return;
        sum = sum - root->val;
        if((root->left == NULL) && (root->right == NULL)) {
            if(sum == 0) isHasPath = true;
        }
    if(root->left) dfs(root->left,sum);
    if(root->right) dfs(root->right,sum);
	   
    }
    bool hasPathSum(TreeNode* root, int sum) {
        if(root) dfs(root, sum);
        return isHasPath;
    }
};
```

然后接着深入问，如果知道存在根节点到叶子节点的路径，那么有哪几条呢？

我们可以继续延续上面的思路，**注意这里的根节点一定是在路径中的**。如何符合条件，就加入数组中，如果不符合，则清空数组。

```C++
class Solution {
public:
	vector<vector<int>> res;
	vector<int> current_total;
	
	void dfs(TreeNode *root,int sum) {
		if(root == NULL) return ;
		sum = sum - root->val;
		current_total.push_back(root->val);
		if(root->left == NULL && root->right == NULL && sum == 0) {
			res.push_back(current_total);
		}
		if(root->left) dfs(root->left,sum);
		if(root->right) dfs(root->right,sum);

		current_total.pop_back();
	}

    vector<vector<int>> pathSum(TreeNode* root, int sum) {
        if(root) dfs(root,sum);
        return res;
    }
};

```

可以总结规律：
1. 不断地递归进入下一层的同时减少 sum 的值；
2. 明确终止条件。

## 如果没有根节点参与
以上两题，都是**根节点参与其中**的，解题思路实际上只是不停的递归下去；那么如果可以没有根节点参与的情况下呢？这个路径如果可以拐弯呢？那么就变得复杂起来了。

```C++
      10
     /  \
    5   -3
   / \    \
  3   2   11
 / \   \
3  -2   1
```
比如这个二叉树，如果我求路径和为 8 的路径，那么实际上会有 3 条，即
```C++
5 -> 3
5 -> 2 -> 1
-3 -> 11
```
那么该如何解决呢？

我们其实可以将其转化为上面的思路：
1. 递归下去每个子节点；
2. 以每个子节点为新的根节点，然后左右递归下去，同时记录 sum 的变化。


```C++
class Solution {
public:
    int res = 0;
    void dfs(TreeNode* root, int sum) {
        if (root== NULL) return ;
        sum = sum - root->val;
        if(sum == 0)  res++;
        if(root->left) dfs(root->left, sum);
        if(root->right) dfs(root->right, sum);
    }
    int pathSum(TreeNode* root, int sum) {
        if (root == NULL) return 0;
        dfs(root, sum);
        if(root->left) pathSum(root->left, sum);
        if(root->right) pathSum(root->right, sum);
        return res;
    }
};
```
## 最大的路径
这道题简单明了，如何获取最大的那个路径和。这里的路径，被定义为**一条从树中任意节点出发，达到任意节点的序列。该路径至少包含一个节点，且不一定经过根节点**。

我们需要分析各种情况。建立一个简易的二叉树，如图所示：
```C++
    d
    |
    a
   / \
  b   c
```

对于一个路径，可以有以下几种情况：

1. d->a->b
2. d->a->c
3. b->a->c

对于情况 1、2，我们可以递归时计算 a + b 和 a + c，选择一个更优的方案返回，也就是上面思路的递归后的最优解。

而情况 3 则复杂一些：a 点可能是根节点，也就是说 d 其实并不存在；a 是左边路径和右边路径的转折点。

这种路径的方式，本身就有可能是最大和，我们需要考虑到它的情况。我们就可以去递归的计算左节点和右节点的值，即按照情况 1 和 2 的路线走；但是每到一个节点，还需要去计算本身以它为转折点的路径的和，最后将两者进行比较。

```C++
class Solution {
public:
    int cur_sum = INT_MIN;
    int maxPathSum(TreeNode* root) {
        maxPath(root);
        return cur_sum;
    }
    int maxPath(TreeNode *root) {
        if(root == NULL) return 0;
        // 计算左边分支最大值
        int leftMax = max(maxPath(root->left),0);
        // 计算右边分支最大值
        int rightMax = max(maxPath(root->right),0);
        // 计算 左->根->右 路线上的最大值
        int lmr = root->val + left +right;
        // 左->根->右 和 历史最大值做对比
        sum = max(sum, lmr);
        // 返回经过root的单边最大分支给上游
        return root->val + max(left,right);
    }
};
```

# 总结

总结一下规律：
1. 要循序渐进的递归到下一层；
2. 要在递归的同时，调整 sum 的变化，并密切观察 sum 为 0 的情况。

我们可以设置一个简易的模板如下。
```C++
void dfs(TreeNode *root,int sum) {
		if(root == NULL) return ;
		// 每次减少 sum 的值
		sum = sum - root->val;
		// 设置终点
		if(root->left == NULL && root->right == NULL && sum == 0) {
			// 在终点的操作
		}
		// 左右子节点继续递归下去
		if(root->left) dfs(root->left,sum);
		if(root->right) dfs(root->right,sum);
	}
```

而对于求最大路径和，我们也继续沿用上述的思路，左右递归，但是同时要考虑到特殊情况，去完善方法。
