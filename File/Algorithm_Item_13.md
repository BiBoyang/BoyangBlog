# 链表刷题之旅（二）：反转链表

# 反转链表 I

反转一个单链表。
# 解答
### 迭代法
在遍历列表时，将当前节点的 next 指针改为指向前一个元素。由于节点没有引用其上一个节点，因此必须事先存储其前一个元素。在更改引用之前，还需要另一个指针来存储下一个节点。不要忘记在最后返回新的头引用！

```C++
class Solution {
public:
    ListNode* reverseList(ListNode* head) {
        ListNode *tempNode = NULL;;
        ListNode *currentNode = head;

        while(currentNode != NULL) {
            ListNode *nextNode = currentNode->next;
            currentNode->next = tempNode;
            tempNode = currentNode;
            currentNode = nextNode;
        }
        return tempNode;
    }
};
```


### 递归法
1. 使用递归函数，一直递归到链表的最后一个结点，该结点就是反转后的头结点，记作 temp .
2. 此后，每次函数在返回的过程中，让当前结点的下一个结点的 next 指针指向当前节点。
3. 同时让当前结点的 next 指针指向 NULL ，从而实现从链表尾部开始的局部反转
4. 当递归函数全部出栈后，链表反转完成。

```C++
class Solution {
public:
    ListNode* reverseList(ListNode* head) {
        if(head == NULL || head->next == NULL) return head;
        ListNode *temp = reverseList(head->next);
        head->next->next = head;
        head->next = NULL;
        return temp;
    }
};
```

# 反转链表 II
反转从位置 m 到 n 的链表。请使用一趟扫描完成反转。

说明:
1 ≤ m ≤ n ≤ 链表长度。

示例:
```C++
输入: 1->2->3->4->5->NULL, m = 2, n = 4
输出: 1->4->3->2->5->NULL
```
## 解答

迭代 地进行上述过程，即可完成问题的要求。下面来看看算法的步骤。

1. 如上所述，我们需要两个指针 dummy 和 pre。
2. dummy 指针初始化为 -1，pre 指针初始化为链表的 head。
3. 一步步地向前推进 pre 指针，dummy 指针跟随其后。
4. 如此推进两个指针，直到 pre 指针到达从链表头起的第 m 个结点。这就是我们反转链表的起始位置。
5. 然后在m-n的区间内，进行翻转



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
    ListNode* reverseBetween(ListNode* head, int m, int n) {
        ListNode *dummy = new ListNode(0);
        dummy->next = head;
        ListNode *pre = dummy;
        for(int i = 0;i<m-1;i++) {
            pre = pre->next;
        }
        ListNode *cur = pre->next;
        for(int i = m;i<n;i++){
            //使用头插法
            ListNode *temp = cur->next;
            cur->next = temp->next;
            temp->next = pre->next;
            pre->next =  temp;
        }
        return dummy->next;
    }
};

```
* 时间复杂度：O(n)
* 空间复杂度：O(1)。


