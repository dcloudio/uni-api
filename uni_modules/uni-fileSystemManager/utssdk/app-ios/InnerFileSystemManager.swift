//
//  InnerFileSystemManager.swift
//  DCloud
//
//  Created by Fred on 2024/12/26.
//

import Foundation
import DCloudUTSFoundation
import DCloudUniappRuntime

extension InnerFileSystemManager {
    public func toValue<T>(_ value: Any, as type: T.Type) -> T? {
        return value as? T
    }
    
    public func failedAction(_ errorCode: NSNumber, errMsg: String? = nil) -> FileSystemManagerFailImpl {
        let failImpl = FileSystemManagerFailImpl(errorCode)
        if let errMsg = errMsg {
            failImpl.errMsg += ("(" + errMsg + ")")
        }
        return failImpl
    }
    
    public func getErrorMessage(name: String, errorCode: NSNumber, description: String) -> String {
        return name + " failed: " + "errorCode = " + errorCode.stringValue + "，errMsg = " + description
    }
}

extension InnerFileSystemManager {
    public func readFileSync(_ filePath: String, _ encoding: String?) -> Any {
        var result: Any = ""
        let semaphore = DispatchSemaphore(value: 0)
        
        UniFileSystemManager.readFile(encoding: encoding, path: filePath) { data, error in
            if let error = error {
                let err = self.getErrorMessage(name: "readFileSync", errorCode: error.errorCode, description: error.description)
                console.log(err)
            } else if let data = data {
                result = data
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let result = toValue(result, as: String.self) {
            return result
        } else if let result = toValue(result, as: ArrayBuffer.self) {
            return result
        }
        
        return ""
    }
    
    public func writeFileSync(_ filePath: String, _ data: Any, _ encoding: String?) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.writeFile(encoding: encoding, path: filePath, data: data) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "writeFileSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("writeFileSync:ok")
        }
    }

