# uni-modal 插件代码评审报告

## 插件概述
- **功能**：实现模态弹框功能，支持显示和隐藏模态对话框
- **支持平台**：Android、iOS、HarmonyOS
- **实现文件**：
  - Android: `utssdk/app-android/index.uts`
  - iOS: `utssdk/app-ios/index.uts`
  - HarmonyOS: `utssdk/app-harmony/index.uts`

---

## 共通问题分析

### 代码质量问题

#### 1. 非空断言使用过度
**位置**：多处使用非空断言符`!`

**Android平台问题**：
- `index.uts:21` - `JSON.parseObject(inputParamStr)!`
- `index.uts:23-24` - `inputParam.getBoolean("cancel")!`, `inputParam.getBoolean("confirm")!`
- `index.uts:95` - `options!.modalPage`
- `index.uts:112` - `perPage.options!["successEventName"]`

**iOS平台问题**：
- `index.uts:20-24` - 多处使用 `inputParam!`
- `index.uts:99` - `options!.modalPage!`

**HarmonyOS平台问题**：
- `index.uts:20` - `JSON.parse(inputParamStr)!`
- `index.uts:108-126` - 多处使用 `options!`, `perPage.options!`

**问题描述**：
过度使用非空断言会降低代码的安全性，一旦实际值为null会导致运行时崩溃。

**修复方案**：
```typescript
// 当前代码（Android）
let inputParam = JSON.parseObject(inputParamStr)!
let res = {
  cancel : inputParam.getBoolean("cancel")!,
  confirm : inputParam.getBoolean("confirm")!,
  content : inputParam.getString("content")
} as ShowModalResult

// 修改后
let inputParam = JSON.parseObject(inputParamStr)
if (inputParam == null) {
  const res = new ShowModalFailImpl('解析参数失败')
  options.fail?.(res)
  options.complete?.(res)
  return
}
let res = {
  cancel : inputParam.getBoolean("cancel") ?? false,
  confirm : inputParam.getBoolean("confirm") ?? false,
  content : inputParam.getString("content")
} as ShowModalResult
```

#### 2. 代码重复问题
**位置**：三个平台的实现代码几乎完全相同

**问题描述**：
Android、iOS、HarmonyOS三个平台的showModal和hideModal函数逻辑基本一致，存在大量重复代码。差异仅在于：
- 获取当前页面的方式不同（Android使用`getCurrentPage()`，iOS/HarmonyOS使用`getCurrentPages()`）
- 获取dialogPages的方式略有不同
- 判断page相等的方式不同（`==` vs `===`）

**修复方案**：
考虑将共通逻辑提取到interface.uts中的公共函数，各平台只实现平台特定的部分：
```typescript
// interface.uts中添加公共函数
function generateModalEventNames(): ModalEventNames {
  const uuid = `${Date.now()}${Math.floor(Math.random() * 1e7)}`
  const baseEventName = `uni_modal_${uuid}`
  return {
    ready: `${baseEventName}_ready`,
    options: `${baseEventName}_options`,
    success: `${baseEventName}_success`,
    fail: `${baseEventName}_fail`
  }
}

// 各平台只实现平台特定的部分
```

#### 3. 事件监听器未清理
**位置**：`showModal`函数中的`uni.$on`监听器

**问题描述**：
在成功回调中注册的事件监听器（readyEventName, successEventName, failEventName）只在失败时清理（第44-46行），但在成功回调后没有清理，可能导致内存泄漏。

**修复方案**：
```typescript
uni.$on(successEventName, (inputParamStr: string) => {
  // ... 处理逻辑
  options.success?.(res)
  options.complete?.(res)

  // 清理事件监听器
  uni.$off(readyEventName, null)
  uni.$off(successEventName, null)
  uni.$off(failEventName, null)
  uni.$off(optionsEventName, null)
})
```

#### 4. UUID生成方式不安全
**位置**：所有平台的`showModal`函数第8行

**问题描述**：
```typescript
const uuid = `${Date.now()}${Math.floor(Math.random() * 1e7)}`
```
这种UUID生成方式存在冲突风险：
- 在同一毫秒内多次调用可能生成相同的UUID
- 随机数范围只有0-9999999，碰撞概率较高

**修复方案**：
```typescript
// 使用更安全的UUID生成方式
function generateUUID(): string {
  const timestamp = Date.now()
  const random1 = Math.floor(Math.random() * 1e9)
  const random2 = Math.floor(Math.random() * 1e9)
  const counter = (generateUUID.counter = (generateUUID.counter || 0) + 1)
  return `${timestamp}_${random1}_${random2}_${counter}`
}
```

#### 5. 错误处理不统一
**位置**：Android和iOS平台的hideModal函数

**Android问题**（index.uts:73-80）：
```typescript
const currentPageInstance = getCurrentPage()
if (currentPageInstance == null){
  const res = new HideModalFailImpl()
  options?.fail?.(res)
  options?.complete?.(res)
  return
}
```

**iOS问题**（index.uts:71-85）：
检查了pages数组和currentPage是否为null，但逻辑冗余。

**修复方案**：
统一错误处理逻辑，添加明确的错误信息：
```typescript
if (currentPageInstance == null){
  const res = new HideModalFailImpl('hideModal:fail 获取当前页面失败')
  options?.fail?.(res)
  options?.complete?.(res)
  return
}
```

### 性能问题

#### 1. JSON序列化和反序列化性能开销
**位置**：所有平台的第16-17行和第20-25行

**问题描述**：
```typescript
// 第16-17行
uni.$emit(optionsEventName, JSON.parse(JSON.stringify(options)))

// 第20-25行
let inputParam = JSON.parseObject(inputParamStr)
```
频繁的JSON序列化/反序列化会带来性能开销，特别是当options对象较大时。

