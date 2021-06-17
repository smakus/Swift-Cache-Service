//
//  CacheService.swift

import Foundation
import UIKit

//you can't cast objects as protocols, so instead we are extending concerete objects to conform to protocols
extension Encodable {
    func toJSONData() -> Data? { try? JSONEncoder().encode(self) }
}

extension Encodable {
    func toJSONString() -> String? {
        guard let data = self.toJSONData() else {
            return nil
        }
        return String(data: data, encoding: String.Encoding.utf8) }
}

extension Decodable {
    init(jsonData: Data) throws {
        self = try JSONDecoder().decode(Self.self, from: jsonData)
    }
}


class CacheService {
    
    public static let shared = CacheService();
    
    //if we are using sync and barriers everywhere why bother with .concurrent?  anyway, research later
    private let queue = DispatchQueue(label: "service.cache", attributes: .concurrent)
    
    private init() {
        loadCacheFromDisk()
    }
    
    private var NSObjectCache = Dictionary<String, NSCacheObject>()
    private var CodableCache = Dictionary<String, CodableCacheObject>()
    
    private let NSObjectCacheFileName = "nsobjectcache.dat"
    private let CodableCacheFileName = "codablecache.dat"
    
    func getCount() -> Int {
        return NSObjectCache.count + CodableCache.count
    }
    
    func clearCache(memoryOnly: Bool = false) {
        NSObjectCache = Dictionary<String, NSCacheObject>()
        CodableCache = Dictionary<String, CodableCacheObject>()
        print("Cleared memory cache.")
        if !memoryOnly {
            FileSystem.clearCacheDirectory()
        }
    }
    
    func purgeExpiredObjects() {
        let purgeDate = Date()
        for (key, value) in self.CodableCache {
            if value.expirationDate <= purgeDate {
                self.CodableCache[key] = nil
            }
        }
        
        for (key, value) in self.NSObjectCache {
            if value.expirationDate <= purgeDate {
                self.NSObjectCache[key] = nil
            }
        }
    }
    
    func saveCacheToDisk() {
        //save codable cache - could probably just serialize the dictionary itself, but alas:
        var codablediskcache:[CodableCacheObject] = [];
        for (_, value) in self.CodableCache {
            codablediskcache.append(value)
        }
        let jsonEncoder = JSONEncoder()
        guard let codableCacheData = try? jsonEncoder.encode(codablediskcache) else {
            print("Error archiving codable cache: Encoding of CodableCache resulted in nil data.")
            return;
        }
        FileSystem.writeToCacheDirectory(data: codableCacheData, fileName: CodableCacheFileName)
        
        //save nsobject cache
        let objectdiskcache = NSCacheObjectList()
        for (_, value) in self.NSObjectCache {
            objectdiskcache.list.append(value)
        }
        
        do {
            let objectCacheData = try NSKeyedArchiver.archivedData(withRootObject: objectdiskcache, requiringSecureCoding: false)
            FileSystem.writeToCacheDirectory(data: objectCacheData, fileName: NSObjectCacheFileName)
        } catch {
            print("Error: Could not archive NSCacheObjectList to disk. Error: \(error.localizedDescription)")
        }
    }
    
    public func loadCacheFromDisk() {
        //load codables:
        if let loadedData = FileSystem.readFromCacheDirectory(fileName: CodableCacheFileName) {
            do {
                let jsonDecoder = JSONDecoder()
                if let diskcache = try jsonDecoder.decode([CodableCacheObject]?.self, from: loadedData) {
                    print("Successfully unarchived CodableObjectCache: \(diskcache.count) items")
                    for entry in diskcache {
                        if entry.expirationDate > Date() {
                            CodableCache[entry.key] = entry;
                        }
                    }
                    print("\(CodableCache.count) items are now in CodableObjectCache (if count is lower than above, some items from archive may have expired).")
                } else {
                    print("Error: Could not unarchive CodableObjectCache from disk. Could not unarchive object, or archived object was null.")
                    FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since we will most likely just keep the monolith cache system instance
                }
            } catch {
                print("Error: Could not unarchive CodableObjectCache from disk. Error: \(error.localizedDescription)")
                FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since we will most likely just keep the monolith cache system instance
            }
        }
        //load NSobjects:
        if let loadedData = FileSystem.readFromCacheDirectory(fileName: NSObjectCacheFileName) {
            do {
                //NSKeyedUnarchiver.unarchivedObject(ofClass: NSCacheObjectList.self, from: loadedData)
                //NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(loadedData) as? NSCacheObjectList
                //NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSCacheObjectList.self, NSCacheObject.self, UIImage.self, NSArray.self], from: loadedData) as? NSCacheObjectList
                if let diskcache = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(loadedData) as? NSCacheObjectList {
                    print("Successfully unarchived NSObjectCache: \(diskcache.list.count) items")
                    for entry in diskcache.list {
                        if entry.expirationDate > Date() {
                            NSObjectCache[entry.key] = entry;
                        }
                    }
                    print("\(NSObjectCache.count) items are now in NSObjectCache (if count is lower than above, some items from archive may have expired).")
                } else {
                    print("Error: Could not unarchive NSObjectCache from disk. Could not unarchive object, or archived object was null.")
                    FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since we will most likely just keep the monolith cache system instance
                }
            } catch {
                print("Error: Could not unarchive NSObjectCache from disk. Error: \(error.localizedDescription)")
                FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since we will most likely just keep the monolith cache system instance
            }
        }
    }
    
