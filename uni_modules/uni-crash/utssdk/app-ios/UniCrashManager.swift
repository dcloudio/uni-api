//
//  UniCrashManager.swift
//  DCloudUniCrash
//
//  Created by Fred on 2024/9/13.
//

import Foundation
@_implementationOnly import KSCrash
import DCloudUniappRuntime
import DCloudUTSFoundation

enum UniCrashType: UInt {
    case native = 1
    case js = 2
    
    var rawValue: UInt {
        switch self {
        case .native :
            return 1
        case .js:
            return 2
        }
    }
}

public struct UniAppCrashInfo {
    let id: String
    let file: String
    let log: Any
    let time: String
    fileprivate let associatedUserInfoKey: String
}

public class UniCrashManager {
    // server link
    public static var uploadUrl: String = "https://cr.dcloud.net.cn/collect/crash"
    // crash 回调接口
    public static var onCrash: (() -> Void)?
    // 是否开启/关闭 crash 回调监听， 设置false触发监听回调，设置true不会触发监听回调
    public static var offAppCrash: Bool = false
    
    private static let dcAppInfoKey = "DCOnCrashAppInfo"
    private static let userInfoKey = "DCOnCrash-" + CACurrentMediaTime().toString()
    private static let preParametersKey = "DCOnCrash-PreParameters"
    
    // 设置最大crash 缓存次数
    private static let maxCrashCaches: Int = 5
    private static var crashCacheMap : UniCrashCacheMap<NSNumber, String>?
    
    // 是否是uni统计
    private static var isUniStatistics: Bool = false
    
    /// onCrash 是一个C函数指针, 需要通过 @convention(c)来声明
    private static var advancedCrashCallback: (@convention(c) (_ writer: UnsafePointer<KSCrashReportWriter>?) -> Void) = { writer in
        guard let writer = writer else { return }
        
        /// 获取崩溃时应用信息
        let params = UniCrashManager.getParametersWithLog()
        
        /// 将应用信息保存到本地
        UniCrashManager.writeParamsToFile(params: params, fileName: UniCrashManager.userInfoKey)
        
        /// withCString 方法确保字符串的 UTF8 编码在 C 函数调用期间是有效的，并且在闭包结束时自动释放
        UniCrashManager.dcAppInfoKey.withCString { dcAppInfoKey in
            UniCrashManager.userInfoKey.withCString { userInfoKey in
                // 安全地访问 writer 并添加自定义信息
                writer.pointee.addStringElement(writer, dcAppInfoKey, userInfoKey)
            }
        }
                
        if !offAppCrash {
             UniCrashManager.onCrash?()
        }
    }
    
    public class func initCrash() {
        // if let isUniStatistics = UniSDKEngine.shared.getAppManager()?.getCurrentApp()?.appConfig.isUniStatistics {
        //     UniCrashManager.isUniStatistics = isUniStatistics
        // }
                    
        //每次硬启动都会异步请求与crash相关的参数并保存到文件中，以便crash瞬间可以直接获取，减少耗时操作，降低crash瞬间存储相关信息失败的概率
        getPreParameters()
        
        guard let installation = KSCrashInstallationStandard.sharedInstance() else {
            return
        }
        
        installation.install()
        
        let crashHandler = KSCrash.sharedInstance()
        
        crashHandler?.deadlockWatchdogInterval = 5.0
        
        /// 设置 crash 时的回调方法
        crashHandler?.onCrash = advancedCrashCallback
        
        if UniCrashManager.isUniStatistics {
            checkAndClearOlderCrashCaches()
        } else {
            reportCrash()
        }
    }
    
    
    public class func getCrashReports() -> [UniAppCrashInfo]? {
        if !UniCrashManager.isUniStatistics { return nil }
        
        var crashReports = [UniAppCrashInfo]()
        
        let semaphore = DispatchSemaphore(value: 0)
        
