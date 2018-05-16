//
//  HelperFunctions.swift
//  VKMusic
//
//  Created by Yaro on 2/23/18.
//  Copyright © 2018 Yaroslav Dukal. All rights reserved.
//

import Foundation

struct DocumentsDirectory {
    static let localDocumentsURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: .userDomainMask).last!
	static let localDownloadsURL = localDocumentsURL.appendingPathComponent("Downloads")
}

extension TrackListTableVC {
    
    func getLocalDownloadsURL() -> URL {
        return DocumentsDirectory.localDocumentsURL.appendingPathComponent("Downloads")
    }
    
    fileprivate func directoryExistsAtPath(_ path: String) -> Bool {
        var isDirectory = ObjCBool(true)
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    func localFilePathForUrl(_ previewUrl: String) -> URL? {
        if !directoryExistsAtPath(getLocalDownloadsURL().path) {
            do {
                try FileManager.default.createDirectory(at: getLocalDownloadsURL(), withIntermediateDirectories: false, attributes: nil)
            } catch let error as NSError { print(error.localizedDescription) }
        }
        return getLocalDownloadsURL().appendingPathComponent(((activeDownloads[previewUrl]?.fileName) ?? previewUrl))
    }
    
    // This method checks if the local file exists at the path generated by localFilePathForUrl(_:)
    func localFileExistsForTrack(_ track: Audio) -> Bool {
        var trackURLString = ""
        if track.url.hasSuffix(".mp3") || track.url.hasSuffix(".mp4") {
            trackURLString = track.url
        } else { //MAILRU IS MISSING .mp3 extension, adding it manually to avoid bugs
           trackURLString = track.url + ".mp3"
        }
        if let localUrl = localFilePathForUrl("\(track.title)_\(track.artist)_\(track.duration).mp\(trackURLString.hasSuffix(".mp3") ? "3" : "4")") {
            var isDir : ObjCBool = false
            let path = localUrl.path
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        }
        return false
    }
    
    func trackIndexForDownloadTask(_ downloadTask: URLSessionDownloadTask) -> Int? {
        if let url = downloadTask.originalRequest?.url?.absoluteString {
            for (index, track) in audioFiles.enumerated() {
                if url == track.url { return index }
            }
        }
        return nil
    }
	
//	func deleteFileFromRealm(url: String) {
//        let realm = try! Realm()
//        try! realm.write {
//            let trackToDelete = realm.objects(SavedAudio.self).filter("url == %@", url)
//            realm.delete(trackToDelete)
//        }
//	}
	
	func deleteSong(_ row: Int) {
		let track = audioFiles[row]
		if localFileExistsForTrack(track) {
            let filePath = getLocalDownloadsURL().appendingPathComponent("\(track.title)_\(track.artist)_\(track.duration).mp\(track.url.last ?? "3")")

			do {
				try FileManager.default.removeItem(at: filePath)
				if AudioPlayer.defaultPlayer.currentAudio != nil && AudioPlayer.defaultPlayer.currentAudio.duration == track.duration {
					AudioPlayer.defaultPlayer.kill()
					currentSelectedIndex = -1
					self.navigationController?.dismissPopupBar(animated: true, completion: nil)
				}
				//Delete From Realm
				CoreDataManager.shared.deleteAudioFile(withID: track.id)
				audioFiles.remove(at: row)
				tableView.reloadData()
				SwiftNotificationBanner.presentNotification("Deleted")
			} catch let error as NSError {
				print(error.debugDescription)
				SwiftNotificationBanner.presentNotification(error.localizedDescription)
			}
		}
	}
	
	func showActivityIndicator(withStatus status: String) {
		toolBarStatusLabel.text = status
		activityIndicator.startAnimating()
		navigationController?.setToolbarHidden(false, animated: true)
	}
	
	func hideActivityIndicator() {
		DispatchQueue.main.async {
			self.activityIndicator.stopAnimating()
			self.navigationController?.setToolbarHidden(true, animated: true)
		}
	}
}