    public func unlinkSync(_ filePath: String) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.removeFile(filePath: filePath) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "unlinkSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("unlinkSync:ok")
        }
    }
    
    public func mkdirSync(_ dirPath: String, _ recursive: Bool) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.createDirectory(path: dirPath, recursive: recursive) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "mkdirSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("mkdirSync:ok")
        }
    }
    
    public func rmdirSync(_ dirPath: String, _ recursive: Bool) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.removeDirectory(filePath: dirPath, recursive: recursive) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "rmdirSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("rmdirSync:ok")
        }
    }
    
    public func readdirSync(_ dirPath: String) -> [String]? {
        var files: [String]?
        
        let group = DispatchGroup()
        group.enter()
        UniFileSystemManager.readDirectoryList(dirPath) { list, error in
            defer {
                group.leave()
            }
            if let error = error {
                let err = self.getErrorMessage(name: "readdirSync", errorCode: error.errorCode, description: error.description)
                console.log(err)
            }
            
            files = list
        }
        
        group.wait()
        
        return files
    }
    
    public func accessSync(_ path: String) {
        if UniFileSystemManager.isExist(path) {
            console.log("access:ok")
        } else {
            let error = failedAction(1300002)
            let err = self.getErrorMessage(name: "accessSync", errorCode: 1300002, description: error.errMsg)
            console.log(err)
        }
    }
    
    public func renameSync(_ oldPath: String, _ newPath: String) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.rename(oldPath: oldPath, newPath: newPath) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "renameSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("renameSync:ok")
        }
    }
    
    public func copyFileSync(_ srcPath: String, _ destPath: String) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.copyFile(srcPath: srcPath, destPath: destPath) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "copyFileSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("copyFileSync:ok")
        }
    }

    public func statSync(_ path: String, _ recursive: Bool) -> Array<Dictionary<String, Any>> {
        var array: Array<Dictionary<String, Any>> = []
        
        let group = DispatchGroup()
        group.enter()
        UniFileSystemManager.getStat(filePath: path, recursive: recursive) { fileStats, error in
            defer {
                group.leave()
            }
            if let error = error {
                let err = self.getErrorMessage(name: "statSync", errorCode: error.errorCode, description: error.description)
                console.log(err)
            } else if let fileStats = fileStats {
                fileStats.forEach { item in
                    let dic = [
                        "path": item.path as String,
                        "stats": item.stats as Stats
                    ]
                    array.append(dic)
                }
                
            }
        }
        group.wait()
        
        return array
    }
    
    public func appendFileSync(_ filePath: String, _ data: Any, _ encoding: String?) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.appendFile(encoding: encoding, path: filePath, data: data) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "appendFileSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("appendFileSync:ok")
        }
    }
    
    public func saveFileSync(_ tempFilePath: String, _ filePath: String?) -> String {
        var result = ""
        
        let semaphore = DispatchSemaphore(value: 0)
        UniFileSystemManager.saveFile(tempFilePath: tempFilePath, filePath: filePath) { path, error in
            if let error = error {
                let err = self.getErrorMessage(name: "appendFileSync", errorCode: error.errorCode, description: error.description)
                console.log(err)
            } else if let path = path {
                result = path
            }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        return result
    }
    
    public func truncateSync(_ filePath: String, _ length: NSNumber?) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.truncate(filePath: filePath, length: length) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "truncateSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("truncateSync:ok")
        }
    }
    
    public func readCompressedFileSync(_ filePath: String, _ compressionAlgorithm: String) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (dataString: String?, error: UniFileSystemManagerError?) = (nil, nil)
        UniFileSystemManager.readCompressedFile(filePath: filePath, compressionAlgorithm: compressionAlgorithm) { dataString, error in
            result = (dataString, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error {
            let err = self.getErrorMessage(name: "readCompressedFileSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if let dataString = result.dataString {
            return dataString
        }
        
        return "-1"
    }
    
    public func openSync(_ options: OpenFileSyncOptions) -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (fd: Int32?, error: UniFileSystemManagerError?) = (nil, nil)
        
        UniFileSystemManager.open(filePath: options.filePath, flag: options.flag) { fd, error in
            result = (fd, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error {
            let err = self.getErrorMessage(name: "openSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if let fd = result.fd {
            return fd.toString()
        }
        
        return "-1"
    }
    
    public func closeSync(_ options: CloseSyncOptions) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.close(fd: options.fd) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error {
            let err = self.getErrorMessage(name: "closeSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("closeSync:ok")
        }
    }
    
    public func fstatSync(_ options: FStatSyncOptions) -> Stats {
        
        let semaphore = DispatchSemaphore(value: 0)
        var result: (stats: Stats?, error: UniFileSystemManagerError?) = (nil, nil)
        
        UniFileSystemManager.fstat(fd: options.fd) { stats, error in
            result = (stats, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error {
            let err = self.getErrorMessage(name: "closeSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if let stats = result.stats {
            return stats
        }
        
        return UniFileSystemManagerStats()
    }
    
    public func ftruncateSync(_ options: FTruncateFileSyncOptions) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (success: Bool, error: UniFileSystemManagerError?) = (false, nil)
        
        UniFileSystemManager.ftruncate(fd: options.fd, length: options.length) { success, error in
            result = (success, error)
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error, !result.success {
            let err = self.getErrorMessage(name: "ftruncateSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if result.success {
            console.log("ftruncateSync:ok")
        }
    }
    
    /// 同步读取文件
    /// - Parameter options: ReadSyncOption 实例
    /// - Returns: 实际读取的字节数
    public func innerReadSync(_ options: ReadSyncOption) -> NSNumber? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (bytesRead: Int32?, error: UniFileSystemManagerError?) = (nil, nil)
        var bytesRead: NSNumber = 0
        
        UniFileSystemManager.read(arrayBuffer: options.arrayBuffer, fd: options.fd, offset: options.offset, length: options.length, position: options.position)  { bytesRead,  error in
            result = (bytesRead, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        func getErrorMessage(name: String, errorCode: NSNumber, description: String) -> String {
            return name + " failed: " + "errorCode = " + errorCode.stringValue + "，errMsg = " + description
        }
        
        if let error = result.error {
            let err = getErrorMessage(name: "readSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if let temp = result.bytesRead {
            bytesRead = NSNumber(temp)
            return bytesRead
        }
        return nil
    }
    
    /// 同步写入文件
    /// - Parameter options: WriteSyncOptions 实例
    /// - Returns: 实际被写入到文件中的字节数（注意，被写入的字节数不一定与被写入的字符串字符数相同）
    public func innerWriteSync(_ options: WriteSyncOptions) -> NSNumber? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: (bytesWritten: Int32?, error: UniFileSystemManagerError?) = (nil, nil)
        var bytesWritten: NSNumber = 0
        
        UniFileSystemManager.write(fd: options.fd, data: options.data, offset: options.offset, length: options.length, position: options.position) { bytesWritten,  error in
            result = (bytesWritten, error)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        if let error = result.error {
            func getErrorMessage(name: String, errorCode: NSNumber, description: String) -> String {
                return name + " failed: " + "errorCode = " + errorCode.stringValue + "，errMsg = " + description
            }
            let err = getErrorMessage(name: "writeSync", errorCode: error.errorCode, description: error.description)
            console.log(err)
        } else if let temp = result.bytesWritten {
            bytesWritten = NSNumber(temp)
            return bytesWritten
        }
        
        return nil
    }
}