        crashCacheMap?.allKeys().forEach({ key in
            let filter = KSCrashReportFilterAppleFmt.filter(with: KSAppleReportStyleUnsymbolicated)
            
            guard let reportDict = KSCrash.sharedInstance().report(withID: key) else {
                KSCrash.sharedInstance().deleteReport(withID: key)
                return
            }
            
            filter?.filterReports([reportDict], onCompletion: { filteredReports, completed, error in
                
                if let filteredReports = filteredReports, completed, filteredReports.count > 0, let appInfoKey = crashCacheMap?.value(forKey: key) {
                    
                    if let params = UniCrashManager.readParamsFromFile(fileName: appInfoKey) {
                        if let crashTime = params["t"] as? String,
                           let crashLog = filteredReports.first,
                           let path = writeCrashLog(crashLog, fileName: key.toString()) {
                            
                            let info = UniAppCrashInfo(id: key.toString(), file: path, log: crashLog, time: crashTime, associatedUserInfoKey: appInfoKey)
                            crashReports.append(info)
                            semaphore.signal()
                        }
                    }
                }
            })
            
            semaphore.wait()
        })
        
        return crashReports.count > 0 ? crashReports : nil
    }
    
    @discardableResult
    public class func deleteCrashReport(reportID: String) -> Bool {
        if !UniCrashManager.isUniStatistics { return false }

        let path = "file://\(UniCrashCacheDir())/\(reportID).crash"
        
        if let temp = Int(reportID) {
            let numID = NSNumber(value: temp)
            KSCrash.sharedInstance().deleteReport(withID: numID)
            if let appInfoKey = crashCacheMap?.value(forKey: numID) {
                UniCrashManager.deleteParamsFile(fileName: appInfoKey)
            }
        }
        
        do {
            if let fileUrl = URL(string: path), FileManager.default.fileExists(atPath: fileUrl.path) {
                try FileManager.default.removeItem(at: fileUrl)
                return true
            }
        } catch {
            return false
        }
        
        return false
    }
    
    public class func creatAppCrash() {
        fatalError("test crash")
    }
}

extension UniCrashManager {
    
    /*
     采用form-data格式（application/x-www-form-urlencoded）提交，包括以下字段：
     s：固定值为99
     p: 平台类型, i表示iOS平台，a表示Android平台
     dcid：设备唯一标识
     md：设备型号
     os：系统版本
     osv: 同os
     net：网络类型, net=0表示未知网络，net=1表示未连接网络，net=2表示有线网络，net=3表示WIFI网络，net=4表示2G网络，net=5表示3G网络，net=6表示4G网络，net=7表示5G网络
     vb：流应用基座版本号
     log：崩溃日志信息（用于定位崩溃位置）
     appid：应用标识（可能无值）
     appcount：运行应用的数目
     wvcount：打开Webview窗口的个数
     pn：应用包名
     pv: 应用版本
     mem: 应用内存占用量，单位为Byte
     memuse: 系统已使用内存，单位为Byte
     memtotal: 总内存，单位为Byte
     diskuse: 使用磁盘空间，单位为Byte
     disktotal: 总磁盘空间，单位为Byte
     etype：错误类型，1表示原生错误，2表示js异常
     eurl：发生js错误的url地址，仅etype=2时提交
     us: uni统计的配置信息, 2.0暂时不支持
     v: 应用版本号 manifest.json中的version->name的值
     vd:设备生产厂商
     root：是否越狱
     t：发生崩溃时间戳
     duration:运行时长
     fore:是否前台运行
     carrierid: 运营商id
     carriername： 运营商名称
     ua: User Agent
     psdk: 打包模式: 离线打包、自定义打包
     uv: uniapp版本是1， uniappx 版本是2
     */
    
    private class func getPreParameters() {
        // 开启网络连接状态监控
        UniNetManager.shared.startNetworkMonitor()
        
        var preParams: [String: Any] = [:]
        preParams.set("root", NSNumber(value: UTSiOS.isRoot()))

