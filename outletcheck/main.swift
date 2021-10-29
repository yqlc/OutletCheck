//
//  main.swift
//  outletcheck
//
//  Created by 杨权 on 2019/10/10.
//  Copyright © 2019 VC. All rights reserved.
//

import Foundation

struct OCXMLResult {
    var name: String
    var properties: [String]
}

struct OCFileResult {
    var url: URL
    var xmls: [OCXMLResult]
}

func getAllFilePath(_ dirPath: String) -> [String] {
    var filePaths = [String]()
    
    if let array = FileManager.default.subpaths(atPath: dirPath) {
        for fileName in array {
            var isDir: ObjCBool = true
            
            let fullPath = "\(dirPath)/\(fileName)"
            
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir) {
                if !isDir.boolValue {
                    filePaths.append(fullPath)
                }
            }
        }
    }
    
    return filePaths
}

func collectOutletProperties(_ accessor: XML.Accessor) -> [String : Int] {
    var dict = [String : Int]()
    
    if let element = accessor.element {
        if element.name == "outlet" {
            if let property = element.attributes["property"] {
                if let num = dict[property] {
                    dict[property] = num + 1
                } else {
                    dict[property] = 1
                }
            }
        } else if !element.childElements.isEmpty {
            element.childElements.forEach {
                let results = collectOutletProperties(XML.Accessor($0))
                
                results.forEach({ (property, count) in
                    if let num = dict[property] {
                        dict[property] = num + count
                    } else {
                        dict[property] = count
                    }
                })
            }
        }
    } else {
        print("xxxxxxxxxxxxxxxxx")
    }
    
    return dict
}

func checkRepeatOutlet(_ accessor: XML.Accessor) -> [String] {
    var properties = [String]()
    let dict = collectOutletProperties(accessor)
    
    dict.forEach { (key, count) in
        if count > 1 {
            properties.append(key)
        }
    }
    
    return properties
}

func parseFiles(_ files: [URL]) {
    print("共找到：\(files.count)个文件")
//    print(files.map({ $0.path}).joined(separator: "\n"))
    print("")
    print("===========================================")
    print("====              开始检测             ====")
    print("===========================================")
    print("")
    
    var failedList = [URL]()
    var targetList = [OCFileResult]()
    
    files.forEach {
        if let data = try? Data(contentsOf: $0) {
            let xml = XML.parse(data)
            
            var results = [OCXMLResult]()
            if $0.pathExtension.lowercased() == "xib" {
                
                let objects = xml["document", "objects"]
                
                let values = checkRepeatOutlet(objects)
                if !values.isEmpty {
                    results.append(OCXMLResult(name: "xib", properties: values))
                }
                
            } else if $0.pathExtension.lowercased() == "storyboard" {
                let scenes = xml["document", "scenes", "scene"]
                
                if let all = scenes.all {
                    for (index, item) in all.enumerated() {
                        let values = checkRepeatOutlet(XML.Accessor(item)["objects"])
                        if !values.isEmpty {
                            let sId = item.attributes["sceneID"]
                            results.append(OCXMLResult(name: sId ?? "\(item.name)_\(index)", properties: values))
                        }
                    }
                }
            } else {
                failedList.append($0)
            }
            
            if !results.isEmpty {
                targetList.append(OCFileResult(url: $0, xmls: results))
            }
        } else {
            failedList.append($0)
        }
    }
    
    if targetList.isEmpty {
        print("没有检测到可疑文件")
    } else {
        print("检测到以下可疑文件:")
        targetList.forEach {
            print("文件路径: \($0.url.path)")
            $0.xmls.forEach({
                print("    场景: \($0.name) [\($0.properties.joined(separator: " | "))]")
            })
        }
    }
    
    print("")
    
    if !failedList.isEmpty {
        print("===========================================")
        print("====            华丽丽的分割           ====")
        print("===========================================")
        
        print("以下文件检测失败:")
        print(failedList.map({ $0.path}).joined(separator: "\n"))
        print("")
    }
    
    print("===========================================")
    print("====              执行完毕             ====")
    print("===========================================")
}

func startCheck(withPath path: String) {
    let fileManager = FileManager.default
    var isDir: ObjCBool = false
    
    if fileManager.fileExists(atPath: path, isDirectory: &isDir) {
        var files = [URL]()
        if isDir.boolValue {
            // 遍历文件夹，找出故事板和 xib 文件
            let list = getAllFilePath(path)
            files.append(contentsOf: list.compactMap({ (subPath) -> URL? in
                let url = URL(fileURLWithPath: subPath)
                if url.pathExtension.lowercased() == "storyboard"
                    || url.pathExtension.lowercased() == "xib" {
                    return url
                }
                return nil
            }))
        } else {
            let url = URL(fileURLWithPath: path)
            if url.pathExtension.lowercased() == "storyboard"
                || url.pathExtension.lowercased() == "xib" {
                files.append(url)
            }
        }
        
        if files.isEmpty {
            print("没有找到 Storyboard 或 Xib 文件")
        } else {
            parseFiles(files)
        }
    } else {
        print("路径不存在")
    }
}

var path = ""
if CommandLine.argc == 2 {
    path = CommandLine.arguments[1]
}

//path = "~/XXX/ProjectPath"
//path = "~/XXX/name.xib"
//path = "~/XXX/name.storyboard"

if (path.isEmpty) {
    print("参数错误")
} else {
    startCheck(withPath: path)
}


