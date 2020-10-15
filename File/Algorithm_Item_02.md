# 二叉树的刷题之旅（一）：各种遍历

[144. 二叉树的前序遍历](https://leetcode-cn.com/problems/binary-tree-preorder-traversal/)       [94. 二叉树的中序遍历](https://leetcode-cn.com/problems/binary-tree-inorder-traversal/)     [145. 二叉树的后序遍历](https://leetcode-cn.com/problems/binary-tree-postorder-traversal/)      [102. 二叉树的层次遍历](https://leetcode-cn.com/problems/binary-tree-level-order-traversal/)        [107. 二叉树的层次遍历 II](https://leetcode-cn.com/problems/binary-tree-level-order-traversal-ii/)  

#  树的概念
树里的每一个节点有一个根植和一个包含所有子节点的列表。从图的观点来看，树也可视为一个拥有N 个节点和N-1 条边的一个有向无环图。

二叉树是一种更为典型的树树状结构。如它名字所描述的那样，二叉树是每个节点最多有两个子树的树结构，通常子树被称作“左子树”和“右子树”。
树节点的声明在结构上类似于双链表的声明：在声明中，一个节点就是由   **Key(关键字)** 加上两个指向 **其他节点的指针(Left和Right)** 组成的结构。
遍历二叉树，我们有四种方式。

* 先序遍历 
  对节点的处理工作是在它的诸儿子节点被处理之前进行的；首先访问根节点，然后遍历左子树，最后遍历右子树。实际上是DFS。
* 后序遍历  
  对节点的处理工作是在它的诸儿子节点被计算后进行的；先遍历左子树，然后遍历右子树，最后访问树的根节点。实际上是DFS。
* 中序遍历 
  对于节点的处理工作是在它的左儿子之后，右儿子之前；先遍历左子树，然后访问根节点，然后遍历右子树。实际上是DFS。
  
* 层序遍历 
    实际上就是广度优先遍历。

## 二叉查找树(binary search tree)
我们一般使用的树，默认为二叉查找树（Binary Search Tree），它的深度的平均值是 **O(logN)** ，最坏的情况下，深度可以达到 **N-1**。
* 注 本节非注明，二叉树代表的就是二叉查找树

二叉树成为二叉查找树最关键的性质就是，对于树中的每个节点X，它的左子树中所有关键字值小于X的关键字值，而它的右子树中所有关键字值大于X的关键字值。注意，这意味着，该树的所有的元素可以用某种统一的方式排序。
由于树的递归定义，我们通常会递归的编写操作的程序，而一般二叉树的深度是O(logN)，所以我们一般不必担心栈空间被用尽。


### AVL树 
AVL(Adelson-Velskii和Landis)树是带有平衡条件的二叉查找树。它的每个节点的左子树和右子树的高度最多差1.

## 如何遍历一棵树
如何遍历一棵树

有两种通用的遍历树的策略：

* 深度优先搜索（DFS）

在这个策略中，我们采用深度作为优先级，以便从跟开始一直到达某个确定的叶子，然后再返回根到达另一个分支。
深度优先搜索策略又可以根据根节点、左孩子和右孩子的相对顺序被细分为先序遍历，中序遍历和后序遍历。

* 宽度优先搜索（BFS）
我们按照高度顺序一层一层的访问整棵树，高层次的节点将会比低层次的节点先被访问到。

下图中的顶点按照访问的顺序编号，按照 1-2-3-4-5 的顺序来比较不同的策略。
![](https://pic.leetcode-cn.com/8e21fed563ab0c9564fb6aaba01934ee6986e0097af51e21e792bee1f4eef4d4-102.png)

# 常见例题
为了节省空间，二叉树定义统一为
```
/**
 * Definition for a binary tree node.
 * struct TreeNode {
 *     int val;
 *     TreeNode *left;
 *     TreeNode *right;
 *     TreeNode(int x) : val(x), left(NULL), right(NULL) {}
 * };
 */
```
## 二叉树的前序遍历
我们可以最方便的知道，二叉树的表达式是递归表达的。那么最简单的前序遍历也可以使用递归的方法。Top -> Bottom;Left -> Right

```C++
class Solution {
public:
    vector<int> preorderTraversal(TreeNode* root) {
        vector<int> ans;
        dfs(ans,root);
        return ans;
    }
    void dfs(vector<int>& ans,TreeNode* root) {
        if(root==NULL) return;
        ans.push_back(root->val);
        dfs(ans,root->left);
        dfs(ans,root->right);
    }
};
```

而非递归的方法就可以使用一个栈来处理。创造一个栈，当根节点不为空时，访问根节点，并入栈；若根节点的左子树不为空，则将左结点置为根节点；若为空，则取栈顶元素，并将栈顶元素的右节点置为根节点，一直到栈为空并且root为空。
```C++
class Solution {
public:
    vector<int> preorderTraversal(TreeNode* root) {
        stack<TreeNode*> nodeStack;
        vector<int> ans;
        while(root || !nodeStack.empty()) {
            //如果根节点存在，则加入栈中
            while(root) {
                nodeStack.push(root);
                ans.push_back(root->val);
                root = root->left;
            }
             //到达左节点为空的时候，直接把栈顶元素取出
            root = nodeStack.top();
            nodeStack.pop();
            //因为左节点为空，那就从右节点开始
            root=root->right;
        }
        return ans;
    }
};
```
为了更加形象的表示出递归的前序遍历中函数栈的用法，我画了一张表示栈的示意图，通过观察图，我们可以了解函数在栈的变化过程，也可以可以直接理解如何使用栈，来表示前序遍历。
二叉树：

![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/item_005.png?raw=true)

在栈中。
![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/item_006.png?raw=true)



## 二叉树的中序遍历
递归法。Left -> Node -> Right

```C++
class Solution {
public:
    vector<int> inorderTraversal(TreeNode* root) {
        vector<int> ans;
        dfs(ans,root);
        return ans;
    }
    void dfs(vector<int>& ans,TreeNode* root) {
        if(root==NULL) return;
        dfs(ans,root->left);
        ans.push_back(root->val);
        dfs(ans,root->right);
    }
};
```
迭代，还是使用栈的方法。一直顺着根节点的左结点找下去，直到某个节点的左结点为空，把这个结点的值压栈，然后访问这个节点的右节点。再以同样的方式顺着这个节点的左结点找
```C++
class Solution {
public:
    vector<int> inorderTraversal(TreeNode* root) {
        vector<int> ans;    
        stack<TreeNode*> nodeStack;
        while(root || !nodeStack.empty()) {
            while(root) {
                //左节点持续压栈
                nodeStack.push(root);
                root = root->left;
            }
            root = nodeStack.top();
            //当前无左节点，取出值
            ans.push_back(root->val);
            nodeStack.pop();
            root = root->right;
        }   
        return ans;
    }
};
```
## 二叉树的后序遍历
递归
```C++
class Solution {
public:
    vector<int> postorderTraversal(TreeNode* root) {
        vector<int> ans;
        dfs(ans,root);
        return ans;
    }
    void dfs(vector<int>& ans,TreeNode* root) {
        if(root == NULL) return;
        dfs(ans,root->left);
        dfs(ans,root->right);
        ans.push_back(root->val);
    }
};
```

迭代法。
方法一，正向。
```C++
class Solution {
public:
    vector<int> postorderTraversal(TreeNode* root) {
        if(!root) return {};
        stack<TreeNode*>nodeStack;
        vector<int> ans;
        nodeStack.push(root);
        while(!nodeStack.empty()){
            //除叶子节点外，每个节点被访问2次
            TreeNode* temp = nodeStack.top();
            root = temp;
            while(temp->left){
                //有左子树，继续往左
                temp = temp->left;
                root->left = NULL;
                root = temp;
                nodeStack.push(temp);
            }
            if(temp->right){
                //如果没有左子树，是否有右子树
                temp = temp->right;
                root->right = NULL;
                root = temp;
                nodeStack.push(temp);
            } else{
                //没有左子树也没有右子树，这个节点就是最优的
                ans.push_back(temp->val);
                nodeStack.pop();
            }
        }
        return ans;
    }
};
```
方法二：反向操作。

从根节点开始依次迭代，弹出栈顶元素输出到输出列表中，然后依次压入它的所有孩子节点，按照从上到下、从右至左的顺序依次压入栈中。

因为深度优先搜索后序遍历的顺序是从下到上、从左至右，所以需要将输出列表逆序输出。
```C++
public:
    vector<int> postorderTraversal(TreeNode* root) {
        vector<int> ans;
        if(root == NULL) {
            return ans;
        }
        stack<TreeNode*> nodeStack;
        nodeStack.push(root);
        
        while(!nodeStack.empty()) {
            TreeNode *temp = nodeStack.top();
            if(!temp->left && !temp->right) {
                nodeStack.pop();
                ans.push_back(temp->val);
            }
            if(temp->right) {
                nodeStack.push(temp->right);
                temp->right = NULL;
            }
            if(temp->left) {
                nodeStack.push(temp->left);
                temp->left = NULL;
            }    
        }
        return ans;
    }
};
```

## 二叉树的层次遍历
最简单的解法就是递归，首先确认树非空，然后调用递归函数 bfs(node, level)，参数是当前节点和节点的层次。程序过程如下：

* 输出列表称为 levels，当前最高层数就是列表的长度 len(levels)。比较访问节点所在的层次 level 和当前最高层次 len(levels) 的大小，如果前者更大就向 levels 添加一个空列表。
* 将当前节点插入到对应层的列表 levels[level] 中。
* 递归非空的孩子节点：bfs(node.left / node.right, level + 1)。

```C++
class Solution {
public·:
    vector<vector<int>> levelOrder(TreeNode* root) {
        vector<vector<int>> res;
        bfs(res,root,0);
        return res;
    }
    void bfs(vector<vector<int>>& res,TreeNode* node,int level){
        if(node == NULL) return ;
        if(level >= res.size()){
            vector<int> level_res;
            res.push_back(level_res);
        }  
        res[level].push_back(node->val);
        if(node->left) bfs(res,node->left,level+1);
        if(node->right) bfs(res,node->right,level+1);
    }
};
```

迭代法使用队列来暂时保存。
第 0 层只包含根节点 root ，算法实现如下：

* 初始化队列只包含一个节点 root 和层次编号 0 ： level = 0。
* 当队列非空的时候：
    * 在输出结果 levels 中插入一个空列表，开始当前层的算法。
    * 计算当前层有多少个元素：等于队列的长度。
    * 将这些元素从队列中弹出，并加入 levels 当前层的空列表中。
    * 将他们的孩子节点作为下一层压入队列中。
    * 进入下一层 level++。
    

```C++

class Solution {
public:
    vector<vector<int>> levelOrder(TreeNode* root) {
        vector<vector<int>> ans;
        queue<TreeNode*> nodeQueue;
        if(root) {
            nodeQueue.push(root);
        }

        while(nodeQueue.size()){
            //加入空vector
            ans.push_back(vector<int>());
            int cnt = nodeQueue.size();
            for(int i = 0;i<cnt;++i){
                TreeNode* cur = nodeQueue.front();
                nodeQueue.pop();
                int t = ans.size() - 1;
                ans[t].push_back(cur->val);
                if(cur->left) {
                    nodeQueue.push(cur->left);
                }
                if(cur->right) {
                    nodeQueue.push(cur->right);
                }
            }
        }
        return ans;
    }
};

```

## 二叉树的层次遍历 II
自底向上的层次遍历。
递归法。和正方向层次遍历一样的方法，只不过最后进行调换、
```C++
class Solution {
public:
    vector<vector<int>> levelOrderBottom(TreeNode* root) {
        vector<vector<int>> ans;
        dfs(root,0,ans);
        reverse(ans.begin(),ans.end());
        return ans;
    }
    
    void dfs(TreeNode* root,int level,vector<vector<int>>& ans){
        if(!root) return;
        if(level >= ans.size()) ans.push_back(vector<int>());
        ans[level].push_back(root->val);
        dfs(root->left,level+1,ans);
        dfs(root->right,level+1,ans);
    }   
};
```
迭代法。和从上至下的层次遍历一样，只不过最后翻转。
```C++
class Solution {
public:
    vector<vector<int>> levelOrderBottom(TreeNode* root) {
        vector<vector<int>> ans;
        queue<TreeNode*> nodeQueue;
        if(root) {
            nodeQueue.push(root);
        }

        while(nodeQueue.size()){
            //加入空vector
            ans.push_back(vector<int>());
            int cnt = nodeQueue.size();
            for(int i = 0;i<cnt;++i){
                TreeNode* cur = nodeQueue.front();
                nodeQueue.pop();
                int t = ans.size() - 1;
                ans[t].push_back(cur->val);
                if(cur->left) {
                    nodeQueue.push(cur->left);
                }
                if(cur->right) {
                    nodeQueue.push(cur->right);
                }
            }
        }
        reverse(ans.begin(), ans.end());
        return ans;
    }
};
```

# 总结
我们其实可以发现，对于递归的求遍历，其实有一套通式。
```C++
void dfs(vector<int>& ans,TreeNode* root) {
        if(root == NULL) return;
            //ans.push_back(root->val); 前序遍历
        dfs(ans,root->left);
            //ans.push_back(root->val); 中序遍历
        dfs(ans,root->right);
            //ans.push_back(root->val); 后序遍历
    }

```

事实上，对于二叉树的算法题，经常要使用到递归；而如果不是用递归，使用迭代，也有自己的模板。

在先序遍历、中序遍历中，是十分相似的。一个是根->左->右,一个是左->右->根。可以发现，主要是在对根的处理上不同。

先序，是创造一个栈，当根节点不为空时，访问根节点，并入栈，**在这里将值加入 res** ；若根节点的左子树不为空，则将左结点置为根节点；若为空，则取栈顶元素，并将栈顶元素的右节点置为根节点，一直到栈为空并且root为空。
中序，是创造一个栈，当根节点不为空时，访问根节点并入栈；若根节点的左子树不为空，则将左节点置为根节点；若空，则取栈顶元素，并**在这里加入res**，然后将栈顶元素的有节点置为根节点，一直到栈为空，并且root为空。

简单一点：**先序先访问值后入栈，中序先出栈后访问值。** 先序序列就是入栈顺序，中序序列就是出栈顺序。

理解清了这个规律的内涵，就是说：
1. 只要按照前序遍历的顺序入栈，出栈肯定是符合中序遍历的。
2. 一个前序遍历对应的所有二叉树，每一棵都必定对应一个出栈序列。


但是后序遍历情况则不同。后序遍历，实际上是带有破坏性质的遍历方法。

在方法二：反向操作 中，我实际上破坏的其中一部分的结构，不然会有重复添加的情况。

这道题最好是画一遍，自然了解。
```C++
    
nodeStack.push(root);
while(!nodeStack.empty()) {
    TreeNode *temp = nodeStack.top();
    if(!temp->left && !temp->right) {
        nodeStack.pop();
        ans.push_back(temp->val);
    }
    if(temp->right) {
        nodeStack.push(temp->right);
        //此处最重要，在添加到栈了之后，要将其左右节点置为0，即左右节点弹出之后，本节点直接符合弹出规则
        temp->right = NULL;
    }
    if(temp->left) {
        nodeStack.push(temp->left);
        //此处最重要，在添加到栈了之后，要将其左右节点置为0，即左右节点弹出之后，本节点直接符合弹出规则
        temp->left = NULL;
    }    
}
```
