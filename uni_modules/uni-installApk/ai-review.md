# uni-installApk 代码审查报告

## 功能概述
实现 Android 平台的 APK 安装功能，支持本地文件路径和 assets 资源文件。

## 代码质量和性能问题

### Android 平台 (utssdk/app-android/index.uts)

#### 1. **严重** - 文件存在性检查逻辑错误
**位置**: index.uts:23

**问题描述**:
```typescript
if (apkFile != null && !apkFile.exists() && !apkFile.isFile()) {
    let error = new InstallApkFailImpl(1300002);
    options.fail?.(error)
    options.complete?.(error)
    return
}
```
使用 `&&` (AND) 连接两个条件是错误的：
- `!apkFile.exists()`: 文件不存在
- `!apkFile.isFile()`: 不是文件

这意味着只有当文件**既不存在又不是文件**时才报错，但如果文件不存在，`isFile()` 调用本身就没有意义。

正确的逻辑应该是：文件不存在**或者**不是文件时报错。

**修复方案**:
```typescript
if (apkFile == null || !apkFile.exists() || !apkFile.isFile()) {
    let error = new InstallApkFailImpl(1300002);
    options.fail?.(error)
    options.complete?.(error)
    return
}
```

**影响**: 可能导致无效的 APK 文件路径没有被正确检测，造成后续安装失败且错误信息不明确。

---

#### 2. **高危** - 安全风险：过度授权
**位置**: index.uts:92

**问题描述**:
```typescript
function changePermissionRecursive(file: File){
    const cmd = "chmod -R 777 " + file.getAbsolutePath()
    const runtime = Runtime.getRuntime()
    try {
        runtime.exec(cmd)
    } catch (e: IOException) {
    }
}
```
使用 `chmod 777` 给予所有用户读写执行权限，这是严重的安全风险：
- 任何应用都可以读取、修改、执行这些文件
- 可能导致 APK 被恶意篡改
- 违反 Android 安全最佳实践

**修复方案**:
```typescript
function changePermissionRecursive(file: File){
    // Android 7.0+ 应该使用 FileProvider，不需要修改权限
    // Android 7.0 以下，使用更安全的权限设置
    const cmd = "chmod -R 755 " + file.getAbsolutePath()  // 只给所有者写权限
    const runtime = Runtime.getRuntime()
    try {
        runtime.exec(cmd)
    } catch (e: IOException) {
        // 记录错误
        console.error("Failed to change file permission: " + e.message)
    }
}
```

更好的方案是使用 Android API:
```typescript
function changePermissionRecursive(file: File) {
    try {
        file.setReadable(true, false)  // 所有人可读
        file.setExecutable(true, false) // 所有人可执行
        file.setWritable(true, true)    // 只有所有者可写
    } catch (e: Exception) {
        console.error("Failed to change file permission: " + e.message)
    }
}
```

---

#### 3. 资源泄漏风险
**位置**: index.uts:64-76

**问题描述**:
```typescript
const inputStream = context.getAssets().open(fileName)
const outputStream = new FileOutputStream(outFile)
let buffer = new ByteArray(1024);
do {
    let len = inputStream.read(buffer);
    if (len == -1) {
        break;
    }
    outputStream.write(buffer, 0, len)
} while (true)

inputStream.close()
outputStream.close()
```
如果在 do-while 循环中抛出异常，流不会被关闭，导致资源泄漏。

**修复方案**:
```typescript
let inputStream : InputStream | null = null;
let outputStream : FileOutputStream | null = null;
try {
    inputStream = context.getAssets().open(fileName)
    outputStream = new FileOutputStream(outFile)
    let buffer = new ByteArray(1024);
    do {
        let len = inputStream.read(buffer);
        if (len == -1) {
            break;
        }
        outputStream.write(buffer, 0, len)
    } while (true)
} finally {
    try {
        inputStream?.close()
    } catch (e: Exception) {}
    try {
        outputStream?.close()
    } catch (e: Exception) {}
}
```

---

