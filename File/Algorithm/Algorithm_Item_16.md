# 链表刷题之旅（五）：两数相加

给出两个 非空 的链表用来表示两个非负的整数。其中，它们各自的位数是按照 逆序 的方式存储的，并且它们的每个节点只能存储 一位 数字。

如果，我们将这两个数相加起来，则会返回一个新的链表来表示它们的和。

比如说：
```C++
输入：(2 -> 4 -> 3) + (5 -> 6 -> 4)
输出：7 -> 0 -> 8
原因：342 + 465 = 807
```

我画一个图，更加清晰的展示这个过程。

直接接触到这道题，最好的办法就是分割开来。
1. 先初始化一个空节点，作为开头；
2. 设计一个 进位数 isTenExc，初始化为 false；
3. 分别遍历第一个节点，加到 sum 上；
4. 判断上一轮是否进位，如果进位，再 sum + 1；
5. 判断此轮 sum 是否大于 10，如果大于，则标记进位数 isTenExc 为 true；
6. 然后依次在新节点后延续下去；
7. 在整个结束之后，再判断进位数是否大于 10，如果大于 10，则在尾部继续加一个 1 ；


```C++
class Solution {
public:
    ListNode* addTwoNumbers(ListNode* l1, ListNode* l2) {
        ListNode *temp = new ListNode(0);
        ListNode *res = temp;
        int sum;
        bool isTenExc = false;
        while(l1 || l2) {
            sum = 0;
            if(l1) {
                sum += l1->val;
                l1 = l1->next;
            }
            if(l2) {
                sum += l2->val;
                l2 = l2->next;
            }
            if(isTenExc) {
                sum += 1;
            }
            if(sum >= 10) {
                sum = sum-10;
                isTenExc = true;
            } else {
                isTenExc = false;
            }
            temp->next = new ListNode(sum);
            temp = temp->next;
        }
        if(isTenExc){
            temp->next = new ListNode(1);
        }
        return res->next;
    }
};
```
* 时间复杂度：O(max(m,n))
* 空间复杂度：O(max(m,n))

如此看起来，其实这种还算简单，比较难的地方在于把握进位数的轮次，只能让上一轮的进位数干涉到此轮的 sum 数字。

相比于反向链表相加，正向链表相加则麻烦了一些。

```C++
输入：(7 -> 2 -> 4 -> 3) + (5 -> 6 -> 4)
输出：7 -> 8 -> 0 -> 7
```

这道题最难的地方在于，链表中数位的顺序于正常加法的顺序正好是是相反的。说到**相反的**，我们第一时间就想到了**栈**。将所有的数字压入栈中，然后在依次取出。

```C++
class Solution {
public:
    ListNode* addTwoNumbers(ListNode* l1, ListNode* l2) {
        stack<int> s1,s2;
        while(l1) {
            s1.push(l1->val);
            l1 = l1->next;
        }
        while(l2) {
            s2.push(l2->val);
            l2 = l2->next;
        }
        bool isTen  = false;
        ListNode *res = NULL;
        int sum;
        while(!s1.empty() || !s2.empty()) {
            sum = 0; 
            if(!s1.empty()) {
                sum += s1.top();
                s1.pop();
                
            } 
            if(!s2.empty()) {
                sum += s2.top();
                s2.pop();
            } 
            
            if(isTen) {
                sum =  sum + 1;
            } 

            if(sum >= 10) {
                sum = sum- 10;
                isTen = true;
            } else {
                isTen = false;
            }
            ListNode *temp = new ListNode(sum);
            temp->next = res;
            res = temp ;
        }
        if(isTen) {
            ListNode *temp = new ListNode(1);
            temp->next = res;
            res = temp ;
        } 
        return res;
    }
};
```
* 时间复杂度：O(max(m,n))
* 空间复杂度：O(m+n))