**影响范围**：
- 每次调用showModal都会执行一次JSON序列化+反序列化
- 如果用户快速连续调用多次，性能影响会累积

**修复方案**：
考虑直接传递对象引用，或使用更高效的序列化方式：
```typescript
// 如果平台支持，直接传递对象
uni.$emit(optionsEventName, options)

// 或者只序列化必要的字段
const simplifiedOptions = {
  title: options.title,
  content: options.content,
  showCancel: options.showCancel,
  // ... 其他必要字段
}
uni.$emit(optionsEventName, simplifiedOptions)
```

#### 2. 循环遍历可优化
**位置**：hideModal函数中的双重循环

**问题描述**：
```typescript
// 第87-101行：查找需要关闭的dialog
for(let perPage of dialogPages){
  if (isSystemModalDialogPage(perPage)) {
    // ...
  }
}

// 第105-120行：关闭找到的dialog
for(let perPage of shallClosePages){
  // ...
}
```
如果只需要关闭单个modal，第一个循环找到后应该立即break，但在Android平台只有特定条件下才break。

**修复方案**：
```typescript
// 如果指定了modalPage，找到后立即break
if(options?.modalPage != null){
  for(let perPage of dialogPages){
    if (isSystemModalDialogPage(perPage) && perPage == options!.modalPage){
      shallClosePages.push(perPage)
      break // 找到目标，立即退出
    }
  }
}
```

### 功能完整性问题

#### 1. 平台判断逻辑不一致
**位置**：isSystemModalDialogPage函数

**Android/HarmonyOS**（使用startsWith）：
```typescript
return page.route.startsWith("uni:uniModal")
```

**iOS**（使用精确匹配）：
```typescript
return page.route == "uni:uniModal"
```

**问题描述**：
平台间的判断逻辑不一致可能导致行为差异。

**修复方案**：
统一使用startsWith或者明确路由格式的命名规范：
```typescript
// 统一使用startsWith
function isSystemModalDialogPage(page: UniPage):boolean {
  return page.route.startsWith("uni:uniModal")
}
```

#### 2. 缺少日志记录
**位置**：整个文件

**问题描述**：
代码中完全没有日志输出，不利于问题排查和调试。特别是在：
- UUID生成时
- 事件监听器注册/注销时
- openDialogPage失败时
- hideModal找不到目标页面时

**修复方案**：
在关键路径添加日志：
```typescript
export const showModal: ShowModal = function (options: ShowModalOptions):ModalPage | null {
  const uuid = `${Date.now()}${Math.floor(Math.random() * 1e7)}`
  console.log(`[showModal] 创建modal，UUID: ${uuid}`)

  // ... 其他代码

  let openRet = uni.openDialogPage({
    url: `...`,
    fail(err) {
      console.error(`[showModal] 打开dialog失败:`, err)
      // ...
    }
  })

  console.log(`[showModal] 打开dialog ${openRet != null ? '成功' : '失败'}`)
  return openRet
}
```

#### 3. HarmonyOS平台特殊处理不够健壮
**位置**：HarmonyOS的hideModal函数（index.uts:87-92）

**问题描述**：
```typescript
if((currentPage as ESObject).$systemDialogPages == null) {
  const res = new HideModalFailImpl()
  options?.fail?.(res)
  options?.complete?.(res)
  return
}
```
使用类型转换`as ESObject`访问`$systemDialogPages`，这种方式不够类型安全。

**修复方案**：
```typescript
// 更安全的检查方式
const dialogPages = (currentPage as any).$systemDialogPages
if (dialogPages == null || !Array.isArray(dialogPages)) {
  console.warn('[hideModal] $systemDialogPages不存在或类型错误')
  const res = new HideModalFailImpl('hideModal:fail 获取dialog页面失败')
  options?.fail?.(res)
  options?.complete?.(res)
  return
}
```

#### 4. 页面比较逻辑不一致
**位置**：hideModal函数中比较modalPage的逻辑

**Android**（index.uts:95）：
```typescript
if(perPage == options!.modalPage)
```

**iOS**（index.uts:99）：
```typescript
if(perPage === options!.modalPage!)
```

**HarmonyOS**（index.uts:108）：
```typescript
if(perPage.options!["optionsEventName"] === options!.modalPage!.options["optionsEventName"])
```

**问题描述**：
三个平台使用了不同的比较方式，HarmonyOS甚至通过比较options中的属性来判断，这可能导致：
- 不同平台行为不一致
- HarmonyOS的方式依赖于options["optionsEventName"]的存在，可能出错

**修复方案**：
统一比较方式，建议使用对象引用比较：
```typescript
if(perPage === options!.modalPage)
```

---

## 总结

### 优先级分类

**高优先级（建议立即修复）**：
1. 事件监听器泄漏问题 - 可能导致内存泄漏
2. 非空断言过度使用 - 可能导致运行时崩溃
3. 页面比较逻辑不一致 - 导致跨平台行为差异

**中优先级（建议近期修复）**：
1. UUID生成方式不安全 - 可能导致事件冲突
2. 代码重复问题 - 维护成本高
3. 添加日志记录 - 便于问题排查
4. 统一错误处理逻辑

**低优先级（可选优化）**：
1. JSON序列化性能优化
2. 循环遍历优化
3. 完善注释文档

### 整体评价
该插件的实现相对简单清晰，主要通过事件总线和openDialogPage来实现模态框功能。代码在三个平台上基本一致，但存在一些细微差异需要统一。主要问题集中在：
1. 内存管理（事件监听器未清理）
2. 类型安全（过度使用非空断言）
3. 跨平台一致性（判断逻辑不统一）

建议优先修复高优先级问题，特别是事件监听器泄漏和非空断言问题，以确保应用的稳定性和内存安全。
