//
//  WHEMainViewController.swift
//  Whesit
//
//  Created by Admin on 10.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import UIKit
import CoreData
import AFNetworking
import SDWebImage

//protocol for collectionView section data
protocol SectionData {
    var sectionName: String {get}  //header name
    var sectionPlaces: Array<RespondsForRequest> {get} //section data
}

extension Notification.Name {
    static let googleServicesIsUnreachable = Notification.Name("Google service is unreachable")
    static let googleServicesIsReachable = Notification.Name("Google service is reachable")
    //static let newDataHasBeenAdded = Notification.Name("New data has been loaded")
}
extension NSNotification.Name {
    static let newDataHasBeenAdded = NSNotification.Name("New data has been loaded")
}

private let reuseIdentifier = "Map Cell"
let numberOfElementsInRow: Int = 2
let collectionViewInsets: Int = 10
let pictureSize: Int = 640//max for free Google maps account

class WHEMainViewController: UICollectionViewController, UISearchBarDelegate, UICollectionViewDelegateFlowLayout {
    
    //data saved on device
    struct SectionFromDatabase: SectionData {
        init(_ request: Requests) {
            self.associatedRequest = request
        }
        let associatedRequest: Requests

        var sectionName: String {
            return self.associatedRequest.requestParameters ?? "No data"
        }
        var sectionPlaces: Array<RespondsForRequest> {
            if let array = self.associatedRequest.responds?.allObjects as? Array<RespondsForRequest> {
                let sortedArray = array.sorted(by: { (elem1, elem2) -> Bool in
                    if elem1.responseNumber > elem2.responseNumber {
                        return false
                    } else {
                        return true
                    }
                })
                return sortedArray
            } else {
                return Array()
            }
        }
    }
    struct SectionFromNetwork: SectionData {
        var associatedRequest: Requests? //data gotten from network can be saved in CoreData and tied with struct
        var sectionName: String
        var sectionPlaces: Array<RespondsForRequest> { //collection view will get data from here, when it is fully loaded
            let dataIsNotYetFull = self.temporaryArray.contains { (element) in
                if element == nil {
                    return true
                } else {
                    return false
                }
            }
            if dataIsNotYetFull {
                return Array()
            } else {
                return self.temporaryArray as! Array<RespondsForRequest>
            }
        }
        var temporaryArray: Array<RespondsForRequest?> //here data will be saved from net
        mutating func addNewEntry() {
            self.temporaryArray.append(nil)
        }
    }
    
    //from popover view to mainScreen
    @IBAction func unwindToMainScreen(sender: UIStoryboardSegue) {
        sender.source.dismiss(animated: true, completion: nil)
    }
    @IBAction func showPreviousData(_ sender: Any) {
        defer {self.collectionView!.reloadData()}
        _ = self.dataNumbersStack.popLast()
        if self.dataNumbersStack.isEmpty {
            data = self.loadDataFromCache(for: nil)
            self.navigationItem.setLeftBarButton(nil, animated: true)
        } else {
            data = Array(arrayLiteral: newData[self.dataNumbersStack.last!])
        }
    }
    
    @IBOutlet weak var backButton: UIBarButtonItem!
    let searchBar = UISearchBar()
    let moc: NSManagedObjectContext? = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.newBackgroundContext()
    let imageCacheManager: SDImageCache = SDImageCache.shared()
    let googleHandler: GoogleRequestsHandler = GoogleRequestsHandler()
    lazy var data: Array<SectionData> = self.loadDataFromCache(for: nil) //initial collectionView Data
    var newData: Array<SectionFromNetwork> = Array()
    var userResponseTimer: Timer? //timer for possible preloading results of searching
    var loadingInProgress: Bool = false
    var isOnline: Bool = true
    var saveAndLoadReady: Bool = true
    var observatorForCacheCleaning: NSObjectProtocol?
    var chosenRegion: Region? //object created when user narrows searchable region in popover map view
    var dataNumbersStack: [Int] = Array()

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //checking core data availability
        if self.moc == nil {
            self.noCoreData()
            self.saveAndLoadReady = false
            self.searchBar.isUserInteractionEnabled = false
        } else {
            //print("ok")
        }
        
        self.searchBar.delegate = self
        self.searchBar.placeholder = "Address, place, city..."
        self.navigationItem.titleView = self.searchBar
        imageCacheManager.maxCacheAge = 60 * 60 * 24 * 20 //20 days lasts any cached image, after which it is deleted
                
        //starts monitoring process for Google services
        let managerQueue: OperationQueue = (googleHandler.requestOperationManager.operationQueue)
        googleHandler.requestOperationManager.reachabilityManager.setReachabilityStatusChange({
            (status:AFNetworkReachabilityStatus) in
            switch status {
            case AFNetworkReachabilityStatus.reachableViaWiFi,
                 AFNetworkReachabilityStatus.reachableViaWWAN:
                managerQueue.isSuspended = false
                //print("host is reachable");
                self.isOnline = true
                self.navigationItem.rightBarButtonItem!.isEnabled = true
                NotificationCenter.default.post(Notification.init(name: .googleServicesIsReachable))
                break
            default:
                managerQueue.isSuspended = false
                //print("host is unreachable");
                self.isOnline = false
                self.navigationItem.rightBarButtonItem!.isEnabled = false
                NotificationCenter.default.post(Notification.init(name: .googleServicesIsUnreachable))
                break
            }
        })
        googleHandler.requestOperationManager.reachabilityManager.startMonitoring()
        
