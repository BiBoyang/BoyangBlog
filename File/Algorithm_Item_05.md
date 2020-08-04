# 二叉树的刷题之旅（四）：路径之和（下）

1. 求根到叶子节点数字之和   
2. 二叉树的所有路径    
3. 二叉树中最长的连续序列    
4. 二叉树最长连续序列
5. 最长同值路径   


# 正文
继续来搞二叉树的路径问题。

给定一个二叉树，它的每个结点都存放一个 0-9 的数字，每条从根到叶子节点的路径都代表一个数字。计算从根到叶子节点生成的所有数字之和。

例如，从根到叶子节点（没有子节点的节点）路径 1->2->3 代表数字 123。

对于这道题，其实就是延续上文的解法，使用递归方法。

```C++
class Solution {
public:
    int res = 0;
    void dfs(TreeNode *root,int sum) {
        if (root == NULL)return;
        sum = sum * 10 + root->val;
        if(root->left == NULL && root->right == NULL) {
            res += sum;
        }
        if(root->left) dfs(root->left, sum);
        if(root->right) dfs(root->right, sum);
    }
    
    int sumNumbers(TreeNode* root) {
        if(root == NULL) return 0;
        dfs(root, 0);
        return res;
    }
};
```
