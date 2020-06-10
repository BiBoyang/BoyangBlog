# 螺旋矩阵
#### 题目链接
[螺旋矩阵 I](https://leetcode-cn.com/problems/spiral-matrix/)    [螺旋矩阵 II](https://leetcode-cn.com/problems/spiral-matrix-ii/)    [螺旋矩阵 III](https://leetcode-cn.com/problems/spiral-matrix-iii/)

# 解答

螺旋矩阵是几道题是很有趣的题，考察程序员对于边界的处理和敏感度。 

思路很好解决，但是如果要真正的写出无 bug 的代码实际上还是有点难度————这个难度在于边界的处理，我最开始解决问题的时候，伪代码一下写了出来，但是真正运行没问题的代码却写了很长时间。尤其是第三题，简直是一种折磨。

我们先开始看，第一题。

给定一个包含 m x n 个元素的矩阵（m 行, n 列），请按照顺时针螺旋顺序，返回矩阵中的所有元素。

明确一下思路，我们是要螺旋的顺时针的访问元素。
![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/luoxuan_01.png?raw=true)

这个图看起来还是有点迷糊，我们把每个点的坐标画出来，就更加明白了。
![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/luoxuan_02.png?raw=true)

首先，我们一定要明确每一步的上下左右边界。

然后首先在第一行向右开始遍历，到了最右之后，就从上而下，这个时候我们要把起始高度变为这一行的**高度**；依次类推。

注意，我们的边界条件有四种
1. 从上边界开始的边界 **up** 大于下边界 **down**；
2. 从右边界开始的边界 **right** 小于左边界 **left**；
3. 从下边界开始的边界 **down** 小于上边界 **up**；
4. 从左边界开始的边界 **left** 大于右边界 **right**；


```C++
class Solution {
public:
    vector<int> spiralOrder(vector<vector<int>>& matrix) {
        if (matrix.empty() || matrix[0].empty()) {
            return {};
        }
        int height = matrix.size(), width = matrix[0].size();
       
        vector<int> res;
        
        int up = 0, down = height - 1, left = 0, right = width - 1;
        
        while (true) {
            //从左往右
            for(int i = left;i <= right;i++) {
               res.push_back(matrix[up][i]);
            }
            //如果上面大于下面，则结束
            up++;
            if(up > down)break;
            
            //从右上往右下
            for(int i = up;i <= down;i++) {
                res.push_back(matrix[i][right]);
            }
            //如果右边小于左边，则结束
            right--;
            if(right < left) break;
            
            //从右下往左下
            for(int i = right;i >= left;i--) {
                res.push_back(matrix[down][i]);
            }
            //如果下边小于上面，则结束
            down--;
            if(down < up) break;
            
            //从左下往左上
            for(int i = down;i >= up;i--) {
                res.push_back(matrix[i][left]);
            }
            //如果左边超过了右边，则结束
            left++;
            if(left > right)break;
        }
        return res;
    }
};
```



