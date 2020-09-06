# 二叉树的刷题之旅（四）：路径之和（下）

1. [最长同值路径](https://leetcode-cn.com/problems/longest-univalue-path/) 
2. [二叉树最长连续序列](https://leetcode-cn.com/problems/binary-tree-longest-consecutive-sequence/)
3. [二叉树中最长的连续序列](https://leetcode-cn.com/problems/binary-tree-longest-consecutive-sequence-ii/)    

  


# 正文


如果给定了一个二叉树，该如何找到最长的那个路径呢？设定这条路径的每个节点的值都是相同的，可以经过也可以不经过根节点。



```C++
class Solution {
public:
    int helper(TreeNode* node, int &ans) {
        if (node == NULL) return 0;
        int leftLen = helper(node->left, ans);
        int rightLen = helper(node->right, ans);
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
        int ans = 0;
        helper(root, ans);
        return ans;
    }
};
```