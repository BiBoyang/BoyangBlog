# 链表刷题之旅（六）：合并有序链表

合并链表是一个很考虑思维的题。

先从合并两个链表来看。

## 合并两个有序链表

做这个题，最开始还是比较经典的，先判空。
```C++
if (l1 == NULL) return l2;
if (l2 == NULL) return l1;
```

使用递归的话，非常容易理解。我们要判断 l1 和 l2 哪一个的头元素更小，然后递归地决定下一个加入到结果里的值。当两个链表都是空的时候，过程终止。

代码就如下所示。

```C++
class Solution {
public:
    ListNode* mergeTwoLists(ListNode* l1, ListNode* l2) {
        if (l1 == NULL)
            return l2;
        if (l2 == NULL) 
            return l1;
        //归并排序的第三者
        ListNode *res = NULL;
        
        if(l1->val < l2->val) {
            res = l1;
            res->next = mergeTwoLists(l1->next,l2);  
        } else {
            res = l2;
            res->next = mergeTwoLists(l2->next,l1);
        }
        return res;
    }
};
```

* 时间复杂度：O(m+n)
* 空间复杂度：O(m+n)。调用 mergeTwoLists 退出时 l1 和 l2 中每个元素都一定已经被遍历过了，所以 n+m个栈帧会消耗 O(n+m) 的空间。

那么，如果不想使用递归的话，也可新建一个链表，然后依次判断两个链表的大小，依次往下排列下去；一旦一个链表排列结束，就可以直接在新建的链表后面接上另外一个链表。

```C++
class Solution {
public:
    ListNode* mergeTwoLists(ListNode* l1, ListNode* l2) {
        ListNode *res = new ListNode(0);
        ListNode *temp = res;
        while(l1 != NULL && l2 != NULL) {
            if(l1->val < l2->val) {
                temp->next = l1;
                l1 = l1->next;
            } else {
                temp->next = l2;
                l2 = l2->next;
            }
            temp = temp->next;
        }
        temp->next = l1 == NULL ? l2 : l1;
        return res->next;
    }
};
```

* 时间复杂度：O(m+n)
* 空间复杂度：O(1)


好了，合并两个排序链表实际上很简单，那么合并多个排序链表呢？

## 合并 k 个排序链表

先从最简单的方向思考，我们可以依次的合并链表，直接使用上面的代码。先将最靠前的两个链表合并，然后将合并的后的链表依次向后逐一进行合并。
```C++
/**
 * Definition for singly-linked list.
 * struct ListNode {
 *     int val;
 *     ListNode *next;
 *     ListNode(int x) : val(x), next(NULL) {}
 * };
 */
class Solution {
public:
    ListNode* mergeKLists(vector<ListNode*>& lists) {
        ListNode* head = new ListNode(0); 
        ListNode* point = head; 
        for(int i=0; i<lists.size(); i++) {
            point->next = mergeTwoLists(point->next,lists[i]); 
        }
        return head->next;

    }
private:
    ListNode* mergeTwoLists(ListNode* l1, ListNode* l2) {
        ListNode *res = new ListNode(0);
        ListNode *temp = res;
        while(l1 != NULL && l2 != NULL) {
            if(l1->val < l2->val) {
                temp->next = l1;
                l1 = l1->next;
            } else {
                temp->next = l2;
                l2 = l2->next;
            }
            temp = temp->next;
        }
        temp->next = l1 == NULL ? l2 : l1;
        return res->next;
    }
};

```

空间复杂度是O(1)。而时间复杂度是需要计算，第 i 次合并之后，res 链表的长度是 i x n，合并的时间代价就是O(i x n)，所以可以计算得出，总的时间复杂度是O(k ^ 2 * n)。

当然，这么依次合并，显然可以是用二分法进行优化。我们可以在中间再加一层，进行二分。

```C++

class Solution {
public:
    ListNode* mergeKLists(vector<ListNode*>& lists) {
        return merge(lists, 0, lists.size() - 1);
    }
private:
    ListNode* merge(vector <ListNode*> &lists, int l, int r) {
        if (l == r) return lists[l];
        if (l > r) return nullptr;
        int mid = (l + r) >> 1;
        return mergeTwoLists(merge(lists, l, mid), merge(lists, mid + 1, r));
    }

    ListNode* mergeTwoLists(ListNode* l1, ListNode* l2) {
        ListNode *res = new ListNode(0);
        ListNode *temp = res;
        while(l1 != NULL && l2 != NULL) {
            if(l1->val < l2->val) {
                temp->next = l1;
                l1 = l1->next;
            } else {
                temp->next = l2;
                l2 = l2->next;
            }
            temp = temp->next;
        }
        temp->next = l1 == NULL ? l2 : l1;
        return res->next;
    }
};

```
因为使用递归的关系。空间复杂度是O(logk)。而时间复杂度则不是 O(k * k * n)了，而是O(kn * logk)。

### 堆排序

这里其实还有一种方法，是直接使用堆的特性（优先队列），即所有加入到堆中的数字，会自动进行排序。在 C++ 中使用堆，可以直接使用 priority_queue。

```C++
class Solution {
public:
    ListNode* mergeKLists(vector<ListNode*>& lists) {
        //自定义排序内容
        auto cmp = [](ListNode *a, ListNode *b) {
            return a->val > b->val;
        };
        //建立堆
        priority_queue<ListNode*, vector<ListNode*>, decltype(cmp)> heap(cmp);
        //遍历加堆
        for (auto node : lists) {
            if(node) { 
                heap.push(node);
            }
        }
        ListNode *dummy = new ListNode(0), *cur = dummy;
        //从堆中取出
        while (!heap.empty()) {
            auto t = heap.top();
            heap.pop();
            cur->next = t;
            cur = cur->next;
            if (cur->next) {
                heap.push(cur->next);
            }
        }
        return dummy->next;        
    }
};

```

* 时间复杂度： O(Nlog⁡k) ，其中 k 是链表的数目。    
        弹出操作时，比较操作的代价会被优化到 O(log⁡k) 。同时，找到最小值节点的时间开销仅仅为 O(1)。
        最后的链表中总共有 N 个节点。
* 空间复杂度：O(n)。 创造一个新的链表需要 O(n) 的开销。