        DispatchQueue.global(qos: .background).async {
            
            preParams.set("dcid", UniDeviceInfo.shared.deviceId)
            preParams.set("md", UTSiOS.getModel())
            preParams.set("os", UniDeviceInfo.shared.systemVersion)
            preParams.set("osv", UniDeviceInfo.shared.systemVersion)
            preParams.set("vb", UTSiOS.getInnerVersion())
            preParams.set("appid", UTSiOS.getAppId())
            preParams.set("memtotal", UniDeviceInfo.getTotalMemory())
            preParams.set("disktotal", UniDeviceInfo.getTotalDiskSpace() ?? 0)
            preParams.set("v", UTSiOS.getAppVersion())
            preParams.set("ua", UTSiOS.getUserAgent())
            
            if let carrierid = UniDeviceInfo.getCarrierID() {
                preParams.set("carrierid", carrierid)
            }
            if let carriername = UniDeviceInfo.getCarrierName() {
                preParams.set("carriername", carriername)
            }
            
            UniCrashManager.writeParamsToFile(params: preParams, fileName: UniCrashManager.preParametersKey)
        }
    }
    
    private class func reportCrash() {
        /// 获取本地所有的日志id
        let ids = KSCrash.sharedInstance().reportIDs()
        
        let filter = KSCrashReportFilterAppleFmt.filter(with: KSAppleReportStyleUnsymbolicated)
        
        /// 遍历日志并上报
        ids?.forEach({ value, index in
            guard let reportID = value as? NSNumber else { return }
            /// 获取日志原始数据
            guard let reportDict = KSCrash.sharedInstance().report(withID: reportID) else {
                KSCrash.sharedInstance().deleteReport(withID: reportID)
                return
            }
            
            /// 通过 filter 构建苹果格式日志
            filter?.filterReports([reportDict], onCompletion: { filteredReports, completed, error in
                
                if let filteredReports = filteredReports, completed, filteredReports.count > 0 {
                    /// 先从崩溃日志中获取key
                    var appinfoKey = ""
                    if let user = reportDict.get("user") as? [String: Any], let temp = user.get(UniCrashManager.dcAppInfoKey) as? String {
                        appinfoKey = temp
                    }
                    
                    var params: [String: Any] = [:]
                    if let temp = UniCrashManager.readParamsFromFile(fileName: appinfoKey) {
                        params = temp
                    } else {
                        KSCrash.sharedInstance().deleteReport(withID: reportID)
                    }
                    
                    /// app uuid
                    /// 在低版本iOS系统可能多存在 recrash_report 一层
                    var appuuid: String?
                    if let system = reportDict.get("system") as? [String: Any], let uuid = system.get("app_uuid") as? String {
                        appuuid = uuid
                    }
                    if appuuid == nil {
                        if let recrashReport = reportDict.get("recrash_report") as? [String: Any], let system = recrashReport.get("system") as? [String: Any], let uuid = system.get("app_uuid") as? String  {
                            appuuid = uuid
                        }
                    }
                    params.set("app_uuid", appuuid ?? "")
                    params.set("log", filteredReports.first ?? "")

                    /// 异步使用post上传crash log
                    DispatchQueue.main.async {
                        var options = UniRequestOptions(url: UniCrashManager.uploadUrl)
                        options.method = .post
                        options.retryCount = 3
                        options.params = params
                        UniNetManager.request(options: options) { respones, error in
                            if let respones = respones {
                                /// 日志上传成功从本地删除
                                KSCrash.sharedInstance().deleteReport(withID: reportID)
                                UniCrashManager.deleteParamsFile(fileName: appinfoKey)
                                UNILogDebug("report success (reportID= \(reportID)): \(String(describing: respones.jsonData()))")
                            } else if let error = error {
                                UNILogDebug("report error (reportID= \(reportID)): \(error)")
                            }
                        }
                    }
                    
                } else if let error = error {
                    UNILogDebug("report error (reportID= \(reportID)): \(error)")
                }
            })
        })
    }

    
    private class func checkAndClearOlderCrashCaches() {
        
        crashCacheMap = UniCrashCacheMap(maxCapacity: maxCrashCaches)
        
        let ids = KSCrash.sharedInstance().reportIDs()
        
