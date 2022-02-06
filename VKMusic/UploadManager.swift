//
//  SessionDelegate.swift
//  test
//
//  Created by Yaro on 3/15/18.
//  Copyright © 2018 Yaro. All rights reserved.
//

import Foundation

@objc protocol UploadManagerDelegage: class {
	func didReceiveResponseJSON(_ json: [String: Any])
	func progress(progress: Float)
}

class UploadManager: NSObject, URLSessionDataDelegate {
	
	var data: Data!
	var urlRequest: URLRequest!
	var downloadURLString: String!
	weak var delegate: UploadManagerDelegage?
	

	init(uploadTaskWithData data: Data) {
		self.data = data
		let url = URL(string: "http://169.234.206.29:8080/upload/import.zip")
		self.urlRequest = URLRequest(url: url!)
		self.urlRequest.httpMethod = "POST"
		self.urlRequest.setValue("Keep-Alive", forHTTPHeaderField: "Connection")
		self.urlRequest.httpBodyStream = InputStream(data: data)
	}
	
	init(downloadTaskWithURLString url: String) {
		self.downloadURLString = url
	}
	
	func uploadFiles() {
		let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: OperationQueue.main)
		let task = session.uploadTask(with: urlRequest, from: data)
		task.resume()
	}
	
	func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
		let uploadProgress = Float(totalBytesSent) / Float(totalBytesExpectedToSend)
		delegate?.progress(progress: uploadProgress)
	}
	
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
		completionHandler(.allow)
	}
	
	func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
		do {
			if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
				//print(json)
				delegate?.didReceiveResponseJSON(json)
			}
		} catch {
			print("error")
		}
	}
}
