//
//  BinaryFile.swift
//  Pwnground
//
//  Created by Bartłomiej Pluta
//

import Foundation

final class BinaryFile: NSObject, NSItemProviderWriting, NSItemProviderReading {
    static let dataUTI = "public.item"
    static var writableTypeIdentifiersForItemProvider: [String] { [BinaryFile.dataUTI] }
    
    var binaryData: Data
    
    init(binaryData: Data) {
        self.binaryData = binaryData
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        let progress = Progress(totalUnitCount: 1)
                
        DispatchQueue.global(qos: .userInitiated).async {
            progress.completedUnitCount = 1
            completionHandler(self.binaryData, nil)
        }
        return progress
    }
    
    static var readableTypeIdentifiersForItemProvider: [String] { [BinaryFile.dataUTI] }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> BinaryFile {
        BinaryFile(binaryData: data)
    }
}
