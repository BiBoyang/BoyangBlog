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

