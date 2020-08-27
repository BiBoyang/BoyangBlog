# 螺旋矩阵
#### 题目链接
[螺旋矩阵 I](https://leetcode-cn.com/problems/spiral-matrix/)<br>[螺旋矩阵 II](https://leetcode-cn.com/problems/spiral-matrix-ii/)<br>[螺旋矩阵 III](https://leetcode-cn.com/problems/spiral-matrix-iii/)

# 正文

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

对于这种算法难度不高、但是边界条件比较突出的题，我们可以在写的时候，先将边界条件写出。比如说：
```C++
while (true) {
    //从左上往右上
    //如果上面大于下面，则结束
    
    //从右上往右下
    //如果右边小于左边，则结束
    
    //从右下往左下
    //如果下边小于上面，则结束
 
    //从左下往左上
    //如果左边超过了右边，则结束
}
```
那么，我们就可以在每一阶段当中写出对应的代码。


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
            //从左上往右上
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

我们遍历一个二维数组的，接下来，给定一个数，如何去构建一个二维数组。即：有一个数 n，生成一个包含 1 到 n * n 所有元素，且元素按顺时针顺序螺旋排列的正方形矩阵。

对于此题，我们可以设定初始值为 num = 1，目标值为 target = n * n。在循环的过程中，每次增加 num 的值，直到等于 target。

遍历的过程则和上面非常类似，每次执行过一条边之后，将其对应的边界加一或者减一。
```C++
while(num <= target) {
    //左上--右上
    up++;
    //右上--右下
    right--;
    //右下--左下
    down--;
    //左下--左上
    left++;
}
```

全部代码如下：
```C++
class Solution {
public:
    vector<vector<int>> generateMatrix(int n) {
        if(n == 0)return {};

        vector<vector<int>> res(n,vector<int>(n,0));
        int up = 0,down = n-1,left = 0,right = n-1,num = 1,target = n * n;

        while(num <= target) {
            //左上--右上
            for(int i = left;i<=right;i++) {
                res[up][i] = num++;
            }
            up++;
            //右上--右下
            for(int i = up;i<= down;i++) {
                res[i][right] = num++;
            } 
            right--;
            //右下--左下
            for(int i = right;i>=left;i--){
                res[down][i] = num++;
            }
            down--;
            //左下--左上
            for(int i = down;i>=up;i--) {
                res[i][left] = num++;
            }
            left++;
        }
        return res;
    }
};
```

其实可以发现，上面两道题，完全是一种思路的两种实现，归根结底，其实是对边界的考察。接下来，有一道对于边界更加严苛的变化来了。

## 限定区域的随机起点的螺旋

在 R 行 C 列的矩阵上，我们从 (r0, c0) 面朝东面开始

这里，网格的西北角位于第一行第一列，网格的东南角位于最后一行最后一列。

现在，我们以顺时针按螺旋状行走，访问此网格中的每个位置。

每当我们移动到网格的边界之外时，我们会继续在网格之外行走（但稍后可能会返回到网格边界）。

最终，我们到过网格的所有 R * C 个空间。

按照访问顺序返回表示网格位置的坐标列表。

看题有点懵，那么拿图来看。

输入：R = 5, C = 6, r0 = 1, c0 = 4
输出：
```
[[1,4],[1,5],[2,5],[2,4],[2,3],[1,3],[0,3],[0,4],[0,5],[3,5],[3,4],[3,3],[3,2],[2,2],[1,2],[0,2],[4,5],[4,4],[4,3],[4,2],[4,1],[3,1],[2,1],[1,1],[0,1],[4,0],[3,0],[2,0],[1,0],[0,0]]
```
![](https://github.com/BiBoyang/Algorithm_Rex/blob/master/Image/item_004.png?raw=true)

限定条件多多啊，那么该如何解决呢？

观察上图，我们发现，遍历的时候，实际上分为两个状态：
* 在范围内
* 不范围内

两者合并在一起，才算得上完整的螺旋，和上面的题差不多。那么，我们其实可以设定一个限制条件来进行筛选。

```C++
bool isInArea(int a,int b,int r,int c) {
        if(a >= 0 && b >= 0 && a < r && b < c) {
            return true;
        } else {
            return false;
        }
    }
```
通过它，我们就可以判断这个坐标点，**是否在范围内**。

然后，照着上面的思想，写出边界条件：
```C++
int total = 1;//走过的范围内的区域
int step = 1;//每一轮移动的步长
while(total < R * C) {
    
    //向东走
      c0++;
    total++；
    //向南走
    r0++;
    total++
    step++；
    //向西走
    c0--；
    total++；
    //向北走
    r0--；
    total++；
    step++;
```
完整代码如下：
```C++
class Solution {
public:
    bool isInArea(int a,int b,int r,int c) {
        if(a >= 0 && b >= 0 && a < r && b < c) {
            return true;
        } else {
            return false;
        }
    }
    vector<vector<int>> spiralMatrixIII(int R, int C, int r0, int c0) {
        int total = 1;
        vector<vector<int>> res;
        vector<int> temp(2);
        temp[0] = r0;
        temp[1] = c0;
        res.push_back(temp);

        int step = 1;//每一轮移动的步长

        while(total < R * C) {
            
            //向东走
            int n = 1;
            while(n <= step) {
                c0++;
                if(isInArea(r0, c0, R, C)){
                    temp[0] = r0;
                    temp[1] = c0;
                    res.push_back(temp);
                    total++;
                }
                n++;
            }

            //向南走
            n = 1;
            while(n <= step) {
                r0++;
                if(isInArea(r0, c0, R, C)){
                    temp[0] = r0;
                    temp[1] = c0;
                    res.push_back(temp);
                    total++;
                }
                n++;
            }

            step++;
            //向西走
            n = 1;
            while(n <= step) {
                c0--;
                if(isInArea(r0, c0, R, C)){
                    temp[0] = r0;
                    temp[1] = c0;
                    res.push_back(temp);
                    total++;
                }
                n++;
            }

            //向北走
            n = 1;
            while(n <= step) {
                r0--;
                if(isInArea(r0, c0, R, C)){
                    temp[0] = r0;
                    temp[1] = c0;
                    res.push_back(temp);
                    total++;
                }
                n++;
            }
            step++;
        }
        return res;
    }
};
```