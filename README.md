# Swift-Cache-Service
A simple cacheing service written in Swift for the cacheing of NSObjects and Codable.

General NSObject, NSCoding class implementation example:

```swift
class NSTestObject : NSObject, NSSecureCoding {
    
    var bird:Int!;
    var dog:String!;
    
    static var supportsSecureCoding: Bool = true
    
    func encode(with coder: NSCoder) {
        coder.encode(bird, forKey: "bird")
        coder.encode(dog, forKey: "dog")
    }
    
    init(bird: Int, dog:String)
    {
        self.bird = bird
        self.dog = dog
        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let k = aDecoder.decodeObject(forKey: "bird") as? Int,
            let y = aDecoder.decodeObject(forKey: "dog") as? String else {
                return nil
        }
        self.init(bird: k, dog: y)
    }
}

class CodableTestObject : Codable {
    var bird:Int;
    var dog:String;
    init(bird: Int, dog:String)
    {
        self.bird = bird
        self.dog = dog
    }
}
```

Usage with cache service:

```swift
let testObject = NSTestObject(bird: 1, dog: "woof");  //let testObject = CodableTestObject(bird: 1, dog: "woof");
CacheService.shared.cacheObject(key: "object1", object: testObject)
CacheService.shared.saveCacheToDisk()
CacheService.shared.clearCache(memoryOnly: true)
CacheService.shared.loadCacheFromDisk()

if let birddog =  CacheService.shared.getObject(for: "object1") as NSTestObject? {
         //good job
} else {
        //something failed
}
```
