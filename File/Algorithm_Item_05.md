# 二叉树的刷题之旅（四）：路径之和（下）

1. [求根到叶子节点数字之和](https://leetcode-cn.com/problems/sum-root-to-leaf-numbers/)
2. [二叉树的所有路径](https://leetcode-cn.com/problems/binary-tree-paths/)
3. [二叉树中最长的连续序列](https://leetcode-cn.com/problems/binary-tree-longest-consecutive-sequence-ii/)    
4. [二叉树最长连续序列](https://leetcode-cn.com/problems/binary-tree-longest-consecutive-sequence/)
5. [最长同值路径](https://leetcode-cn.com/problems/longest-univalue-path/)   


# 正文
继续来搞二叉树的路径问题。

给定一个二叉树，它的每个结点都存放一个 0-9 的数字，每条从根到叶子节点的路径都代表一个数字。计算从根到叶子节点生成的所有数字之和。

例如，从根到叶子节点（没有子节点的节点）路径 1->2->3 代表数字 123。

对于这道题，其实就是延续上文的解法，继续使用递归。

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

而要获取二叉树所有从根节点到叶子节点的路径，也是类似的方法。
```C++
class Solution {
public:
    vector<string> res;
    void helper(TreeNode* root,string str) {
        if (root == NULL) return;  
        if (root->left == NULL && root->right == NULL) {
            str += to_string(root->val);
            res.push_back(str);
        }
        str = str + to_string(root->val) + "->";
        if(root->left) helper(root->left, str);
        if(root->right) helper(root->right, str);
    }
    vector<string> binaryTreePaths(TreeNode* root) {
        if(root == NULL) return res;
        string str = "";
        helper(root, str);
        return res;
    }
};
```

以上两道题，都是需要从根节点直接