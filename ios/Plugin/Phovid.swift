import Foundation

@objc public class Phovid: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
