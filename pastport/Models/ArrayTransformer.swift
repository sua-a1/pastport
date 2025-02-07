import Foundation

@objc(StringArrayTransformer)
final class StringArrayTransformer: NSSecureUnarchiveFromDataTransformer {
    
    static let name = NSValueTransformerName(rawValue: String(describing: StringArrayTransformer.self))
    
    override static var allowedTopLevelClasses: [AnyClass] {
        [NSArray.self, NSString.self]
    }
    
    static func register() {
        let transformer = StringArrayTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let array = value as? [String] else { return nil }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: array as NSArray, requiringSecureCoding: true)
            return data
        } catch {
            print("DEBUG: Failed to transform array to data: \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return [] }
        do {
            let array = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSString.self], from: data) as? [String]
            return array ?? []
        } catch {
            print("DEBUG: Failed to transform data to array: \(error)")
            return []
        }
    }
} 