        //if there is a connection - removes old entries from cache in a new queue and proceeds to normal work, otherwise shows an alert view
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(unreachabilityAlertView),
                                               name: .googleServicesIsUnreachable,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(loadNewData(for:)),
                                               name: .newDataHasBeenAdded,
                                               object: nil)
        self.observatorForCacheCleaning = NotificationCenter.default.addObserver(
            forName: .googleServicesIsReachable,
            object: nil,
            queue: OperationQueue.init(),
            using: { (note: Notification) in
            self.perform(#selector(self.deleteExpiredDataFromCache))
            }
        )

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
    }
    //shows if there is no connection to Google
    func unreachabilityAlertView() {
        let unreachableAlert = UIAlertController.init(title: "Google service is unavailable", message: "Network problem", preferredStyle: UIAlertControllerStyle.alert)
        let unreachableAction = UIAlertAction.init(title: "Continue in offline mode", style: UIAlertActionStyle.cancel) { (UIAlertAction) in
        }
        unreachableAlert.addAction(unreachableAction)
        self.present(unreachableAlert, animated: true, completion: nil)
    }
    //shows in case of CoreData problems
    func noCoreData() {
        let databaseAlert = UIAlertController.init(title: "Database is unavailable", message: "Saved data can't be shown", preferredStyle: UIAlertControllerStyle.alert)
        let action = UIAlertAction.init(title: "Continue", style: UIAlertActionStyle.cancel) { (UIAlertAction) in
        }
        databaseAlert.addAction(action)
        self.present(databaseAlert, animated: true, completion: nil)
    }
    //cache cleaning
    func deleteExpiredDataFromCache() {
        defer {NotificationCenter.default.removeObserver(self.observatorForCacheCleaning!)}
        switch saveAndLoadReady {
        case true:
            let date = Date.init(timeIntervalSinceNow: -60 * 60 * 24 * 20) //20 days for Google rules
            let predicate = NSPredicate.init(format: "dateOfRequest < %@", argumentArray: [date])
            if let requestsArray = CoreDataHelper.fetchRequests(in: moc!, with: predicate) {
                for request in requestsArray {
                    self.moc!.delete(request)
                    //print("is deleted")
                }
                if ((try? self.moc!.save()) != nil) {
                    self.imageCacheManager.cleanDisk()
                    self.data = self.loadDataFromCache(for: nil)
                    self.collectionView!.reloadData()
                }
            }
        case false:
            break
        }
    }

    //MARK: - SearchBarMethods
    //when user texts some request, 2 sec timer starts which will load data for that request, if user changes request, timer is started over
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        userResponseTimer?.invalidate()
        self.userResponseTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(timeFireMethod), userInfo: nil, repeats: false)
    }   
    //if there are already loading in progress, search button will do nothing
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        defer {self.searchBar.resignFirstResponder()}
        switch loadingInProgress {
        case true:
            if self.newData.last?.sectionName == searchBar.text {
                break
            } else {
                self.load(self.searchBar.text!)
            }
        case false:
            self.userResponseTimer?.invalidate()
            self.load(self.searchBar.text!)
        }
    }
    func timeFireMethod(timer: Timer) {
        self.load(self.searchBar.text!)
    }
    
    //MARK: - Data loading
    func load(_ request: String) {
        if saveAndLoadReady {
            switch isOnline {
            case true:
                guard request != "" else {break} //don't request blank text
                self.makeRequestToGoogleMapsWith(address: request)
            case false:
                self.data = self.loadDataFromCache(for: request)
                self.collectionView!.reloadData()
            }
        } else {
            self.noCoreData()
        }
    }
    func loadDataFromCache(for request: String?) -> Array<SectionData> {
        var predicate: NSPredicate? = nil
        if request != nil && request != "" {
            predicate = NSPredicate.init(format: "requestParameters contains %@", argumentArray: [request!])
        }
        var data: Array<SectionFromDatabase> = Array()
        let cachedRequests = CoreDataHelper.fetchRequests(in: moc!, with: predicate)
        if let cache = cachedRequests {
            for request in cache {
                let section = SectionFromDatabase(request)
                data.append(section)
            }
        }
        data.reverse()
        return data
    }
    func makeRequestToGoogleMapsWith(address: String) {
        
        loadingInProgress = true
        let newSection = SectionFromNetwork(associatedRequest: nil, sectionName: address, temporaryArray: Array())
        self.newData.append(newSection)
        let index = newData.count - 1
        
        //Google returns a table of places for request (5 max), each of them then geocoded with another request.
        googleHandler.findPlaces(address, aroundPoint: chosenRegion?.centre, inRadius: chosenRegion?.radius, requestNumber: index)
        { (places, requestNumber) in
        var i = 0
        for place in places {
            self.newData[requestNumber!].addNewEntry() //illustrate how many new places are going to be shown
            self.googleHandler.geocode(place[FieldNames.description] as? String,
                                       numberOfRequest: requestNumber! * 10 + i,
                                       completion: { (geocode, numberOfRequest) in
                                        let index = numberOfRequest! % 10
                                        let requestNumber = (numberOfRequest! - index) / 10
                                        if let array = self.googleHandler.transmute(geocode, using: self.moc!, fromRequest: nil, requestNumber: index) {
                                          self.newData[requestNumber].temporaryArray.remove(at: index)
                                          self.newData[requestNumber].temporaryArray.insert(array[0], at: index)
                                            NotificationCenter.default.post(name: NSNotification.Name.newDataHasBeenAdded, object: nil, userInfo: ["forRequest": requestNumber])
                                       }})
            i += 1
        }}
    }
    func loadNewData(for notification: Notification) {
        let requestNumber = notification.userInfo!["forRequest"] as! Int
        let noDataYet = newData[requestNumber].sectionPlaces.isEmpty
        if !noDataYet {
            data = Array(arrayLiteral: newData[requestNumber])
            self.collectionView!.reloadData()
            self.dataNumbersStack.append(requestNumber)
            if CoreDataHelper.save(newData[requestNumber].sectionPlaces, forRequest: self.newData[requestNumber].sectionName, in: self.moc!) {
                print("ResultsSaved")
            }
            loadingInProgress = false
            if self.navigationItem.leftBarButtonItem == nil {
                self.navigationItem.setLeftBarButton(backButton, animated: true)
            }
        }
    }

    // MARK: - CollectionViewLayoutAndRotation
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (self.view.frame.size.width  - CGFloat.init(collectionViewInsets * (numberOfElementsInRow + 1))) / CGFloat(numberOfElementsInRow)
        let height = width * 4/3
        let cellSize = CGSize.init(width: width, height: height)
        return cellSize
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat.init(collectionViewInsets)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CGFloat.init(collectionViewInsets)
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let inset = CGFloat.init(collectionViewInsets)
        let edgeInsets = UIEdgeInsetsMake(inset, inset, inset, inset)
        return edgeInsets
    }
    //comment if there is no need for rotation
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.collectionView!.collectionViewLayout.invalidateLayout()
    }
    
    // MARK: - UICollectionViewDataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return data.count
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return data[section].sectionPlaces.count
    }
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! WHECollectionReusableView
        header.requestLabel.text = data[indexPath.section].sectionName
        return header
    }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! WHECollectionViewCell
        let dataForCell = data[indexPath.section].sectionPlaces[indexPath.row]
        cell.data = dataForCell
        cell.addressLabel.text = dataForCell.formattedAddress
        cell.addressLabel.adjustsFontSizeToFitWidth = true
        
        //loading images
        let imageURL = URL.init(string: dataForCell.imageURL ?? "")
        cell.mapImage.sd_setImageWithPreviousCachedImage(with: imageURL, placeholderImage: UIImage.init(named: "info"), options: SDWebImageOptions.lowPriority, progress: { (receivedSize: Int, expectedSize: Int) in
        }, completed: { (image: UIImage?, error: Error?, cacheType: SDImageCacheType, imageURL: URL?) in
        })

        return cell
    }
    
    // MARK: - Navigation
    // при переходе на экран карты AppleMaps, контроллеру передается объект, содержащий данные ответа от сервиса Google
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Details" {
            let cell = sender as! WHECollectionViewCell
            let newController = segue.destination as! WHEDetailedViewController
            newController.placeDescription = cell.data
        } else if segue.identifier == "SearchNarrower" {
            let newVC = segue.destination as! WHEPopoverMapViewController
            if let chosenRegion = chosenRegion {
                newVC.selectedRegion = chosenRegion
            }
        }
    }
    override func canPerformUnwindSegueAction(_ action: Selector, from fromViewController: UIViewController, withSender sender: Any) -> Bool {
        return true
    }
    
    // MARK: - UICollectionViewDelegate
    // Selected element will be highlighted for 3 seconds
    override func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        let cell = self.collectionView!.cellForItem(at: indexPath) as! WHECollectionViewCell
        cell.mapImage.alpha = 0.2
        return true
    }
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        let cell = self.collectionView!.cellForItem(at: indexPath) as! WHECollectionViewCell
        self.perform(#selector(changeMapImageTransparencyToFullFor(cell:)), with: cell, afterDelay: 3.0)
    }
    func changeMapImageTransparencyToFullFor(cell: WHECollectionViewCell) {
        cell.mapImage.alpha = 1.0
    }

    /*
    // Uncomment this method to specify if the specified item should be selected
    override func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    */

    /*
    // Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
    override func collectionView(_ collectionView: UICollectionView, shouldShowMenuForItemAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, canPerformAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        return false
    }

    override func collectionView(_ collectionView: UICollectionView, performAction action: Selector, forItemAt indexPath: IndexPath, withSender sender: Any?) {
    
    }
    */

}
