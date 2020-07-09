# 链表刷题之旅（三）:移除链表元素

（19）删除链表倒数第N个节点✅
（82）删除排序链表中的重复元素II✅
（83）删除排序链表中的重复元素✅
（203）移除链表元素✅

# 移除链表元素
删除链表中等于给定值 val 的所有节点。
示例:
```C++
输入: 1->2->6->3->4->5->6, val = 6
输出: 1->2->3->4->5
```

# 解答

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
    ListNode* removeElements(ListNode* head, int val) {
        ListNode *dummy = new ListNode(0);
        dummy->next = head;
        ListNode *cur = dummy;
        while(cur->next) {
            if(cur->next->val == val) {
                cur->next = cur->next->next;
            } else {
                cur = cur->next;
            }
        }
        return dummy->next;
    }
};
```
* 时间复杂度：O(n)
* 空间复杂度：O(1)

# 删除倒数第 N 个节点
给定一个链表，删除链表的倒数第 n 个节点，并且返回链表的头结点。

示例：
```C++
给定一个链表: 1->2->3->4->5, 和 n = 2.

当删除了倒数第二个节点后，链表变为 1->2->3->5.
```

# 解答
上述算法可以优化为只使用一次遍历。我们可以使用两个指针而不是一个指针。第一个指针从列表的开头向前移动 n+1步，而第二个指针将从列表的开头出发。现在，这两个指针被 n 个结点分开。我们通过同时移动两个指针向前来保持这个恒定的间隔，直到第一个指针到达最后一个结点。此时第二个指针将指向从最后一个结点数起的第 n 个结点。我们重新链接第二个指针所引用的结点的 next 指针指向该结点的下下个结点。

```C++
class Solution {
public:
    ListNode* removeNthFromEnd(ListNode* head, int n) {
        
        ListNode *dummy = new ListNode(0);
        dummy->next = head;        
        ListNode *slow = dummy,*fast = dummy;
        
        //这段要好好理解
        for(int i= 0;i <= n;i++) {
            fast = fast->next;
        }
        
        while(fast) {
            fast = fast->next;
            slow = slow->next;
        }
        slow->next = slow->next->next;
        return dummy->next;
    }
};
```

* 时间复杂度：O(n)
* 空间复杂度：O(1)。


# 删除排序链表中的重复元素
给定一个排序链表，删除所有重复的元素，使得每个元素只出现一次。
## 解答
```C++
class Solution {
public:
    ListNode* deleteDuplicates(ListNode* head) {
        ListNode *cur = head;
        while(cur && cur->next) {
            if(cur->next->val == cur->val) {
                cur->next = cur->next->next;
            } else {
                cur = cur->next;
            }
        }
        return head;
    }
};

```

# 删除排序链表中的重复元素 II
给定一个排序链表，删除所有含有重复数字的节点，只保留原始链表中 没有重复出现 的数字。
## 解答
### 递归法
```C++
class Solution {
public:
    ListNode* deleteDuplicates(ListNode* head) {
        if(head ==NULL) return head;
        if(head->next && head->val == head->next->val) {
            while(head && head->next && head->val == head->next->val) {
                head = head->next;
            }
            //这里直接跳过，走next
            return deleteDuplicates(head->next);
        } else {
            head->next = deleteDuplicates(head->next);
        }       
        return head;
    }
};
```
### 双指针法
```C++
class Solution {
public:
    ListNode* deleteDuplicates(ListNode* head) {
        //快慢指针
        if(head == NULL ) return head;
        ListNode *dummy = new ListNode(0);
        dummy->next = head;
        ListNode *slow = dummy;
        ListNode *fast = dummy->next;
        while(fast) {
            if(fast->next && fast->val == fast->next->val )  {
                int temp = fast->val;
                while(fast && temp == fast->val) {
                    fast = fast->next;
                }
            } else {
                slow->next = fast;
                slow = fast;
                fast = fast->next;
            }

            slow->next = fast;
        
        }
        return dummy->next;
    }
};
```

