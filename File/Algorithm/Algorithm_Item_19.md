# 哈希表刷题之旅（二）

对于哈希表来说，最常见的题目就是查找重复元素了。

对于这种题，最简单的办法就是遍历该数组，让后将值插入到哈希表中，如果此值已经存在于哈希表中，则表明发生了重复。

代码模板如下
```C++
bool findDuplicates(vector<int>& keys) {
    // 将 type 替换为 keys 的实际类型
    unordered_set<int> hashset;
    for (int key : keys) {
        if (hashset.count(key) > 0) {
            return true;
        }
        hashset.insert(key);
    }
    return false;
}
```

# 如何求两个数组的交集

先给出一个简单的例题：给定两个数组，如果求它们的交集？

我们可以创建两个哈希表，先将一个数组的元素加入哈希表中，然后在将第二个数组的元素加入到其中，如果有重复的，则表示这个是重复的元素。

然后再将其转化为数组。
```C++
class Solution {
public:
    vector<int> intersection(vector<int>& nums1, vector<int>& nums2) {
        unordered_set<int> res;
        unordered_set<int> hashNums1(nums1.begin(),nums1.end());
        for(int num:nums2) {
            if(hashNums1.count(num) > 0) {
                res.insert(num);
            }
        }
        return vector<int>(res.begin(),res.end());
    }
};
```


## 求两数之和

首先，返回的是元素的 下标，所以可以考虑使用 {元素:下标} 的结构构造哈希表；其次，遍历数组的过程中，如果当前元素为 x， target - x 在之前已经遍历过，则表明 [下标(x), 下标(target - x)] 就是答案，否则，将 x:下标(x) 添加到哈希表中。

```C++
class Solution {
public:
    vector<int> twoSum(vector<int>& nums, int target) {
        vector<int> res;
        unordered_map<int,int> hashMap;
        for(int i = 0;i < nums.size();i++) {
            int x = target - nums[i];
            if(hashMap.count(nums[i]) > 0) {
                res.push_back(i);
                res.push_back(hashMap[nums[i]]);
                break;
            }
            // 将 target - nums[i] 的 index 插入哈希表
            hashMap[x] = i;
        }
        return res;   
    }
};
```

## 同构字符串
给定两个字符串 s 和 t，判断它们是否是同构的。

如果 s 中的字符可以被替换得到 t ，那么这两个字符串是同构的。

我们可以这么想，即字符串 s 中的字符，于 t 中的一一对应，反之也是如此。

```C++
class Solution {
public:
    bool helper(string a,string b) {
        unordered_map<char,char> map;
        for(int i = 0;i<a.size();i++) {
            char c1 = a[i];
            char c2 = b[i];
            if(map.count(c1) > 0) {
                if(map[c1] != c2) {
                    return false;
                }
            } else {
                map.insert(make_pair(c1,c2));
            }
        }
        return true;
    }
    bool isIsomorphic(string s, string t) {
        if(s.size() == 0) return true;
        return helper(s, t) && helper(t, s);
    }
};
```

## 两个列表的最小索引总和

假设Andy和Doris想在晚餐时选择一家餐厅，并且他们都有一个表示最喜爱餐厅的列表，每个餐厅的名字用字符串表示。

你需要帮助他们用最少的索引和找出他们共同喜爱的餐厅。 如果答案不止一个，则输出所有答案并且不考虑顺序。 你可以假设总是存在一个答案。

```C++
class Solution {
public:
    vector<string> findRestaurant(vector<string>& list1, vector<string>& list2) {
        unordered_map<string,int> map;
        vector<string> res;
        int min = INT_MAX;
        for(int i = 0;i<list1.size();i++) {
            map[list1[i]] = i;
        }
        for(int i = 0;i<list2.size();i++) {
            if(map.count(list2[i])) {
                if(map[list2[i]] + i < min) {
                    res.clear();
                    min = map[list2[i]] + i;
                    res.push_back(list2[i]);

                } else if(map[list2[i]] + i == min){
                    res.push_back(list2[i]);
                }
            } 
        }
        return res;
    }
};
```