//
//  ViewController.swift
//  大文件断点续传
//
//  Created by 曾文志 on 19/02/2017.
//  Copyright © 2017 Lebron. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var request: URLRequest = {
        return URLRequest(url: URL(string: "http://olixskhpy.bkt.clouddn.com/brothers.jpg")!)
    }()
    
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var imageView: UIImageView!
    
    private lazy var session: URLSession = {
        // 创建会话相关配置
        let config = URLSessionConfiguration.background(withIdentifier: Constants.kDownload)
        // 在应用进入后台时，让系统决定决定是否在后台继续下载。如果是false，进入后台将暂停下载
        config.isDiscretionary = true

        // 创建一个可以在后台下载的session (其实会话的类型有四种形式)
        let session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
        return session
    }()
    private var task: URLSessionDownloadTask!
    private var resumeData: Data!
    private var currentTitle: String! {
        didSet {
            downloadButton.setTitle(currentTitle, for: .normal)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func startDownload(_ button: UIButton) {
        switch button.currentTitle! {
            
        case Constants.kStartDownload:
            currentTitle = Constants.kPauseDownload

            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            
            task = session.downloadTask(with: request)
            task.resume()
            
        case Constants.kPauseDownload:
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            currentTitle = Constants.kResumeDownload
            
            // 保存已经下载的位置
            task.cancel { (data) in
                self.resumeData = data
            }

        case Constants.kResumeDownload:
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            currentTitle = Constants.kPauseDownload
            
            // 重新建立一个下载任务，继续下载未完成的数据
            task = session.downloadTask(withResumeData: resumeData)
            task.resume()
            
        case Constants.kCompleteDownload:
            print("kCompleteDownload-----下载完成")
            
        default:
            break
        }
    }
}


// MARK: - URLSessionDownloadDelegate
extension ViewController: URLSessionDownloadDelegate {
    
    // 每下载完一部分调用，可能会调用多次
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        progressView.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        
        print(progressView.progress)
    }
    
    // 下载完成后调用
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 下载完成后，保存到缓存目录
        let destination = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).last! + "/" + downloadTask.response!.suggestedFilename!
        do {
            try FileManager.default.moveItem(atPath: location.path, toPath: destination)
        }
        catch {
            print(error.localizedDescription)
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false

        imageView.image = UIImage(contentsOfFile: destination)
        currentTitle = Constants.kCompleteDownload
        // 在后台下载完成，重新进入前台，把progress设置为1.0；如果不设置，progress的值是进入后台之前的值
        progressView.progress = 1.0
        session.invalidateAndCancel() // 下载完成，使session失效
    }
    
    // 任务完成时调用，但是不一定下载完成；用户点击暂停后，也会调用这个方法
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 如果下载任务可以恢复，那么NSError的userInfo包含了NSURLSessionDownloadTaskResumeData键对应的数据，保存起来，继续下载要用到
        guard error != nil, let data = (error! as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data else {
            return
        }

        resumeData = data
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        print("didResumeAtOffset-----恢复下载")
    }
}

private struct Constants {
    static let kDownload = "Download"
    static let kStartDownload = "开始下载"
    static let kPauseDownload = "暂停下载"
    static let kResumeDownload = "继续下载"
    static let kCompleteDownload = "下载完成"
}
