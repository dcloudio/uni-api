# uni-prompt 插件代码评审报告

## 插件概述
- **功能**: 实现Toast提示、Modal对话框、ActionSheet选择器等交互提示功能
- **支持平台**: Android、iOS、HarmonyOS
- **实现文件**: `utssdk/app-android/index.uts` + 各功能模块实现文件
- **核心模块**: showToast, showLoading, showModal, showActionSheet

---

## 代码质量问题

### 1. dispatchAsync参数使用不当
**位置**: Android平台index.uts所有函数

**代码示例** (index.uts:19-22, 26-29):
```typescript
export const showToast : ShowToast = function (options : ShowToastOptions) {
	UTSAndroid.dispatchAsync('main',function(res){
		ToastModule.showToastImpl(options)
	},null)
}

export const hideToast : HideToast = function () {
	UTSAndroid.dispatchAsync('main',function(res){
		ToastModule.hideToastImpl()
	},null)
}
```

**问题描述**:
1. 第三个参数传null,含义不明确
2. function(res)中的res参数未使用
3. 所有函数都使用相同模式,代码重复

**修复方案**:
```typescript
// 创建辅助函数
function runOnMainThread(callback: () => void) {
	UTSAndroid.dispatchAsync('main', () => {
		callback()
	}, null)
}

// 简化调用
export const showToast : ShowToast = function (options : ShowToastOptions) {
	runOnMainThread(() => {
		ToastModule.showToastImpl(options)
	})
}

export const hideToast : HideToast = function () {
	runOnMainThread(() => {
		ToastModule.hideToastImpl()
	})
}
```

### 2. 条件编译过多
**位置**: index.uts多处

**代码示例** (index.uts:7-12, 31-43):
```typescript
// #ifndef UNI-APP-X
import * as ModalModule from "./showModal.uts"
// #endif
// #ifndef UNI-APP-X
import * as ActionSheetModule from "./showActionSheet.uts"
// #endif

// #ifndef UNI-APP-X
export const showLoading : ShowLoading = function (options : ShowLoadingOptions) {
	UTSAndroid.dispatchAsync('main',function(res){
		ToastModule.showLoadingImpl(options)
	},null)
}
// #endif
```

**问题描述**:
1. 大量使用`#ifndef UNI-APP-X`条件编译
2. 相同条件的代码块分散在文件各处
3. 难以理解UNI-APP-X和非UNI-APP-X的区别

**修复方案**:
```typescript
// 方案1: 集中条件编译
// #ifndef UNI-APP-X
import * as ModalModule from "./showModal.uts"
import * as ActionSheetModule from "./showActionSheet.uts"

export const showLoading : ShowLoading = function (options : ShowLoadingOptions) {
	runOnMainThread(() => {
		ToastModule.showLoadingImpl(options)
	})
}

export const hideLoading : HideLoading = function () {
	runOnMainThread(() => {
		ToastModule.hideLoadingImpl()
	})
}

export const showModal : ShowModal = function (options : ShowModalOptions) {
	runOnMainThread(() => {
		ModalModule.showModalImpl(options)
	})
}

export const showActionSheet : ShowActionSheet = function (options : ShowActionSheetOptions) {
	runOnMainThread(() => {
		ActionSheetModule.actionSheetImpl(options)
	})
}
// #endif

// 方案2: 添加注释说明
/**
 * UNI-APP-X版本: showModal和showActionSheet使用uni-modal和uni-actionSheet独立插件
 * 非UNI-APP-X版本: 在本插件中实现
 */
```

### 3. 缺少输入验证
**位置**: 所有导出函数

**问题描述**:
没有验证options参数:
- options是否为null
- 必填字段是否存在
- 字段值是否合法

**修复方案**:
```typescript
export const showToast : ShowToast = function (options : ShowToastOptions) {
	if (options == null) {
		console.error('[showToast] options不能为空')
		return
	}

	// 验证title
	if (options.title == null || options.title.trim().length == 0) {
		console.error('[showToast] title不能为空')
		options.fail?.({
			errMsg: 'showToast:fail title不能为空'
		})
		return
	}

	// 验证duration
	if (options.duration != null && options.duration < 0) {
		console.warn('[showToast] duration不能为负数,使用默认值')
		options.duration = 1500
	}

	runOnMainThread(() => {
		ToastModule.showToastImpl(options)
	})
}
```

### 4. 缺少错误处理
**位置**: 所有函数

**问题描述**:
dispatchAsync和模块调用都没有try-catch包裹,出错会直接崩溃。