        ids?.forEach({ value in
            
            guard let reportID = value as? NSNumber else { return }
            
            let filter = KSCrashReportFilterAppleFmt.filter(with: KSAppleReportStyleUnsymbolicated)
            
            guard let reportDict = KSCrash.sharedInstance().report(withID: reportID) else {
                return
            }
            
            
            filter?.filterReports([reportDict], onCompletion: { filteredReports, completed, error in
                
                if let filteredReports = filteredReports, completed, filteredReports.count > 0 {
                    var appinfoKey = ""
                    if let user = reportDict["user"] as? [String: Any], let temp = user[UniCrashManager.dcAppInfoKey] as? String {
                        appinfoKey = temp
                    }
                    
                    crashCacheMap?.setValue(appinfoKey, forKey: reportID)
                }
            })
            
        })
    }
    
    private class func writeCrashLog(_ log: Any, fileName: String) -> String? {
        let path = "file://\(UniCrashCacheDir())/\(fileName).crash"
        
        if let fileUrl = URL(string: path) {
            
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                return fileUrl.path
            }
            
            do {
                if let stringLog = log as? String {
                    try stringLog.write(to: fileUrl, atomically: true, encoding: .utf8)
                } else if let dataLog = log as? Data {
                    try dataLog.write(to: fileUrl)
                } else if let dictionaryLog = log as? [String: Any] {
                    let data = try JSONSerialization.data(withJSONObject: dictionaryLog, options: .prettyPrinted)
                    try data.write(to: fileUrl)
                } else {
                    return nil
                }
                
                return fileUrl.path
                
            } catch {
                return nil
            }
        }

