# 链表刷题之旅（一）： 双指针
  
  链表是一种物理存储结构上非连续，非顺序的存储结构，数据元素的逻辑顺序是通过链表中的指针链接次序实现的。
  
  实现起来很简单，每一个结构均含有表元素和指向包含该元素后继元的结构的指针（Next 指针）。 这种也叫单链表。
  
  如果每一个结构均含有表元素和指向包含该元素前继元的结构的指针以及后继元的结构的指针，这叫叫做双链表。
  
  我们一般接触到的链表都是单链表。
  
  
 
# 查找、插入、删除

查找很简单：直接遍历，时间复杂度是：O(n)，即使是知道了 index。

链表的插入或删除不需要移动其他元素，时间复杂度是O(1)；但是如果中间有查找动作，那么时间复杂度还是：O(n)。


# Tips
* ‘=’左边的 ->next 一般指的是该节点中存的 next（链表节点包括两个部分组成，一个是val，一个是next用于指向下一个部分的），而右边的 ->next 一般来讲是指的指向的某个具体节点


# 经典双指针

## 模板
```C++
// Initialize slow & fast pointers
ListNode* slow = head;
ListNode* fast = head;
/**
 * Change this condition to fit specific problem.
 * Attention: remember to avoid null-pointer error
 **/
while (slow && fast && fast->next) {
    slow = slow->next;          // move slow pointer one step each time
    fast = fast->next->next;    // move fast pointer two steps each time
    if (slow == fast) {         // change this condition to fit specific problem
        return true;
    }
}
return false;   // change return value to fit specific problem
```

## 环形链表 I
给定一个链表，判断链表中是否有环。

为了表示给定链表中的环，我们使用整数 pos 来表示链表尾连接到链表中的位置（索引从 0 开始）。 如果 pos 是 -1，则在该链表中没有环。

值得注意的是：
1. 在调用 next 字段之前，始终检查节点是否为空。

获取空节点的下一个节点将导致空指针错误。例如，在我们运行 fast = fast.next.next 之前，需要检查 fast 和 fast.next 不为空。

2. 仔细定义循环的结束条件。

### 解答
使用快慢指针。
```C++
class Solution {
public:
    bool hasCycle(ListNode *head) {
        ListNode *slow = head;
        ListNode *fast = head;
        while(fast && fast->next) {
            slow = slow->next;
            fast = fast->next->next;
            if(slow == fast) {
                return true;
            }
        }
        return false;
    }
};
```

* 时间复杂度：O(n)。
        假如有环，快指针将会首先到达尾部，其时间取决于列表的长度，也就是 O(n)。
        假如无环，时间复杂度会是O(N+K)。K 是环形长度。
* 空间复杂度：O(1)。


## 环形链表 II
给定一个链表，返回链表开始入环的第一个节点。 如果链表无环，则返回 null。

为了表示给定链表中的环，我们使用整数 pos 来表示链表尾连接到链表中的位置（索引从 0 开始）。 如果 pos 是 -1，则在该链表中没有环。

说明：不允许修改给定的链表。

### 解答
假如没有相遇，则直接输出 NULL。

假如有相遇，说明肯定有环。这时氛围两个阶段：

**第一阶段：**

* 设链表共有 a+b个节点，其中 链表头部到链表入口 有 a 个节点（不计链表入口节点）， 链表环 有 b 个节点；设两指针分别走了 f，s 步，则有：
    1. fast 走的步数是slow步数的 2 倍，即 f=2s；（解析： fast 每轮走 2 步）
    2. fast 比 slow 多走了 n 个环的长度，即 f=s+nb ；（解析： 双指针都走过 a 步，然后在环内绕圈直到重合，重合时 fast 比 slow 多走环的长度整数倍）；

* 以上两式相减得：f=2nb，s = nb，即 fast和slow 指针分别走了 2n，n 个 环的周长 （注意：n 是未知数，不同链表的情况不同）。

**第二阶段：**

给定阶段 1 找到的相遇点，阶段 2 将找到环的入口。首先我们初始化额外的两个指针： left ，指向链表的头， right 指向相遇点。然后，我们每次将它们往前移动一步，直到它们相遇，它们相遇的点就是环的入口，返回这个节点。


```C++
class Solution {
public:
    ListNode *detectCycle(ListNode *head) {
        ListNode *slow = head;
        ListNode *fast = head;

        while(true) {
            if( fast == NULL || fast->next == NULL) {
                return NULL;
            }
            slow = slow->next;
            fast = fast->next->next;
            if(slow == fast) break;
        }
        ListNode *left = head;
        ListNode *right = slow;
        while(left != right) {
            left = left->next;
            right = right->next;
        }
        return right;
    }
};
```

* 时间复杂度：O(n)
* 空间复杂度：O(1)。


## 相交链表
编写一个程序，找到两个单链表相交的起始节点。

### 解答
此题有两种解法

#### 哈希表

```C++
class Solution {
public:
    ListNode *getIntersectionNode(ListNode *headA, ListNode *headB) {
        unordered_set<ListNode *> s;
        ListNode *curA = headA;
        while(curA) {
            s.insert(curA);
            curA = curA->next;
        }
        ListNode *curB = headB;
        while(curB) {
            if(s.find(curB) != s.end()) {
                return curB;
            }
            curB = curB->next;
        }
        return NULL;
    }
};
```
* 时间复杂度：O(m+n)。
* 空间复杂度：O(m)或者O(n)。

#### 双指针


1. 指针 pA 指向 A 链表，指针 pB 指向 B 链表，依次往后遍历
2. 如果 pA 到了末尾，则 pA = headB 继续遍历
3. 如果 pB 到了末尾，则 pB = headA 继续遍历
4. 比较长的链表指针指向较短链表head时，长度差就消除了

```C++
class Solution {
public:
    ListNode *getIntersectionNode(ListNode *headA, ListNode *headB) {
        ListNode *a = headA;
        ListNode *b = headB;
        while(a != b) {
            if(a) {
                a = a->next;
            } else {
                a = headB;
            }
            if(b) {
                b = b->next;
            } else {
                b = headA;
            }
        }
        return a;
    }
};
```
* 时间复杂度：O(m+n)。
* 空间复杂度：O(1)。


