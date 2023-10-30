//
//  CodingHandler.swift
//
//  Created by TaoHebin on 2023/3/6.
//

import Foundation


func cleanUTF8(data:Data?) -> Data? {
    if let data = data {
        let cd = iconv_open("UTF-8", "UTF-8")
        var one = 1
        let argPointer = withUnsafeMutablePointer(to: &one) {$0}
        iconvctl(cd, ICONV_SET_DISCARD_ILSEQ, argPointer)
        var inbytesleft:Int = data.count
        var outbytesleft:Int = data.count
        
        var inbuf = data.withUnsafeBytes { (buffer : UnsafeRawBufferPointer) in
            let src:UnsafeMutablePointer<CChar>? = UnsafeMutablePointer<CChar>.allocate(capacity:buffer.count)
            memset(src, 0, buffer.count)
            memcpy(src, buffer.baseAddress, buffer.count)
            return src
        }
        let outbuf:UnsafeMutablePointer<CChar>? = UnsafeMutablePointer<CChar>.allocate(capacity:data.count)
        var outPtr = outbuf
        if iconv(cd, &inbuf, &inbytesleft, &outPtr, &outbytesleft)  == -1{
            return nil
        }
        
        var result : Data? = nil
        if let outbuf = outbuf{
            result = Data(bytes: outbuf, count: data.count)
        }
        iconv_close(cd)
        outbuf?.deallocate()
        return result
    }else{
        return nil
    }
}
