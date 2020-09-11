//
//  CacheService.swift
//
//  Created on 4/7/20.


import Foundation
import UIKit

//TODO:  test performance of dictionary vs. NSCache.  If we want to use NSCache, we'll have to somehow figure out how to serialize its contents.

class CacheService {
    
    public static let shared = CacheService();
    
    private let queue = DispatchQueue(label: "service.cache", attributes: .concurrent)

    private init() {
        loadCacheFromDisk()
    }

    private var ObjectCache = Dictionary<String, CacheObject>()
    
    func getCount() -> Int {
        return ObjectCache.count
    }
    
    func clearCache(memoryOnly: Bool = false) {
        ObjectCache = Dictionary<String, CacheObject>()
        print("Cleared memory cache.")
        if !memoryOnly {
            FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since most will most likely just keep the monolith cache system instance
        }
    }
    
    func saveCacheToDisk() {
        let diskcache = CacheObjectList()
        for (_, value) in self.ObjectCache {
            diskcache.list.append(value)
        }
        guard let objectCacheData = try? NSKeyedArchiver.archivedData(withRootObject: diskcache, requiringSecureCoding: false)
            else {
                print("Error archiving cache: Encoding of ObjectCache resulted in nil data.")
                return;
        }
        FileSystem.writeToCacheDirectory(data: objectCacheData)
    }
    
    public func loadCacheFromDisk() {
        if let loadedData = FileSystem.readFromCacheDirectory() {
            do {
                if let diskcache = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(loadedData) as? CacheObjectList {
                    print("Successfully unarchived ObjectCache: \(diskcache.list.count) items")
                    for entry in diskcache.list {
                        if entry.expirationDate > Date() {
                            ObjectCache[entry.key] = entry;
                        }
                    }
                    print("\(ObjectCache.count) items are now in ObjectCache (if count is lower than above, some items from archive may have expired).")
                } else {
                    print("Error: Could not unarchive ObjectCache from disk. Could not unarchive object, or archived object was null.")
                    FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since most will most likely just keep the monolith cache system instance
                }
            } catch {
                print("Error: Could not unarchive ObjectCache from disk. Error: \(error.localizedDescription)")
                FileSystem.clearCacheDirectory() //WARNING: should probably pass in file names so we dont blow out other specific caches, but leaving this for now, since most will most likely just keep the monolith cache system instance
            }
        }
    }
    
    //WARNING: ALL cache objects need to follow the NSObject, NSCoding standard in order to serialize properly.  
    
    func cacheObject(key: String, object: AnyObject, TTLInMinutes:Int? = nil)
    {
        var newTTL = TTLInMinutes
        if newTTL == nil {
            if object is UIImage {
                newTTL = 1440 //cache images for a day
            } else {
                newTTL = 10 //cache anything else for 10 minutes
            }
        }
        let cacheObj = CacheObject(key: key, expirationDate: Date().addingTimeInterval(TimeInterval(newTTL! * 60)), object: object as AnyObject)
        queue.sync(flags: .barrier) {
            self.ObjectCache[key] = cacheObj;
            print("cached data for: \(key)")
        }
    }
    
    func getObject<T>(for key:String) -> T? {
        queue.sync(flags: .barrier) {
            if let cachedObject = ObjectCache[key] {
                //should be in UTC to deal with a change in timezone.... unless that is handled under the hood?
                if cachedObject.expirationDate > Date() {
                    if let returnObj = cachedObject.object as? T {
                        print("Found and returned good object for key: \(key)")
                        return returnObj;
                    } else {
                        ObjectCache[key] = nil;
                        print("could not convert cached object to type \(T.self) for: \(key)")
                        return nil as T?;
                    }
                } else {
                    ObjectCache[key] = nil;
                    print("cache expired for key (removing now): \(key)")
                    return nil as T?;
                }
            } else {
                print("object does not exist in cache for key: \(key)")
                return nil as T?;
            }
        }
    }
    
    deinit {
        saveCacheToDisk()
    }
}

@objc(covid1) fileprivate class CacheObjectList : NSObject, NSCoding {
        
    var list: [CacheObject]
    
    init (list: [CacheObject]? = nil) {
        if list == nil {
            self.list = [CacheObject]()
        } else {
            self.list = list!
        }
        super.init()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        
        guard let items = aDecoder.decodeObject(forKey: "list") as? [CacheObject] else {
            return nil
        }
        
        self.init(list: items)
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(list, forKey: "list")
    }
}

//WARNING: ALL cache objects need to follow the NSObject, NSCoding standard in order to serialize properly.  

@objc(covid2) fileprivate class CacheObject : NSObject, NSCoding {
    
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
