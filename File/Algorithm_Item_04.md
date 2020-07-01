# 二叉树的刷题之旅（三）：路径之和（上）
[路径总和](https://leetcode-cn.com/problems/path-sum/)

[路径总和II](https://leetcode-cn.com/problems/path-sum-ii/)

[路径总和III](https://leetcode-cn.com/problems/path-sum-iii/)

[路径总和IV](https://leetcode-cn.com/problems/path-sum-iv/)


路径总和是二叉树系列的一种经典题型，即**通过一个值，来找到二叉树中的路径**。

先从头说起，给定一个二叉树和一个目标和，判断该树中是否存在根节点到叶子节点的路径，这条路径上所有节点值相加等于目标和。

比如说，给了以下这个例子。


二叉树如下，以及目标和 sum = 22，

```
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

