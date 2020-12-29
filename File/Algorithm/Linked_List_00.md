# 链表刷题之旅（零）：基础
  
* 链表是一种物理存储结构上非连续，非顺序的存储结构，数据元素的逻辑顺序是通过链表中的指针链接次序实现的。
  
* 实现起来很简单，每一个结构均含有表元素和指向包含该元素后继元的结构的指针（Next 指针）。 这种也叫单链表。
 
* 如果每一个结构均含有表元素和指向包含该元素前继元的结构的指针以及后继元的结构的指针，这叫叫做双链表。
  
* 我们一般接触到的链表都是单链表。
  
  
 
## 查找、插入、删除

查找很简单：直接遍历，时间复杂度是：O(n)，即使是知道了 index。

链表的插入或删除不需要移动其他元素，时间复杂度是O(1)；但是如果中间有查找动作，那么时间复杂度还是：O(n)。


# Tips
* ‘=’左边的 `->next` 一般指的是该节点中存的 next（链表节点包括两个部分组成，一个是 val，一个是 next 用于指向下一个部分的），而右边的 `->next` 一般来讲是指的指向的某个具体节点


# 经典双指针模板

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