        return nil
    }
    
    private class func getParametersWithLog(_ content: String? = nil, type: UniCrashType? = .native, jsUrl: String? = nil ) -> [String: Any] {
        let preParams = UniCrashManager.readParamsFromFile(fileName: UniCrashManager.preParametersKey)
        
        let dcid = preParams?.get("dcid") ?? UniDeviceInfo.shared.deviceId
        let md = preParams?.get("md") ?? UTSiOS.getModel()
        let os = preParams?.get("os") ?? UniDeviceInfo.shared.systemVersion
        let osv = preParams?.get("osv") ?? UniDeviceInfo.shared.systemVersion
        let vb = preParams?.get("vb") ?? UTSiOS.getInnerVersion()
        let appid = preParams?.get("appid") ?? UTSiOS.getAppId()
        let memtotal = preParams?.get("memtotal") ?? UniDeviceInfo.getTotalMemory()
        let disktotal = preParams?.get("disktotal") ?? (UniDeviceInfo.getTotalDiskSpace() ?? 0)
        let v = preParams?.get("v") ?? UTSiOS.getAppVersion()
        let root = preParams?.get("root") ?? NSNumber(value: UTSiOS.isRoot())
        let ua = preParams?.get("ua") ?? UTSiOS.getUserAgent()
        let carrierid = preParams?.get("carrierid")
        let carriername = preParams?.get("carriername")
        let now = Date().timeIntervalSince1970
        let appStartTime = UniSDKEngine.shared.getAppManager()?.appStartTime ??  Date().timeIntervalSince1970
        let duration = round((now - appStartTime) * 10) / 10
        let fore = UniSDKEngine.shared.getAppManager()?.isAppInForeground() ?? false
        
        var net = 0
        switch UniNetManager.shared.currentNetworkType {
        case .unknown:
            net = 0
        case .none:
            net = 1
        case .wifi:
            net = 3
        case .cellular2G:
            net = 4
        case .cellular3G:
            net = 5
        case .cellular4G:
            net = 6
        case .cellular5G:
            net = 7
        case .ethernet:
            net = 0
        case .loopback:
            net = 0
        @unknown default:
            net = 0
        }
        
        var parameters = [
            "s": 99,
            "p": "i",
            "dcid": dcid,
            "md": md,
            "os": os,
            "osv": osv,
            "net": net,
            "vb": vb,
            "log": content ?? "",
            "appid": appid,
            "appcount": 1,
            "pn": Bundle.main.bundleIdentifier ?? "Unknown",
            "pv": Bundle.main.infoDictionary?.get("CFBundleShortVersionString") ?? "Unknown",
            "mem": UniDeviceInfo.getUsedMemory(),
            "memtotal": memtotal,
            "diskuse": UniDeviceInfo.getUsedDiskSpace() ?? 0,
            "disktotal": disktotal ?? 0,
            "etype": type?.rawValue ?? 1,
            "v": v,
            "vd": "Apple",
            "channel": "", // 后续支持渠道需要添加
            "batlevel": UniDeviceInfo.getBatteryInfo(),
            "root": root,
            "t": now.toString(),
            "duration": duration.toString(),
            "fore": fore ? 0 : 1,
            "ua": ua,
            "psdk": 0,
            "uv": 2
            
        ] as [String : Any]
        
        // etype=2/5时发生js错误页面的地址，目前仅支持原生crash捕获
        if let eurl = jsUrl {
            parameters.set("eurl", eurl)
        }
        
        if let carrierid = carrierid {
            parameters.set("carrierid", carrierid)
        }
        
        if let carriername = carriername {
            parameters.set("carriername", carriername)
        }
        return parameters
    }
    
    private class func writeParamsToFile(params: [String: Any], fileName: String) {
        
        let filePath = "\(UniCrashCacheDir())/\(fileName.lowercased()).plist"
        if let data = try? PropertyListSerialization.data(fromPropertyList: params, format: .binary, options: 0) {
            try? data.write(to: URL(fileURLWithPath: filePath))
        }
    }
    
    private class func readParamsFromFile(fileName: String) -> [String: Any]? {
        let filePath = "\(UniCrashCacheDir())/\(fileName.lowercased()).plist"
        if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
            if let params = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                return params
            }
        }
        return nil
    }
    
    @discardableResult
	class func deleteParamsFile(fileName: String) -> Bool {
        let filePath = "\(UniCrashCacheDir())/\(fileName.lowercased()).plist"
        let fileManager = FileManager.default
        
        do {
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
                UNILogDebug("File deleted successfully. path = \(filePath)")
                return true
            } else {
                UNILogDebug("File does not exist. path = \(filePath)")
                return false
            }
        } catch {
            UNILogDebug("Failed to delete file: \(error). path = \(filePath)")
            return false
        }
    }
    
    private class func UniGetSystemCachesDir() -> String {
        return NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
    }
    
    private class func UniEnsureDirExist(_ path: String) {
        if FileManager.default.fileExists(atPath: path) == false {
            do {
                try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
            }catch {
                UNILogDebug(error.localizedDescription)
            }
        }
    }
    
    private class func UniCrashCacheDir() -> String {
        let path = UniGetSystemCachesDir() + "/uni-crash"
        UniEnsureDirExist(path)
        return path
    }
}


private class UniCrashCacheMap<Key: Hashable, Value> {
    private var keys = [Key]()
    private(set) var _values = [Key: Value]()
    private let maxCapacity: Int
    
    public var values: [Key: Value] {
        return _values
    }
    
    init(maxCapacity: Int) {
        self.maxCapacity = maxCapacity
    }
    
    func setValue(_ value: Value, forKey key: Key) {
        if let _ = _values[key] {
            removeValue(forKey: key)
        }
        
        if keys.count >= maxCapacity {
            if let oldestKey = keys.first {
                removeValue(forKey: oldestKey)
            }
        }
        
        keys.append(key)
        _values[key] = value
    }
    
    func value(forKey key: Key) -> Value? {
        return _values[key]
    }
    
    func removeValue(forKey key: Key) {
        
        if let value = value(forKey: key) as? String {
            UniCrashManager.deleteParamsFile(fileName: value)
        }
        if let key = key as? NSNumber {
            KSCrash.sharedInstance().deleteReport(withID: key)
            UniCrashManager.deleteCrashReport(reportID: key.toString())
        }
        _values.removeValue(forKey: key)
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
        }
    }
    
    func count() -> Int {
        return keys.count
    }
    
    func allKeys() -> [Key] {
        return keys
    }
    
    func allValues() -> [Value] {
        return keys.compactMap { _values[$0] }
    }
}