#### 4. 错误处理不完整
**位置**: index.uts:51-89

**问题描述**:
```typescript
function copyAssetFileToPrivateDir(context : Context, fileName : string) : File | null {
    try {
        // ... 复制逻辑
        return outFile
    } catch (e : Exception) {
        e.printStackTrace()
    }
    return null
}
```
捕获异常但只打印堆栈跟踪，调用者无法获知失败原因。在 `installApk` 函数中也没有检查返回值是否为 null。

**修复方案**:
```typescript
// 在 installApk 函数中添加检查
if (filePath.startsWith("/android_asset/")) {
    filePath = filePath.replace("/android_asset/", "")
    apkFile = copyAssetFileToPrivateDir(context, filePath)

    // 添加空值检查
    if (apkFile == null) {
        let error = new InstallApkFailImpl(1300002);
        error.errMsg = "Failed to copy asset file";
        options.fail?.(error)
        options.complete?.(error)
        return
    }
}
```

---

#### 5. 成功回调过早调用
**位置**: index.uts:42-47

**问题描述**:
```typescript
context.startActivity(intent)
const success : InstallApkSuccess = {
    errMsg: "success"
}
options.success?.(success)
options.complete?.(success)
```
`startActivity` 只是启动了系统安装界面，并不代表 APK 安装成功。用户可能取消安装或安装失败。

**建议**:
1. 在文档中明确说明 `success` 回调表示**启动安装界面成功**，而不是安装完成
2. 考虑改名为 `InstallApkLaunchSuccess` 更准确
3. 如果需要监听实际安装结果，需要使用 BroadcastReceiver 监听 `ACTION_PACKAGE_ADDED`

---

#### 6. 字符串替换不完整
**位置**: index.uts:17

**问题描述**:
```typescript
filePath = filePath.replace("/android_asset/", "")
```
`replace` 只替换第一个匹配项。虽然这个场景下可能不会出现多次匹配，但使用 `replaceAll` 更安全。

**修复方案**:
```typescript
filePath = filePath.replaceAll("/android_asset/", "")
```

---

#### 7. 缺少参数验证
**位置**: index.uts:12-14

**问题描述**:
没有验证 `options.filePath` 是否为空或无效。

**修复方案**:
```typescript
export function installApk(options : InstallApkOptions) : void {
    // 参数验证
    if (options.filePath == null || options.filePath.trim() == "") {
        let error = new InstallApkFailImpl(1300002);
        error.errMsg = "Invalid file path";
        options.fail?.(error)
        options.complete?.(error)
        return
    }

    const context = UTSAndroid.getAppContext() as Context
    // ... 其余逻辑
}
```

---

#### 8. 缺少权限检查（Android 8.0+）
**问题描述**:
Android 8.0 (API 26) 及以上需要 `REQUEST_INSTALL_PACKAGES` 权限才能安装未知来源的应用。代码没有检查此权限。

**修复方案**:
```typescript
export function installApk(options : InstallApkOptions) : void {
    const context = UTSAndroid.getAppContext() as Context

    // Android 8.0+ 权限检查
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        const packageManager = context.getPackageManager()
        if (!packageManager.canRequestPackageInstalls()) {
            let error = new InstallApkFailImpl(1300003);  // 需要添加新错误码
            error.errMsg = "Missing REQUEST_INSTALL_PACKAGES permission";
            options.fail?.(error)
            options.complete?.(error)
            return
        }
    }

    // ... 其余逻辑
}
```

---

#### 9. 文件路径转换可能不准确
**位置**: index.uts:14

**问题描述**:
```typescript
var filePath = UTSAndroid.convert2AbsFullPath(options.filePath)
```
如果 `convert2AbsFullPath` 转换失败或返回无效路径，没有进行验证。

**建议**: 验证转换后的路径是否合法。

---

#### 10. 空指针风险
**位置**: index.uts:35, 39

**问题描述**:
```typescript
const apkUri = FileProvider.getUriForFile(context, authority, apkFile!!)
// ...
intent.setDataAndType(Uri.fromFile(apkFile!!), "application/vnd.android.package-archive");
```
使用 `!!` 强制解包，但之前的检查逻辑有误（问题1），可能导致空指针异常。

