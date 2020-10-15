# 二叉树的刷题之旅（四）：路径之和（下）

* [最长同值路径](https://leetcode-cn.com/problems/longest-univalue-path/) 
* [二叉树最长连续序列](https://leetcode-cn.com/problems/binary-tree-longest-consecutive-sequence/)
* [二叉树中最长的连续序列](https://leetcode-cn.com/problems/binary-tree-longest-consecutive-sequence-ii/)    

  


# 正文


如果给定了一个二叉树，该如何找到最长的那个路径呢？设定这条路径的每个节点的值都是相同的，可以经过也可以不经过根节点。

我们可以将任何路径（具有相同值的节点）看作是最多两个从其根延伸出的箭头。

具体地说，路径的根将是唯一节点，因此该节点的父节点不会出现在该路径中，而箭头将是根在该路径中只有一个子节点的路径。

然后，对于每个节点，我们想知道向左延伸的最长箭头和向右延伸的最长箭头是什么？我们可以用递归来解决这个问题。

令 leftLen 为从节点 node 延伸出的最长箭头的长度。如果 node->left 存在且与节点 node 具有相同的值，则该值就会是 leftLen + 1。在 node->right 存在的情况下也是一样。

当我们计算箭头长度时，候选答案将是该节点在两个方向上的箭头之和。我们将这些候选答案记录下来，并返回最佳答案。



```C++
class Solution {
public:
    int ans = 0;
    int helper(TreeNode* node ) {
        if (node == NULL) return 0;
        int leftLen = helper(node->left);
        int rightLen = helper(node->right);
        if(node->left && node->val == node->left->val) {
            leftLen =  leftLen + 1;
        } else {
            leftLen = 0;
        }
        if(node->right && node->val == node->right->val) {
            rightLen = rightLen + 1;
        } else {
            rightLen = 0;
        }
        ans = max(ans, leftLen + rightLen);
        return max(leftLen, rightLen);
    }
    int longestUnivaluePath(TreeNode* root) {
        helper(root);
        return ans;
    }
};
```

继续下去，假如要寻找二叉树中最长的连续序列路径的长度，即要么递增要么递减，只可以是「父 - 子」关系的话，该怎么处理呢。

```C++
class Solution {
public:
    int MaxLength = 0;
    void helper(TreeNode *root,TreeNode *pre,int length) {
        if(root == NULL) return ;
        if(pre != NULL && root->val == pre->val + 1) {
            length = length + 1;
        } else {
            length = 1;
        }
        MaxLength = max(MaxLength,length);
        if(root->left) helper(root->left,root,length);
        if(root->right) helper(root->right,root,length);
    }
    
    int longestConsecutive(TreeNode* root) {
        if(root == NULL) return 0;
        helper(root,NULL,0);
        return MaxLength;
    }
};
```

好，更进一步，路径可以是子-父-子的关系，那么该如何寻找呢？

可以分别考虑子节点逆序最大长度与顺序最大长度。

```C++
class Solution {
public:
    int res = 0;
    //pair 第一位表示递减。第二位表示递增
    pair<int, int> helper(TreeNode* root) {
        if (root == NULL) return {0, 0};
        auto l = helper(root->left);
        auto r = helper(root->right);
        int l1 = 0;
        int l2 = 0;
        int r1 = 0;
        int r2 = 0;
        if (root->right && root->right->val + 1 == root->val) {
            r1 = r.first;
        } else if (root->right && root->right->val - 1 == root->val) {
            r2 = r.second;
        }
        if (root->left && root->left->val + 1 == root->val) {
            l1 = l.first;
        } else if (root->left && root->left->val - 1 == root->val) {
            l2 = l.second;
        }
        int len = max(l1 + 1 + r2, l2 + 1 + r1);
        res = max(res, len);
        return {max(l1, r1) + 1, max(l2, r2) + 1};
    }
    int longestConsecutive(TreeNode* root) {
        helper(root);
        return res;
    }
};
```




