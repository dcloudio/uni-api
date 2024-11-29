
import DCloudUTSFoundation;
import DCloudUniappRuntime;

public var __$$on = {
(_ eventName: String, _ callback:@escaping (_ arg: Any...) -> Void) -> NSNumber in
    return UniUTSJS.on(eventName, callback);
};
public var __$$off = {
(_ eventName: String, _ callbackId: NSNumber) -> Void in
    UniUTSJS.off(eventName, callbackId);
};
public var __$$once = {
(_ eventName: String, _ callback:@escaping (_ arg: Any...) -> Void) -> NSNumber in
    return UniUTSJS.once(eventName, callback);
};
public var __$$emit = {
(_ eventName: String, _ spreadArg: Any...) -> Void in
    UniUTSJS.emit(eventName, spreadArg);
};