    //WARNING: ALL nscache objects need to follow the NSObject, NSCoding standard in order to serialize properly.
    //So why are we doing this?  Codable only works on almalgamations of primitive types, and swift can't serialize general AnyObjects yet, while NSObject can, provided you implement NSCoding (and images happen to serialize perfectly, as they already adhere to NSCoding).
    
    func cacheObject<T>(key: String, object: T, TTLInMinutes:Int? = nil)
    {
        var newTTL = TTLInMinutes
        if newTTL == nil {
            if object is UIImage {
                newTTL = 1440 //cache images for a day
            } else {
                newTTL = 525600 //cache anything else for a long date (login timeout should eventually refresh these)
            }
        }
        if object is Codable {
            if let objectAsJson = (object as! Codable).toJSONString() {
                let codableCacheObj = CodableCacheObject(key: key, expirationDate: Date().addingTimeInterval(TimeInterval(newTTL! * 60)), stringSerializedObject: objectAsJson)
                queue.sync(flags: .barrier) {
                    self.CodableCache[key] = codableCacheObj;
                    print("cached data for: \(key)")
                }
            } else {
                print("could not serialize codable object for: \(key)")
            }
        } else {
            let cacheObj = NSCacheObject(key: key, expirationDate: Date().addingTimeInterval(TimeInterval(newTTL! * 60)), object: object as AnyObject)
            queue.sync(flags: .barrier) {
                self.NSObjectCache[key] = cacheObj;
                print("cached data for: \(key)")
            }
        }
    }
    
    func getObject<T>(for key:String) -> T? {
        queue.sync(flags: .barrier) {
            if T.self is Codable.Type {
                if let cachedObject = CodableCache[key] {
                    //should be in UTC to deal with a change in timezone.... unless that is handled under the hood.  dont care right now
                    if cachedObject.expirationDate > Date() {
                        
                        guard let model = T.self as? Decodable.Type else {
                            NSObjectCache[key] = nil;
                            print("could not convert cached object to type \(T.self) for: \(key)")
                            return nil as T?;
                        }
                        
                        if let returnObj = try? model.init(jsonData: cachedObject.stringSerializedObject.data(using: .utf8)!) as? T {
                            print("Found and returned good object for key: \(key)")
                            return returnObj;
                        } else {
                            NSObjectCache[key] = nil;
                            print("could not convert cached object to type \(T.self) for: \(key)")
                            return nil as T?;
                        }
                    } else {
                        NSObjectCache[key] = nil;
                        print("cache expired for key (removing now): \(key)")
                        return nil as T?;
                    }
                } else {
                    print("object does not exist in cache for key: \(key)")
                    return nil as T?;
                }
            } else  {
                if let cachedObject = NSObjectCache[key] {
                    //should be in UTC to deal with a change in timezone.... unless that is handled under the hood.  dont care right now
                    if cachedObject.expirationDate > Date() {
                        if let returnObj = cachedObject.object as? T {
                            print("Found and returned good object for key: \(key)")
                            return returnObj;
                        } else {
                            NSObjectCache[key] = nil;
                            print("could not convert cached object to type \(T.self) for: \(key)")
                            return nil as T?;
                        }
                    } else {
                        NSObjectCache[key] = nil;
                        print("cache expired for key (removing now): \(key)")
                        return nil as T?;
                    }
                } else {
                    print("object does not exist in cache for key: \(key)")
                    return nil as T?;
                }
            }
        }
    }
    
    deinit {
        saveCacheToDisk()
    }
}

class CodableCacheObject : Codable {
    var key: String
    var expirationDate: Date
    var stringSerializedObject: String
    
    init (key: String, expirationDate:Date, stringSerializedObject: String) {
        self.key = key
        self.expirationDate = expirationDate
        self.stringSerializedObject = stringSerializedObject
    }
}

class NSCacheObjectList : NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool =  true
    
    var list: [NSCacheObject]
    
    init (list: [NSCacheObject]? = nil) {
        if list == nil {
            self.list = [NSCacheObject]()
        } else {
            self.list = list!
        }
        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        
        guard let items = aDecoder.decodeObject(forKey: "list") as? [NSCacheObject] else {
            return nil
        }
        
        self.init(list: items)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(list, forKey: "list")
    }
}

//WARNING: ALL nscache objects need to follow the NSObject, NSCoding standard in order to serialize properly.
//So why are we doing this?  Codable only works on amalgamations of primitive types, and swift can't serialize general AnyObjects yet, while NSObject can, provided you implement NSCoding (and images happen to serialize perfectly, as they already adhere to NSCoding).

class NSCacheObject : NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool = true
    
    var key: String
    var expirationDate: Date
    var object: AnyObject
    
    init (key: String, expirationDate:Date, object: AnyObject) {
        self.key = key
        self.expirationDate = expirationDate
        self.object = object
        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        guard let k = aDecoder.decodeObject(forKey: "key") as? String,
            let val = aDecoder.decodeObject(forKey: "object"),
            let expiry = aDecoder.decodeObject(forKey: "expirationDate") as? Date else {
                return nil
        }
        
        self.init(key: k, expirationDate: expiry, object: val as AnyObject)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(key, forKey: "key")
        aCoder.encode(expirationDate, forKey: "expirationDate")
        aCoder.encode(object, forKey: "object")
    }
}
