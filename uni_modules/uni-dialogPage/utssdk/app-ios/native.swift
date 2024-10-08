
import Foundation
import DCloudUTSFoundation
import DCloudUniappRuntime

typealias RouteErrorCode = NSNumber;

public typealias OpenDialogPageSuccess = AsyncApiSuccessResult
public typealias OpenDialogPageSuccessCallback = (OpenDialogPageSuccess)->Void
public protocol OpenDialogPageFail : IUniError {}
public typealias OpenDialogPageFailCallback = (OpenDialogPageFail)->Void
public typealias OpenDialogPageComplete = AsyncApiResult
public typealias OpenDialogPageCompleteCallback = (OpenDialogPageComplete)->Void


public typealias CloseDialogPageSuccess = AsyncApiSuccessResult
public typealias CloseDialogPageSuccessCallback = (CloseDialogPageSuccess)->Void
public protocol CloseDialogPageFail : IUniError {}
public typealias CloseDialogPageFailCallback = (CloseDialogPageFail)->Void
public typealias CloseDialogPageComplete = AsyncApiResult
public typealias CloseDialogPageCompleteCallback = (CloseDialogPageComplete)->Void

public class OpenDialogPageSuccessImpl : OpenDialogPageSuccess {
   public var errMsg: String = "openDialogPage: ok"
   init(_ args : Map<String, Any> ) {
       if  let errMsg = args["errMsg"] as? String {
           self.errMsg = errMsg
       }
   }
}

public class EventChannel {}

public class OpenDialogPageFailImpl : UniError, OpenDialogPageFail {
   init(_ args : Map<String, Any> ) {
       super.init()
       if  let errMsg = args["errCode"] as? String {
           self.errMsg = errMsg
       }
   }
}

public class OpenDialogPageOptions{
   public var url : String = ""
   public var animationType : String? = nil
   public var animationDuration : NSNumber? = nil
   public var disableEscBack : NSNumber? = nil
   public var parentPage : UniPage? = nil
   public var success : OpenDialogPageSuccessCallback? = nil
   public var fail : OpenDialogPageFailCallback? = nil
   public var complete : OpenDialogPageCompleteCallback? = nil
}

public class CloseDialogPageSuccessImpl : CloseDialogPageSuccess {
   public var errMsg = "closeDialogPage: ok"
   init(_ args : Map<String, Any> ) {
       if  let errMsg = args["errMsg"] as? String {
           self.errMsg = errMsg
       }
   }
}

public class CloseDialogPageFailImpl : UniError, CloseDialogPageFail {
   init(_ args : Map<String, Any> ) {
       super.init()
       if  let errMsg = args["errCode"] as? String {
           self.errMsg = errMsg
       }
   }
}

public class CloseDialogPageOptions {
   public var dialogPage : UniDialogPage? = nil
   public var animationType : String? = nil
   public var animationDuration : NSNumber? = nil
   public var success : CloseDialogPageSuccessCallback? = nil
   public var fail : CloseDialogPageFailCallback? = nil
   public var complete : CloseDialogPageCompleteCallback? = nil
}

public func openDialogPage(_ option : OpenDialogPageOptions) -> UniDialogPage? {
       let ocOption = UniOpenDialogPageOptions()
       ocOption.url = option.url
       ocOption.parentPage = option.parentPage
       ocOption.animationType = option.animationType
       ocOption.animationDuration = option.animationDuration
       if let callback = option.success  {
           ocOption.success = { args in
               let res = OpenDialogPageSuccessImpl(args)
               callback( res )
               if let callback = option.complete  {
                   ocOption.complete = { args in
                       callback( res )
                   }
               }
           }
       }
       if let callback = option.fail  {
           ocOption.fail = { args in
               let res = OpenDialogPageFailImpl(args)
               callback( res )
               if let callback = option.complete  {
                   ocOption.complete = { args in
                       callback( res )
                   }
               }
           }
       }
       
       let dialogPage = UniUTSJSImpl.openDialogPage(ocOption) as? UniDialogPage
       return dialogPage
   }
   
   public  func closeDialogPage(_ option : CloseDialogPageOptions) {
       let ocOption = UniCloseDialogPageOptions()
       if let dialogPage = option.dialogPage  {
           ocOption.dialogPage = dialogPage
       }
       ocOption.animationType = option.animationType
       ocOption.animationDuration = option.animationDuration
       if let callback = option.success  {
           ocOption.success = { args in
               let res = CloseDialogPageSuccessImpl(args)
               callback( res )
               if let callback = option.complete  {
                   ocOption.complete = { args in
                       callback( res )
                   }
               }
           }
       }
       if let callback = option.fail  {
           ocOption.fail = { args in
               let res = CloseDialogPageFailImpl(args)
               callback( res )
               if let callback = option.complete  {
                   ocOption.complete = { args in
                       callback( res )
                   }
               }
           }
       }
       UniUTSJSImpl.closeDialogPage(ocOption)
   }


