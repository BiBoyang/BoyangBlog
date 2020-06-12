# 二叉树的刷题之旅（二）：深度问题

[104. 二叉树的最大深度](https://leetcode-cn.com/problems/maximum-depth-of-binary-tree/)     

[111. 二叉树的最小深度](https://leetcode-cn.com/problems/minimum-depth-of-binary-tree/)     

[559. N叉树的最大深度](https://leetcode-cn.com/problems/maximum-depth-of-n-ary-tree/)     

# 二叉树的最大深度
最简单的办法就是使用 DFS 的递归，每递归一次，就选择左子树深度和右子树深度最大的那个 + 1。
```C++
class Solution {
public:
    int maxDepth(TreeNode* root) {
        if(root == NULL) {
            return 0;
        } else  {
            int left_depth = maxDepth(root->left);
            int right_depth = maxDepth(root->right);
            return max(left_depth,right_depth) + 1;
        }
    }
};
```

我们知道，但凡使用递归解决的问题，都可以考虑一下`栈`。

所以我们从包含根结点且相应深度为 1 的栈开始。然后我们继续迭代：**将当前结点弹出栈并推入子结点。每一步都会更新深度。**

```C++
class Solution {
public:
    int maxDepth(TreeNode* root) {
        int ans = 0;
        if(root == NULL) return ans;
        //这个栈用来记录节点和深度
        stack<pair<TreeNode*,int>> nodeStack;
        int deep = 0;
        while(root || !nodeStack.empty()) {
            while(root) {
                deep++;
                nodeStack.push(pair<TreeNode*,int>(root,deep));
                root = root->left;
            }
            root = nodeStack.top().first;
            deep = nodeStack.top().second;
            ans = max(ans, deep);
            nodeStack.pop();
            root = root->right;
        }
        return ans;
    }
};

```
看起来求最大深度非常简单易懂，即使是用迭代的方法，也是将所有的节点的高度都加入到栈中，然后每次拿出栈顶点和最大值作对比，得到最深的深度。

然而求最小的深度的时候，就有点难办了。

递归法。
也是同样的递归求值。
```C++
class Solution {
public:
    int minDepth(TreeNode* root) {
        if(root == NULL) {
            return 0;
        }
        if((root->left == NULL) && (root->right == NULL)) {
            return 1;
        }
        int temp = INT_MAX;
        if(root->left != NULL) {
            temp = min(minDepth(root->left),temp);
        }
        if(root->right != NULL) {
            temp = min(minDepth(root->right),temp);
        }
        return temp + 1;
    }
};
```
时间复杂度：O(n)。
空间复杂度：O(n)。

迭代法。
深度优先搜索。
```C++
class Solution {
public:
    int minDepth(TreeNode* root) {
        stack<pair<TreeNode*, int>> NodeStack;
        if(root == NULL) {
            return 0;
        } else {
            NodeStack.push(pair<TreeNode *,int>(root,1));
        }
        int min_depth = INT_MAX;
        while(!NodeStack.empty()) {
            pair<TreeNode*, int> current = NodeStack.top();
            NodeStack.pop();
            root = current.first;
            int current_depth = current.second;
            if((root->left == NULL) && (root->right == NULL)) {
                min_depth = min(min_depth,current_depth);
            }
            if(root->left != NULL) {
                NodeStack.push(pair<TreeNode*,int>(root->left,current_depth + 1));
            }
            if(root->right != NULL) {
                NodeStack.push(pair<TreeNode*,int>(root->right,current_depth + 1));
            }
        }
        return min_depth;
    }
};
```
时间复杂度：O(n)。
空间复杂度：O(n)。


## N叉树的最大深度
直接递归。
```C++
class Solution {
public:
    int maxDepth(Node* root) {
        int ans = 0;
        if(root == NULL) {
            return 0;
        } else {
            for(auto child:root->children) {
                if(child) {
                    ans = max(ans,maxDepth(child));
                }
            }
        }
        return ans + 1;
    }
};
```

# 总结
总的来说，非必要情况下，直接使用递归就能很好的解决深度问题。时间复杂度和空间复杂度上都要优于迭代。
递归的方法非常好理解，注意边界条件就可以了。
迭代的情况下，重点是要同时记录节点和节点的深度，再去进行判断。