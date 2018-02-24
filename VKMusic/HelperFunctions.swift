//
//  HelperFunctions.swift
//  VKMusic
//
//  Created by Yaro on 2/23/18.
//  Copyright © 2018 Yaroslav Dukal. All rights reserved.
//

import Foundation
import RealmSwift

extension TrackListTableVC {
    
    func localFilePathForUrl(_ previewUrl: String) -> URL? {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        let fullPath = documentsPath.appendingPathComponent((activeDownloads[previewUrl]?.fileName) ?? previewUrl)
        return URL(fileURLWithPath:fullPath)
    }
    
    // This method checks if the local file exists at the path generated by localFilePathForUrl(_:)
    func localFileExistsForTrack(_ track: Audio) -> Bool {
        if let localUrl = localFilePathForUrl("\(track.title)\n\(track.artist).mp3") {
            var isDir : ObjCBool = false
            let path = localUrl.path
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        }
        return false
    }
    
    func trackIndexForDownloadTask(_ downloadTask: URLSessionDownloadTask) -> Int? {
        if let url = downloadTask.originalRequest?.url?.absoluteString {
            for (index, track) in audioFiles.enumerated() {
                if url == track.url! {
                    return index
                }
            }
        }
        return nil
    }
    
    func deleteSong(_ row: Int) {
        let track = audioFiles[row]
        
        if localFileExistsForTrack(track) {
            let realm = try! Realm()
            let fileToDelete = realm.objects(SavedAudio.self)
            
            let fileManager = FileManager.default
            let nsDocumentDirectory = FileManager.SearchPathDirectory.documentDirectory
            let nsUserDomainMask = FileManager.SearchPathDomainMask.userDomainMask
            let paths = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
            guard let dirPath = paths.first else { return }
            let filePath = String(describing: "\(dirPath)/\(track.title)\n\(track.artist).mp3")
            
            do {
                try fileManager.removeItem(atPath: filePath)
                try! realm.write({ () -> Void in
                    realm.delete(fileToDelete[row])
                })
                if AudioPlayer.defaultPlayer.currentAudio != nil && AudioPlayer.defaultPlayer.currentAudio == track {
                    AudioPlayer.defaultPlayer.kill()
                    self.navigationController?.dismissPopupBar(animated: true, completion: nil)
                }
                currentSelectedIndex = -1
            } catch let error as NSError {
                print(error.debugDescription)
            }
        }
        
        audioFiles.remove(at: row)
        tableView.reloadData()
        SwiftNotificationBanner.presentNotification("Deleted")
    }
}
