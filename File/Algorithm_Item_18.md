# 哈希表刷题之旅（一）：设计哈希表

# hash ABC
hash 是一种用于处理查找时非常高效的数据结构。时间复杂度一般情况下可以直接认为是 O(1)。
散列技术是在记录的存储位置和它的关键字之间确立一个对应关系 *f*，使得关键字 `key` 对应的存储位置 `f(key)`。函数 `f` 被称之为哈希函数(hash function)，使用哈希技术将数据存储在一块连续的地址区域中，该连续的存储空间我们称之为散列表，也就是哈希表（hash table）。
我们在存储的时候，是用过哈希函数计算得到哈希地址，并按照哈希地址存储该记录；查找的时候，通过通过同样的哈希函数计算记录的哈希地址，并按照地址访问该记录。
如果两个值在一个地址，就是 **冲突（collision）**。
解决冲突的方法主要是下边几种

> * 开放定址法
> * 再散列函数法
> * 链地址法（拉链法）
> * 公共溢出区法

假如在理想的状态下完全没有冲突，哈希表是所有查找中性能最高的，但是在极端情况下（全是一个地址），就是一个链表（链地址法）了。

测量性能我们主要是以下边几个标准：
> * 散列表是否均匀
> * 处理冲突的方式
> * 散列表的负载因子
 
 负载因子 = 表中记录个数 / 散列表的长度
 
* 优点：在理想的状态下，查找、插入、删除操作的效率是最高的，是 O(1)，树的相同操作也是需要 O(n) 的时间级的。
* 缺点：要时刻注意散列表的负载因子，准备扩容；要在面对真实的场景的时候，采用正确的冲突处理方法。

# 设计哈希集合

先做一个这样的概念题，如何不使用内建的哈希函数，自己设计一个哈希集合？

简单的实现以下三个函数：
* add(value)：向哈希集合中插入一个值。
* contains(value) ：返回哈希集合中是否存在这个值。
* remove(value)：将给定值从哈希集合中删除。如果哈希集合中没有这个值，什么也不做。

我们可以直接了当的使用拉链法，也就是在一个桶子那里使用链表来表示哈希值相同的元素。

我们先创建一个链表的数组，桶子设置为 10007（10000 以上最小的质数），
```C++
vector<ListNode*> hashArray;
int n = 10007;
```

然后在添加的时候，我们用 key 去和 n 取余，得到 index。然后判断其是否已经在数组中，如果不在，则创建一个链表加入；如果在，则创建一个链表加入到后面。
```C++
void add(int key) {
    int index = key % n;
    if (hashArray[index] == nullptr) {
        hashArray[index] = new ListNode(key);
    } else {
        ListNode *node = hashArray[index];
        if (node->val == key) return;
        while (node->next != NULL) {
            if (node->next->val == key) return;
            node = node->next;
        }
        node->next = new ListNode(key);
    }
}
```

删除的时候则用逆向的思路：
```C++
void remove(int key) {
    int index = key % n;
    if (hashArray[index] == nullptr) return;
    if (hashArray[index]->val == key) {
        hashArray[index] = hashArray[index]->next;
    } else {
        ListNode* pre = hashArray[index];
        ListNode* node = pre->next;
        while (node != nullptr) {
            if (node->val == key) {
                pre->next = node->next;
                return;
            }
            pre = node;
            node = node->next;
        }
    }
}
```

判断是否存在，也就相对最简单了，计算出哈希值之后，直接在对应的桶子里去找：
```C++
bool contains(int key) {
    int index = key % n;
    ListNode* node = hashArray[index];
    while (node != nullptr) {
        if (node->val == key) return true;
        node = node->next;
    }
    return false;
}
```


## C++ 中哈希表的用法
```C++
#include <unordered_set>               

int main() {
    // 1. 初始化哈希集
    unordered_set<int> hashset;   
    // 2. 新增键
    hashset.insert(3);
    hashset.insert(2);
    hashset.insert(1);
    // 3. 删除键
    hashset.erase(2);
    // 4. 查询键是否包含在哈希集合中
    if (hashset.count(2) <= 0) {
        cout << "键 2 不在哈希集合中" << endl;
    }
    // 5. 哈希集合的大小
    cout << "哈希集合的大小为: " << hashset.size() << endl; 
    // 6. 遍历哈希集合
    for (auto it = hashset.begin(); it != hashset.end(); ++it) {
        cout << (*it) << " ";
    }
    cout << "在哈希集合中" << endl;
    // 7. 清空哈希集合
    hashset.clear();
    // 8. 查看哈希集合是否为空
    if (hashset.empty()) {
        cout << "哈希集合为空！" << endl;
    }
}

```