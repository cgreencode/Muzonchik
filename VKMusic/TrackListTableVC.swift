//
//  TrackListTableVC.swift
//  VKMusic
//
//  Created by Yaro on 2/23/18.
//  Copyright © 2018 Yaroslav Dukal. All rights reserved.
//

import UIKit
import BTNavigationDropdownMenu
import SwiftSoup
import LNPopupController
import SVProgressHUD
import RealmSwift

class TrackListTableVC: UITableViewController {
    
    //MARK: - Constants
    let searchController = UISearchController(searchResultsController: nil)
    //MARK: - Variables
    var barPlayButton: UIBarButtonItem?
    var currentSelectedIndex = -1
    var audioFiles = [Audio]()
    var filterAudios = [Audio]()
    var activeDownloads = [String: Download]()
    var isDownloadedListShown = false
    
    lazy var downloadsSession: Foundation.URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "bgSessionConfiguration")
        let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        return session
    }()

    //MARK: - viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDropdownMenu()
       
        NotificationCenter.default.addObserver(self, selector: #selector(playNextSong), name:NSNotification.Name(rawValue: "playNextSong"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playPreviousSong), name:NSNotification.Name(rawValue: "playPreviousSong"), object: nil)
        
        pullMusic()
    }
    
    @objc func playPreviousSong() {
        if currentSelectedIndex == 0 {
            currentSelectedIndex = audioFiles.count - 1
        } else {
            currentSelectedIndex = currentSelectedIndex - 1
        }
        let rowToSelect = NSIndexPath(row: currentSelectedIndex, section: 0)
        self.tableView.selectRow(at: rowToSelect as IndexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
        self.tableView(self.tableView, didSelectRowAt: rowToSelect as IndexPath)
    }
    
    @objc func playNextSong() {
        if currentSelectedIndex == (audioFiles.count - 1) {
            currentSelectedIndex = -1
        }
        let rowToSelect = NSIndexPath(row: currentSelectedIndex + 1, section: 0)
        self.tableView.selectRow(at: rowToSelect as IndexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
        self.tableView(self.tableView, didSelectRowAt: rowToSelect as IndexPath)
    }
    
    private func setupUI() {
        setupMimiMusicPlayerView()
        addRightBarButton()
        setupSearchBar()
        let backView = UIView(frame: self.tableView.bounds)
        backView.backgroundColor = .splashBlue
        self.tableView.backgroundView = backView
    }
    
    private func addRightBarButton() {
        let settingsButton = UIButton(frame: CGRect(x: 0, y: 0, width: 35, height: 35))
        settingsButton.addTarget(self, action: #selector(didTapSettingsButton), for: .touchUpInside)
        settingsButton.setImage(#imageLiteral(resourceName: "settings"), for: .normal)
        settingsButton.transform = CGAffineTransform(translationX: 15, y: 0)
        let settingsButtonContainer = UIView(frame: settingsButton.frame)
        settingsButtonContainer.addSubview(settingsButton)
        let rightBarButton = UIBarButtonItem(customView: settingsButtonContainer)
        self.navigationItem.rightBarButtonItem = rightBarButton
    }
    
    @objc func didTapSettingsButton() {
        self.presentViewControllerWithNavBar(identifier: "SettingsTableVC")
    }
    
    private func setupSearchBar() {
        // Setup the Search Controller
        if #available(iOS 9.1, *) {
            searchController.obscuresBackgroundDuringPresentation = false
        }
        searchController.searchBar.placeholder = "Search"
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            tableView.tableHeaderView = searchController.searchBar
            searchController.searchBar.barTintColor = .splashBlue
        }
        definesPresentationContext = true
        searchController.searchBar.isTranslucent = true
        searchController.searchBar.keyboardAppearance = .dark
        // Setup the Scope Bar
        searchController.searchBar.delegate = self
    }
    
    private func setupMimiMusicPlayerView() {
       
        UIProgressView.appearance(whenContainedInInstancesOf: [LNPopupBar.self]).tintColor = .red
       
        navigationController?.popupBar.tintColor = UIColor(white: 38.0 / 255.0, alpha: 1.0)
        navigationController?.popupBar.imageView.layer.cornerRadius = 5
        navigationController?.popupBar.barStyle = .default
        navigationController?.popupInteractionStyle = .drag
        navigationController?.popupBar.progressViewStyle = .top
        navigationController?.popupBar.barTintColor = .white
    }
        
    private func setupDropdownMenu() {
        let items = ["Music", "Downloads"]
        let menuView = BTNavigationDropdownMenu(navigationController: self.navigationController, containerView: self.navigationController!.view, title: BTTitle.title("Music"), items: items)
        menuView.cellSeparatorColor = .black
        menuView.cellHeight = 50
        menuView.cellBackgroundColor = .lightBlack
        menuView.cellSelectionColor = .lightBlack
        menuView.shouldKeepSelectedCellColor = false
        menuView.cellTextLabelColor = .white
        menuView.cellTextLabelFont = UIFont(name: "Avenir-Heavy", size: 15)
        menuView.cellTextLabelAlignment = .center 
        menuView.arrowPadding = 15
        menuView.animationDuration = 0.5
        menuView.maskBackgroundColor = .black
        menuView.maskBackgroundOpacity = 0.3
        menuView.didSelectItemAtIndexHandler = {(indexPath: Int) -> () in
            indexPath == 0 ? self.pullMusic() : self.displayDownloadedSongsOnly()
        }
        self.navigationItem.titleView = menuView

    }
    
    func displayDownloadedSongsOnly() {
        isDownloadedListShown = true
        currentSelectedIndex = -1
        
        let realm = try! Realm()
        let downloadedAudioFiles = realm.objects(SavedAudio.self)
        audioFiles.removeAll()
        for audio in downloadedAudioFiles {
            audioFiles.append(Audio(url: audio.url, title: audio.title, artist: audio.artist, duration: audio.duration))
        }
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func pullMusic() {
        currentSelectedIndex = -1
        isDownloadedListShown = false
        
        SVProgressHUD.show(withStatus: "Loading")
        GlobalFunctions.shared.urlToHTMLString(url: WEB_BASE_URL) { (htmlString, error) in
            if let error = error {
                print(error)
                DispatchQueue.main.async {
                    SwiftNotificationBanner.presentNotification(error)
                }
                SVProgressHUD.dismiss()
            }
            if let htmlString = htmlString {
                self.parseHTML(html: htmlString)
            }
        }
    }
    
    func searchMusic(tag: String) {
        currentSelectedIndex = -1
        isDownloadedListShown = false
        
        SVProgressHUD.show(withStatus: "Loading")
        GlobalFunctions.shared.urlToHTMLString(url: SEARCH_URL + "\(tag)") { (htmlString, error) in
            if let error = error {
                print(error)
                DispatchQueue.main.async {
                    SwiftNotificationBanner.presentNotification(error)
                }
                SVProgressHUD.dismiss()
            }
            if let htmlString = htmlString {
                self.parseHTML(html: htmlString)
            }
        }
    }
    
    func parseHTML(html: String) {
        let els: Elements = try! SwiftSoup.parse(html).select("li")
        audioFiles.removeAll()
        for element: Element in els.array() {
            if try! element.className() == "item x-track track" {
                let audioFile = Audio(withElement: element)
                audioFiles.append(audioFile)
            }
        }

        DispatchQueue.main.async {
            SVProgressHUD.dismiss()
            self.tableView.reloadData()
        }
    }
    
    func getAudioFromYouTubeURL(url: String) {
        SVProgressHUD.show(withStatus: "Processing ...")
        GlobalFunctions.shared.processYouTubeURL(url: url) { (audio, error) in
            SVProgressHUD.dismiss()
            if error == nil {
                guard let audio = audio else { return }
               
                self.audioFiles.removeAll()
                self.audioFiles.append(audio)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            } else {
                DispatchQueue.main.async {
                    SwiftNotificationBanner.presentNotification(error ?? "ERROR parsing video")
                }
                print(error ?? "")
            }
        }
    }

    func isFiltering() -> Bool {
        return searchController.isActive && !(searchController.searchBar.text ?? "").isEmpty && isDownloadedListShown
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return audioFiles.count
        //return isFiltering() ? filterAudios.count : audioFiles.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat(Float.ulpOfOne)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat(Float.ulpOfOne)
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return isDownloadedListShown
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteSong(indexPath.row)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackListTableViewCell", for: indexPath) as! TrackListTableViewCell
//        let audio: Audio
//        isFiltering() ? (audio = filterAudios[indexPath.row]) : (audio = audioFiles[indexPath.row])
//        cell.audioData = audio
//        cell.downloadData = activeDownloads[audio.url]
//        cell.checkMarkImageView.isHidden = !localFileExistsForTrack(audio)
        
        cell.delegate = self
        cell.audioData = audioFiles[indexPath.row]
        cell.downloadData = activeDownloads[audioFiles[indexPath.row].url]
        cell.checkMarkImageView.isHidden = !localFileExistsForTrack(audioFiles[indexPath.row])


        return cell
    }
    
   
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        var audio: Audio
//        isFiltering() ? (audio = filterAudios[indexPath.row]) : (audio = audioFiles[indexPath.row])
        
        let audio = audioFiles[indexPath.row]
        
        let popupContentController = storyboard?.instantiateViewController(withIdentifier: "MusicPlayerController") as! MusicPlayerController
        popupContentController.songTitle = audio.title
        popupContentController.albumTitle = audio.artist
        popupContentController.albumArt = #imageLiteral(resourceName: "artwork")
        popupContentController.trackDurationSeconds = audio.duration
        
        popupContentController.popupItem.title = audio.artist
        popupContentController.popupItem.subtitle = audio.title
        
        navigationController?.presentPopupBar(withContentViewController: popupContentController, animated: true, completion: nil)
        
        if currentSelectedIndex != indexPath.row {
            currentSelectedIndex = indexPath.row
            AudioPlayer.defaultPlayer.setPlayList(audioFiles)
            AudioPlayer.index = currentSelectedIndex
            
            //Mark that nothing isPlaying
            for i in 0..<audioFiles.count {
                audioFiles[i].isPlaying = false
            }
            if localFileExistsForTrack(audio) {
                let urlString = "\(audio.title)_\(audio.artist).mp\(audio.url.last ?? "3")"
                let url = localFilePathForUrl(urlString)
                audioFiles[indexPath.row].isPlaying = true
                AudioPlayer.defaultPlayer.playAudioFromURL(audioURL: url!)
            } else {
                let url = URL(string: audio.url)
                audioFiles[indexPath.row].isPlaying = true
                AudioPlayer.defaultPlayer.playAudio(fromURL: url)
            }
            DispatchQueue.main.async {
                tableView.reloadData()
            }
        }
    }

    
}

//MARK: - UISearchBar Delegate
extension TrackListTableVC: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBar.showsCancelButton = true
//        if isDownloadedListShown {
//            filterContentForSearchText(searchText)
//        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        //pullMusic()
//        if isDownloadedListShown {
//            self.displayDownloadedSongsOnly()
//        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
       // view.removeGestureRecognizer(tapRecognizer)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        if let searchText = searchBar.text {
            if searchText.hasPrefix("http") {
                getAudioFromYouTubeURL(url: searchText)
            } else {
                searchMusic(tag: searchText.lowercased())
            }
        }
    }
    
    func filterContentForSearchText(_ searchText: String) {
        filterAudios = audioFiles.filter({(audio : Audio) -> Bool in
            return audio.title.lowercased().contains(searchText.lowercased())
        })
        tableView.reloadData()
    }
}
