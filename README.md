# Swift-Cache-Service
A simple cacheing service written in Swift for the cacheing of NSObjects (and hence, UIImage, since UIImages conform to NSCoding/NSSecureCoding) and Codable.

General NSObject + NSSecureCoding, and Codable class implementation examples:

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

Usage with cache service (and demonstration of all basic cache features, such as (de)serialization to/from disk:

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


The above example creates an object to cache, caches it, then serializes the cache to disk, then clears the cache memory, then reads the cache from disk to memory, and finally reads the original object out of the cache.
