# 从0开始的Flutter开发
自然会遇到不少问题，记录在下

## github issue 请求
在page大的时候会报错：
```
{
  "message": "Pagination with the page parameter is not supported for large datasets, please use cursor based pagination (after/before)",
  "documentation_url": "https://docs.github.com/rest/issues/issues#list-repository-issues",
  "status": "422"
}
```
此时需要看返回值的link提供的链接，一页一页获取。返回内容参考：https://docs.github.com/en/rest/using-the-rest-api/getting-started-with-the-rest-api?apiVersion=2022-11-28#about-the-response-code-and-headers


```py
import requests

def fetch_issues(repo_owner, repo_name, per_page=2):
    # base_url = "https://api.github.com/repositories/117391789/issues?per_page=2&after=Y3Vyc29yOnYyOpLPAAABllNotEjOszuOYw%3D%3D&page=2"
    base_url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/issues?per_page={per_page}"
    print("base_url: ", base_url)
    response = requests.get(base_url)
    if response.status_code != 200:
        print(f"Error: {response.status_code}")
        print(response.text)
        return

    link_header = response.headers.get("Link")
    print("link_header: ",link_header)

    issues = response.json()
    print("issues: ", issues)

# 使用示例
issues = fetch_issues("zytx121", "je")

"""
link_header:  <https://api.github.com/repositories/117391789/issues?per_page=2&after=Y3Vyc29yOnYyOpLPAAABlkdSAhjOsw1S3g%3D%3D&page=3>; rel="next", <https://api.github.com/repositories/117391789/issues?per_page=2&page=1&before=Y3Vyc29yOnYyOpLPAAABlkdjwRDOsw3JCA%3D%3D>; rel="prev"
"""
```

## SharedPreferencesWithCache
可以用 `reload` 刷新缓存。缓存的意义在于后续读取是同步的。

## 状态共享
https://book.flutterchina.club/chapter15/globals.html#_15-4-1-%E5%85%A8%E5%B1%80%E5%8F%98%E9%87%8F-global%E7%B1%BB

  全局变量就是单纯指会贯穿整个APP生命周期的变量，用于单纯的保存一些信息，或者封装一些全局工具和方法的对象。而共享状态则是指哪些需要跨组件或跨路由共享的信息，这些信息通常也是全局变量，而共享状态和全局变量的不同在于前者发生改变时需要通知所有使用该状态的组件，而后者不需要。为此，我们将全局变量和共享状态分开单独管理。

## 搜索界面
模仿夸克，让搜索框下移。为了方便，搜索界面新开了一个页面，使用hero进行位置过渡。有一些难点：
- hero时键盘如何始终弹出？AI说用跨页面的 `focusNode` ，但会导致新页面有键盘但无法聚焦。终于利用解释不清的特性实现了，见[searchBartest.dart](/lib/test/searchbar.dart)。唯一的缺点是：短时间内当进入search界面，收起键盘，退出界面，会导致键盘闪现，猜测是因为hero打断了之前界面的键盘弹起动画。还是有隐患。
- 键盘弹出会导致“底部”的位置改变，导致抖动；在退出页面时键盘的收起也会导致离开动画的鬼畜。观察后猜测夸克的解决方案是记住上一次键盘的高度，于是用此方案实现了[`KeyboardSpacer`](lib/components/searchbar.dart)。

## markdown相关
这部分很繁琐，专门开了个文件介绍：[lib/mdEditor/README.md](lib/mdEditor/README.md)

## 小米底部手势栏透明
在 `android/app/src/main/res/values/styles.xml` 加入 `<item name="android:windowTranslucentNavigation">true</item>`

## github 登录
由于要向第三方仓库发送issue，只能用Oauth App而不是Github App。由于没有后端，而且不能将Client secret写在代码中（会泄露），所以只能使用`Enable Device Flow`。