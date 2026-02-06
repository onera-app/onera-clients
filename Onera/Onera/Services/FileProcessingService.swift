//
//  FileProcessingService.swift
//  Onera
//
//  File processing for images, PDFs, and text files
//

import Foundation
import PDFKit
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
typealias PlatformImage = UIImage

// MARK: - UIImage Extension for Cross-Platform API

extension UIImage {
    nonisolated func resizedImage(to newSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

#elseif os(macOS)
import AppKit
typealias PlatformImage = NSImage

// MARK: - NSImage Extension for UIImage API Compatibility

extension NSImage {
    func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    func resizedImage(to newSize: CGSize) -> NSImage {
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: CGRect(origin: .zero, size: newSize),
                  from: CGRect(origin: .zero, size: self.size),
                  operation: .copy,
                  fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
#endif

// MARK: - Processed File

struct ProcessedFile: Sendable {
    let type: AttachmentType
    let data: String // Base64 encoded
    let mimeType: String
    let fileName: String
    let fileSize: Int
    let metadata: FileMetadata
}

struct FileMetadata: Sendable {
    var width: Int?
    var height: Int?
    var pageCount: Int?
    var extractedText: String?
}

// MARK: - Protocol

protocol FileProcessingServiceProtocol: Sendable {
    func processFile(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile
    func processImage(_ image: PlatformImage, fileName: String) async throws -> ProcessedFile
    func compressImage(_ data: Data, maxSizeMB: Double, maxDimension: Int) async throws -> Data
    func extractPDFText(_ data: Data) async throws -> (text: String, pageCount: Int)
    func validateFile(_ data: Data, mimeType: String) -> FileValidationResult
}

// MARK: - Validation Result

struct FileValidationResult {
    let isValid: Bool
    let error: String?
}

// MARK: - Errors

enum FileProcessingError: LocalizedError {
    case unsupportedType(String)
    case fileTooLarge(maxMB: Int)
    case processingFailed(String)
    case invalidImage
    case pdfExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedType(let type):
            return "Unsupported file type: \(type)"
        case .fileTooLarge(let maxMB):
            return "File too large. Maximum size is \(maxMB)MB"
        case .processingFailed(let reason):
            return "Failed to process file: \(reason)"
        case .invalidImage:
            return "Invalid image data"
        case .pdfExtractionFailed:
            return "Failed to extract text from PDF"
        }
    }
}

// MARK: - Constants

enum FileProcessingConstants: Sendable {
    nonisolated static let maxImageSize = 10 * 1024 * 1024 // 10MB
    nonisolated static let maxDocumentSize = 50 * 1024 * 1024 // 50MB
    nonisolated static let maxTextSize = 1 * 1024 * 1024 // 1MB
    nonisolated static let maxExtractedTextLength = 50000 // 50k chars
    
    nonisolated static let compressionMaxSizeMB: Double = 1.0
    nonisolated static let compressionMaxDimension = 2048
    nonisolated static let compressionQuality: CGFloat = 0.8
    
    nonisolated static let supportedImageTypes = [
        "image/jpeg",
        "image/png",
        "image/gif",
        "image/webp"
    ]
    
    nonisolated static let supportedDocumentTypes = [
        "application/pdf"
    ]
    
    nonisolated static let supportedTextTypes = [
        "text/plain",
        "text/markdown",
        "text/csv",
        "application/json",
        "text/html",
        "text/css",
        "text/javascript"
    ]
}

// MARK: - Implementation

final class FileProcessingService: FileProcessingServiceProtocol, @unchecked Sendable {
    
    // MARK: - Type Detection
    
    private func detectAttachmentType(mimeType: String) -> AttachmentType? {
        if FileProcessingConstants.supportedImageTypes.contains(mimeType) {
            return .image
        }
        if FileProcessingConstants.supportedDocumentTypes.contains(mimeType) ||
           FileProcessingConstants.supportedTextTypes.contains(mimeType) {
            return .file
        }
        return nil
    }
    
    // MARK: - Validation
    
    func validateFile(_ data: Data, mimeType: String) -> FileValidationResult {
        guard detectAttachmentType(mimeType: mimeType) != nil else {
            return FileValidationResult(isValid: false, error: "Unsupported file type: \(mimeType)")
        }
        
        let maxSize: Int
        if FileProcessingConstants.supportedImageTypes.contains(mimeType) {
            maxSize = FileProcessingConstants.maxImageSize
        } else if FileProcessingConstants.supportedDocumentTypes.contains(mimeType) {
            maxSize = FileProcessingConstants.maxDocumentSize
        } else {
            maxSize = FileProcessingConstants.maxTextSize
        }
        
        if data.count > maxSize {
            let maxMB = maxSize / (1024 * 1024)
            return FileValidationResult(isValid: false, error: "File too large. Maximum size is \(maxMB)MB")
        }
        
        return FileValidationResult(isValid: true, error: nil)
    }
    
    // MARK: - Process File
    
    func processFile(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile {
        let validation = validateFile(data, mimeType: mimeType)
        guard validation.isValid else {
            throw FileProcessingError.processingFailed(validation.error ?? "Unknown error")
        }
        
        guard detectAttachmentType(mimeType: mimeType) != nil else {
            throw FileProcessingError.unsupportedType(mimeType)
        }
        
        // Process based on type
        if FileProcessingConstants.supportedImageTypes.contains(mimeType) {
            return try await processImageData(data, fileName: fileName, mimeType: mimeType)
        } else if FileProcessingConstants.supportedDocumentTypes.contains(mimeType) {
            return try await processDocument(data, fileName: fileName, mimeType: mimeType)
        } else {
            return try await processTextFile(data, fileName: fileName, mimeType: mimeType)
        }
    }
    
    // MARK: - Image Processing
    
    func processImage(_ image: PlatformImage, fileName: String) async throws -> ProcessedFile {
        guard let imageData = image.jpegData(compressionQuality: FileProcessingConstants.compressionQuality) else {
            throw FileProcessingError.invalidImage
        }
        
        // Compress if needed
        let compressedData = try await compressImage(
            imageData,
            maxSizeMB: FileProcessingConstants.compressionMaxSizeMB,
            maxDimension: FileProcessingConstants.compressionMaxDimension
        )
        
        let metadata = FileMetadata(
            width: Int(image.size.width),
            height: Int(image.size.height)
        )
        
        return ProcessedFile(
            type: .image,
            data: compressedData.base64EncodedString(),
            mimeType: "image/jpeg",
            fileName: fileName,
            fileSize: compressedData.count,
            metadata: metadata
        )
    }
    
    private func processImageData(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile {
        guard let image = PlatformImage(data: data) else {
            throw FileProcessingError.invalidImage
        }
        
        // Compress the image
        let compressedData = try await compressImage(
            data,
            maxSizeMB: FileProcessingConstants.compressionMaxSizeMB,
            maxDimension: FileProcessingConstants.compressionMaxDimension
        )
        
        let metadata = FileMetadata(
            width: Int(image.size.width),
            height: Int(image.size.height)
        )
        
        return ProcessedFile(
            type: .image,
            data: compressedData.base64EncodedString(),
            mimeType: mimeType,
            fileName: fileName,
            fileSize: compressedData.count,
            metadata: metadata
        )
    }
    
    func compressImage(_ data: Data, maxSizeMB: Double, maxDimension: Int) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) {
            guard let image = PlatformImage(data: data) else {
                throw FileProcessingError.invalidImage
            }
            
            // Resize if needed
            let maxDim = CGFloat(maxDimension)
            let imageSize = image.size
            var processedImage = image
            
            if imageSize.width > maxDim || imageSize.height > maxDim {
                let scale: CGFloat
                if imageSize.width > imageSize.height {
                    scale = maxDim / imageSize.width
                } else {
                    scale = maxDim / imageSize.height
                }
                
                let newSize = CGSize(
                    width: imageSize.width * scale,
                    height: imageSize.height * scale
                )
                
                processedImage = image.resizedImage(to: newSize)
            }
            
            // Compress with decreasing quality until under size limit
            var quality: CGFloat = 0.8
            let maxBytes = Int(maxSizeMB * 1024 * 1024)
            
            while quality > 0.1 {
                if let compressed = processedImage.jpegData(compressionQuality: quality) {
                    if compressed.count <= maxBytes {
                        return compressed
                    }
                }
                quality -= 0.1
            }
            
            // Return whatever we can get at minimum quality
            guard let finalData = processedImage.jpegData(compressionQuality: 0.1) else {
                throw FileProcessingError.invalidImage
            }
            
            return finalData
        }.value
    }
    
    // MARK: - Document Processing
    
    private func processDocument(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile {
        let (text, pageCount) = try await extractPDFText(data)
        
        let metadata = FileMetadata(
            pageCount: pageCount,
            extractedText: text
        )
        
        return ProcessedFile(
            type: .file,
            data: data.base64EncodedString(),
            mimeType: mimeType,
            fileName: fileName,
            fileSize: data.count,
            metadata: metadata
        )
    }
    
    func extractPDFText(_ data: Data) async throws -> (text: String, pageCount: Int) {
        return try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(data: data) else {
                throw FileProcessingError.pdfExtractionFailed
            }
            
            let pageCount = document.pageCount
            var pages: [String] = []
            
            for i in 0..<pageCount {
                if let page = document.page(at: i),
                   let pageText = page.string {
                    pages.append("[Page \(i + 1)]\n\(pageText)")
                } else {
                    pages.append("[Page \(i + 1)]\n[Error reading page]")
                }
            }
            
            var text = pages.joined(separator: "\n\n")
            
            // Truncate if too long
            if text.count > FileProcessingConstants.maxExtractedTextLength {
                let endIndex = text.index(text.startIndex, offsetBy: FileProcessingConstants.maxExtractedTextLength)
                text = String(text[..<endIndex]) + "\n\n[Text truncated...]"
            }
            
            return (text, pageCount)
        }.value
    }
    
    // MARK: - Text File Processing
    
    private func processTextFile(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile {
        var text = String(data: data, encoding: .utf8) ?? ""
        
        // Truncate if too long
        if text.count > FileProcessingConstants.maxExtractedTextLength {
            let endIndex = text.index(text.startIndex, offsetBy: FileProcessingConstants.maxExtractedTextLength)
            text = String(text[..<endIndex]) + "\n\n[Content truncated...]"
        }
        
        let metadata = FileMetadata(extractedText: text)
        
        return ProcessedFile(
            type: .file,
            data: data.base64EncodedString(),
            mimeType: mimeType,
            fileName: fileName,
            fileSize: data.count,
            metadata: metadata
        )
    }
}

// MARK: - Mock Implementation

#if DEBUG
final class MockFileProcessingService: FileProcessingServiceProtocol, @unchecked Sendable {
    var shouldFail = false
    
    func processFile(_ data: Data, fileName: String, mimeType: String) async throws -> ProcessedFile {
        if shouldFail { throw FileProcessingError.processingFailed("Mock error") }
        return ProcessedFile(
            type: .image,
            data: data.base64EncodedString(),
            mimeType: mimeType,
            fileName: fileName,
            fileSize: data.count,
            metadata: FileMetadata()
        )
    }
    
    func processImage(_ image: PlatformImage, fileName: String) async throws -> ProcessedFile {
        if shouldFail { throw FileProcessingError.invalidImage }
        let data = image.jpegData(compressionQuality: 0.8) ?? Data()
        return ProcessedFile(
            type: .image,
            data: data.base64EncodedString(),
            mimeType: "image/jpeg",
            fileName: fileName,
            fileSize: data.count,
            metadata: FileMetadata(width: Int(image.size.width), height: Int(image.size.height))
        )
    }
    
    func compressImage(_ data: Data, maxSizeMB: Double, maxDimension: Int) async throws -> Data {
        return data
    }
    
    func extractPDFText(_ data: Data) async throws -> (text: String, pageCount: Int) {
        return ("Mock PDF content", 1)
    }
    
    func validateFile(_ data: Data, mimeType: String) -> FileValidationResult {
        return FileValidationResult(isValid: true, error: nil)
    }
}
#endif