**修复方案**: 修复问题1 后，这里的强制解包是安全的。

---

### 错误定义 (utssdk/unierror.uts)

#### 11. Map 访问方式可能不正确
**位置**: unierror.uts:23

**问题描述**:
```typescript
this.errMsg = UniErrors[errCode] ?? "";
```
使用数组访问语法 `UniErrors[errCode]` 访问 Map，这可能不是正确的 UTS 语法。

**修复方案**:
```typescript
this.errMsg = UniErrors.get(errCode) ?? "";
```

---

#### 12. 错误码不完整
**问题描述**:
只定义了一个错误码 `1300002 (No such file)`，但可能还需要：
- 1300003: 缺少安装权限
- 1300004: 文件不是有效的 APK
- 1300005: 复制文件失败

**建议**: 扩展错误码定义，提供更详细的错误信息。

---

## 性能问题

#### 13. 固定缓冲区大小
**位置**: index.uts:66

**问题描述**:
```typescript
let buffer = new ByteArray(1024);
```
使用 1KB 的固定缓冲区可能导致大文件复制效率低下。

**优化方案**:
```typescript
let buffer = new ByteArray(8192);  // 使用 8KB 缓冲区
```

---

#### 14. assets 文件每次都复制
**位置**: index.uts:51-89

**问题描述**:
每次安装都会重新复制 assets 文件，即使文件已经存在。

**优化方案**:
```typescript
function copyAssetFileToPrivateDir(context : Context, fileName : string) : File | null {
    try {
        const destPath = context.getCacheDir().getPath() + "/apks/" + fileName
        const outFile = new File(destPath)

        // 检查文件是否已存在且有效
        if (outFile.exists() && outFile.isFile() && outFile.length() > 0) {
            return outFile;  // 直接返回，不重复复制
        }

        // ... 复制逻辑
    } catch (e : Exception) {
        e.printStackTrace()
    }
    return null
}
```

---

## 总体建议

### 安全性改进
1. 修改文件权限设置，使用 755 或 Android API
2. 添加 REQUEST_INSTALL_PACKAGES 权限检查
3. 验证 APK 文件完整性（可选）

### 健壮性改进
1. 完善参数验证
2. 修复文件存在性检查逻辑
3. 改进错误处理和资源管理
4. 添加更多错误码

### 文档改进
1. 明确说明 success 回调的含义
2. 说明所需权限配置
3. 提供 Android 各版本差异说明
4. 添加使用示例和常见问题

---

## 优先级建议

### P0 (必须修复):
1. 文件存在性检查逻辑错误 (问题1)
2. 安全风险：chmod 777 (问题2)
3. Map 访问方式 (问题11)

### P1 (高优先级):
1. 资源泄漏风险 (问题3)
2. 错误处理不完整 (问题4)
3. 缺少参数验证 (问题7)
4. 缺少权限检查 (问题8)

### P2 (中优先级):
1. 成功回调语义不明确 (问题5)
2. 字符串替换 (问题6)
3. 空指针风险 (问题10)
4. 错误码不完整 (问题12)

### P3 (低优先级):
1. 文件路径转换验证 (问题9)
2. 固定缓冲区大小 (问题13)
3. assets 文件重复复制 (问题14)

---

## 总体评价

**代码质量**: ⭐⭐ (2/5)
- 存在严重的逻辑错误和安全风险
- 错误处理不完善
- 缺少必要的参数验证和权限检查

**性能**: ⭐⭐⭐ (3/5)
- 基本逻辑合理
- 缓冲区可以优化
- 可以避免重复复制文件

**安全性**: ⭐⭐ (2/5)
- chmod 777 是严重的安全风险
- 缺少权限检查
- 没有文件完整性验证

**可维护性**: ⭐⭐⭐ (3/5)
- 代码结构清晰
- 但缺少注释
- 错误码定义不完整