**修复方案**:
```typescript
export const showToast : ShowToast = function (options : ShowToastOptions) {
	try {
		runOnMainThread(() => {
			try {
				ToastModule.showToastImpl(options)
			} catch (e) {
				console.error('[showToast] 显示Toast失败:', e)
				options.fail?.({
					errMsg: `showToast:fail ${e.message}`
				})
			}
		})
	} catch (e) {
		console.error('[showToast] 切换主线程失败:', e)
		options.fail?.({
			errMsg: `showToast:fail ${e.message}`
		})
	}
}
```

---

## 功能完整性问题

### 1. Toast队列管理
**问题描述**:
如果快速连续调用showToast,可能:
- 后面的Toast覆盖前面的
- Toast显示混乱
- 用户看不清消息

**建议**:
```typescript
class ToastQueue {
	private static queue: ShowToastOptions[] = []
	private static isShowing = false

	static add(options: ShowToastOptions) {
		this.queue.push(options)
		if (!this.isShowing) {
			this.showNext()
		}
	}

	private static showNext() {
		if (this.queue.length == 0) {
			this.isShowing = false
			return
		}

		this.isShowing = true
		const options = this.queue.shift()!
		ToastModule.showToastImpl(options)

		// duration后显示下一个
		setTimeout(() => {
			this.showNext()
		}, options.duration || 1500)
	}
}
```

### 2. 缺少showToast和showLoading互斥
**问题描述**:
Toast和Loading可能同时显示,界面混乱。

**建议**:
```typescript
let currentPromptType: 'toast' | 'loading' | null = null

export const showToast : ShowToast = function (options : ShowToastOptions) {
	if (currentPromptType == 'loading') {
		hideLoading()
	}
	currentPromptType = 'toast'
	// ... 显示Toast
}

export const showLoading : ShowLoading = function (options : ShowLoadingOptions) {
	if (currentPromptType == 'toast') {
		hideToast()
	}
	currentPromptType = 'loading'
	// ... 显示Loading
}
```

### 3. 缺少日志记录
**问题描述**:
没有任何日志,不利于问题排查。

**建议**:
```typescript
export const showToast : ShowToast = function (options : ShowToastOptions) {
	console.log(`[showToast] title: ${options.title}, duration: ${options.duration}`)
	runOnMainThread(() => {
		ToastModule.showToastImpl(options)
		console.log('[showToast] Toast已显示')
	})
}
```

---

## 性能问题

### 1. dispatchAsync开销
**问题描述**:
每次调用都通过dispatchAsync切换到主线程,频繁调用时有性能开销。

**影响**:
轻微,因为这些操作本身就需要在主线程执行。

**建议**:
保持当前实现,但在文档中说明不要频繁调用。

---

## 安全问题

### 1. XSS风险 - Toast内容
**问题描述**:
如果Toast内容来自用户输入或网络数据,可能包含恶意脚本(在Web环境)。

**建议**:
```typescript
function sanitizeText(text: string): string {
	// 移除HTML标签和特殊字符
	return text
		.replace(/<[^>]*>/g, '')
		.replace(/[<>'"]/g, '')
		.substring(0, 200) // 限制长度
}

export const showToast : ShowToast = function (options : ShowToastOptions) {
	// 清理标题
	if (options.title != null) {
		options.title = sanitizeText(options.title)
	}
	// ...
}
```

### 2. 缺少调用频率限制
**问题描述**:
恶意代码可能快速连续调用showToast/showLoading,影响用户体验或造成性能问题。

**建议**:
```typescript
class RateLimiter {
	private static lastCallTime = 0
	private static minInterval = 100 // ms

	static shouldAllow(): boolean {
		const now = Date.now()
		if (now - this.lastCallTime < this.minInterval) {
			console.warn('[Prompt] 调用过于频繁')
			return false
		}
		this.lastCallTime = now
		return true
	}
}

export const showToast : ShowToast = function (options : ShowToastOptions) {
	if (!RateLimiter.shouldAllow()) {
		return
	}
	// ...
}
```

---

## 总结

### 优先级分类

**高优先级**:
1. 添加输入参数验证
2. 添加错误处理try-catch
3. 实现Toast和Loading互斥

**中优先级**:
1. 重构dispatchAsync调用,消除代码重复
2. 优化条件编译结构
3. 添加Toast队列管理

**低优先级**:
1. 添加日志记录
2. 添加XSS防护
3. 添加调用频率限制

### 整体评价
uni-prompt插件实现了常用的交互提示功能,代码结构简单清晰。主要问题:
1. 缺少基本的参数验证和错误处理
2. 代码重复较多,可以通过辅助函数优化
3. 缺少Toast队列和互斥管理可能导致显示混乱
4. 条件编译的使用需要更好的组织和文档说明

建议优先完善参数验证和错误处理,然后优化代码结构,最后补充高级功能如队列管理。该插件需要重点测试快速连续调用的场景。
