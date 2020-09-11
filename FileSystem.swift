//
//  FileSystem.swift
//  Created on 4/10/20.


import Foundation

struct FileSystem {
    
    static private let defaultCacheDataFileName = "objectCache.dat"
    
    static private func getCacheDirectory() -> URL {
        let cd = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("com.xyz.cache/", isDirectory: true)
        do {
            var isDirectory = ObjCBool(true)
            if !FileManager.default.fileExists(atPath: cd.path, isDirectory: &isDirectory) {
                try FileManager.default.createDirectory(atPath: cd.path, withIntermediateDirectories: true, attributes: nil)
                print("Created cache directory:  \(cd.path)")
            }
        } catch {
            print(error.localizedDescription)
        }
        return cd; //this could obviously fail, but we'd simply not be creating cache files properly rather than crash the app
    }
    
    static public func writeToCacheDirectory(data: Data, fileName: String = defaultCacheDataFileName) {
        let url = self.getCacheDirectory().appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            print("Wrote to cache file:  \(fileName)")
        } catch {
            print(error.localizedDescription)
        }
    }
    
    static public func readFromCacheDirectory(fileName: String = defaultCacheDataFileName) -> Data? {
        let url = self.getCacheDirectory().appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                print("Found cache file \(fileName), returning contents.")
                return try Data.init(contentsOf: url)
            } else {
                print("Could not find cache file:  \(fileName)")
                return nil;
            }
        } catch {
            print(error.localizedDescription)
            return nil;
        }
    }
    
    //honestly this clearcache function is shit - TODO: make it blow out the directory, and test the file array thing.
    static public func clearCacheDirectory(fileList:[String]? = nil) {
        var filesToDelete:[String] = [];
        if (fileList != nil && fileList!.count > 0) {
            for file in fileList! {
                let filePath = self.getCacheDirectory().appendingPathComponent(file).path
                if FileManager.default.fileExists(atPath: filePath)
                {
                    filesToDelete.append(file)
                }
            }
        } else {
            do {
                filesToDelete = try FileManager.default.contentsOfDirectory(atPath: self.getCacheDirectory().path)
            } catch {
                print(error.localizedDescription)
            }
        }
        
        if filesToDelete.isEmpty {
            print("FileSystem clearCache: no cache files found to remove!")
        } else {
            for file in filesToDelete
            {
                do {
                    try FileManager.default.removeItem(atPath: self.getCacheDirectory().appendingPathComponent(file).path)
                    print("Deleted cache file:  \(file)")
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}
