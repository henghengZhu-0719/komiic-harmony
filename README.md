# komiic-harmony

Komiic 的鸿蒙客户端，自用。数据层从 [Breeze-plugin-komiic](../Breeze-plugin-komiic) 移植，
GraphQL query 字符串与插件完全一致。

## 怎么跑起来

这里只有源码，没有 DevEco 的工程骨架（`build-profile.json5`、`hvigorfile.ts`、`oh-package.json5`、
`EntryAbility` 那些是 IDE 按 SDK 版本生成的，手写容易对不上）。步骤：

1. DevEco Studio 新建一个 Empty Ability 工程，模块名保持默认的 `entry`
2. 把本仓库的 `entry/src/main/ets/` 整个覆盖进去
3. 改两个生成文件，见下面两节
4. 连真机或模拟器运行

### module.json5 加网络权限

```json5
{
  "module": {
    "requestPermissions": [
      { "name": "ohos.permission.INTERNET" }
    ]
  }
}
```

没有这条，所有请求都会失败。

### main_pages.json 注册页面

`entry/src/main/resources/base/profile/main_pages.json`：

```json
{
  "src": [
    "pages/Index",
    "pages/Detail",
    "pages/Reader",
    "pages/Settings"
  ]
}
```

## 结构

```
komiic/
  Config.ets       接口地址、分页大小、分类/排序选项
  Types.ets        所有 GraphQL 响应的显式 interface
  Format.ets       时间、作者、计数的展示格式化
  Store.ets        preferences：账号、密码、token、开关
  Client.ets       HTTP + 鉴权 + token 过期自动重登 + 图片字节流
  Api.ets          18 个业务接口
  ImageLoader.ets  带请求头的图片下载 + 内存/磁盘两级缓存
  Sdk.ets          单例门面，页面只用这个
components/
  KomiicImage.ets  会带 Referer 的 Image
utils/
  Orientation.ets  阅读页的屏幕方向（自动 / 锁竖 / 锁横）
pages/
  Index.ets        最近更新 / 排行榜 / 分类 / 搜索
  Detail.ets       详情 + 章节列表 + 收藏
  Reader.ets       竖向连续阅读
  Settings.ets     登录、推荐开关、清缓存
```

## 阅读页的旋转

三档方向，进阅读页生效，退出去自动还原，选的档位记在 preferences（`reader.orientation`）里。

- **自动**：`AUTO_ROTATION_RESTRICTED`，跟着传感器转，同时尊重系统的「旋转锁定」开关
- **竖屏 / 横屏**：`setPreferredOrientation` 强制锁住，不理传感器

两种切换方式：

- **两指拧一下**（`RotationGesture`，两指、15° 触发）。往一边拧锁横屏，往另一边拧锁竖屏；
  已经锁在那个方向时再拧一次回到自动。拧的方向和结果对不上手感就往反方向拧，逻辑是对称的
- 点屏幕呼出控制条，右上角那颗按钮按一下换一档

横竖屏的排版差别：竖屏还是长图连续滚；横屏给每页加一个「最大高度 = 屏幕高度」的约束，
整页塞进一屏、两边留黑，翻屏时会把当前页重新对齐到顶端。尺寸靠根容器的 `onAreaChange`
实测，没用 `mediaquery`（那套 API 已经标 deprecated）。

运行时设的方向优先级高于 `module.json5` 里的 `orientation`，所以工程配置不用动。

## 三个必须知道的点

**图片必须带 Referer 和 UA。** 直接 `Image(url)` 会 403，ArkUI 的 Image 不支持自定义请求头。
所以走 `KomiicImage` → `ImageLoader` → 自己下字节流 → `createPixelMap`。
新增任何显示 Komiic 图片的地方，都得用 `KomiicImage`，别图省事写原生 `Image`。

**UA 不能改。** `Config.DEFAULT_USER_AGENT` 是伪装成 Chrome 的，换成鸿蒙默认 UA 大概率被拦。

**token 会过期。** `Client.graphql` 里拦截 `token is expired`，用存的账号密码静默重登后重放一次，
`runLogin` 保证并发时只发一个登录请求。这套逻辑别拆。

## 接口清单

免鉴权（11）：`recentUpdate` `hotComics` `comicByCategories` `searchComicsAndAuthors`
`comicByIds`（完整/精简两套投影）`recommendComicById` `chaptersByComicId` `imagesByChapterId`
`getMessagesByComicId` `messageChan` `messageCountByComicId`

需登录（6）：`folders` `comicInAccountFolders` `folderComicIds`
`addComicToFolder` `removeComicToFolder` `createFolder`

REST：`POST /api/login`、`GET /api/image/{kid}`

## 还没做

- 阅读进度记录（现在每次都从头开始）
- 云端收藏的独立页面（`Api.folderComics` 已经能用，缺 UI）
- 评论展示（`Api.commentsByComicId` / `commentReplies` 已经能用，缺 UI）
- 离线下载
- 横向翻页阅读模式

## 关于密码存储

现在账号密码是明文存在 preferences 里的，跟原插件一致。自用够了，
真要上心可以换成 `@kit.UniversalKeystoreKit` 加密后再存。
