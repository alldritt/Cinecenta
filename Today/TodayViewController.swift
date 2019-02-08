//
//  TodayViewController.swift
//  Today
//
//  Created by Mark Alldritt on 2019-01-28.
//  Copyright © 2019 Mark Alldritt. All rights reserved.
//

import UIKit
import NotificationCenter
import Haneke


let cinecentaURL = URL(string: "https://www.latenightsw.com/mark/cinecenta.php")!


class TodayViewController: UIViewController, NCWidgetProviding, UITableViewDataSource, UITableViewDelegate {
    
    private var today: [[String:AnyObject]]?
    
    @IBOutlet weak var tableView: UITableView!
    
    private func centerTableView() {
        let contentSize = self.tableView.contentSize
        let boundsSize = self.view.bounds.size
        
        if contentSize.height < boundsSize.height {
            let yOffset = floor((boundsSize.height - contentSize.height) / 2)
            
            tableView.frame.origin = CGPoint(x: 0, y: yOffset)
        }
    }

    public func scrapeSite(flushCache: Bool = false, completionHandler: @escaping ([[String:AnyObject]]?, [[String:AnyObject]]?) -> Void) {
        let nextPollTimeKey = "nextPollTime"
        var flushCache = flushCache
        
        if !flushCache {
            //  See if the cached data has expired
            if let nextPollDate = UserDefaults.standard.object(forKey: nextPollTimeKey) as? Date {
                flushCache = Date() > nextPollDate
            }
        }
        if flushCache {
            Shared.JSONCache.remove(key: cinecentaURL.absoluteString)
        }
        Shared.JSONCache.fetch(URL: cinecentaURL).onSuccess { json in
            print("JSON: \(json)")
            
            let today = json.dictionary["today"] as? [[String:AnyObject]]
            let tomorrow = json.dictionary["tomorrow"] as? [[String:AnyObject]]
            
            UserDefaults.standard.set(Date.tomorrow, forKey: nextPollTimeKey)
            
            completionHandler(today, tomorrow)
        }
    }

    private func reload(_ flushCache: Bool = false) {
        scrapeSite(flushCache: flushCache) { (today, _) in
            self.today = today
            self.tableView.reloadData()
            self.tableView.setNeedsLayout()

            self.viewWillLayoutSubviews()
            
            //if self.today == nil && self.tomorrow == nil {
            //    self.tableView.backgroundView = self.noResultsLabel!
            //    self.tableView.separatorStyle = .none
            //}
            //else {
            //    self.tableView.backgroundView = nil
            //    self.tableView.separatorStyle = .singleLine
            //}
        }

    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 67
        tableView.isScrollEnabled = false

        NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        var frame = tableView.frame
        frame.size.height = self.tableView.contentSize.height
        tableView.frame = frame
        centerTableView()
    }
        
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        reload()
        completionHandler(NCUpdateResult.newData)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            tableView?.reloadData()
        }
    }
    
    //  MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return today?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "movieCell") else { fatalError() }
        
        cell.selectionStyle = .none
        
        if let today = today {
            let show = today[indexPath.row]
            let title = show["title"] as! String
            let times = show["times"] as! String
            let imageURL = show["image"] as? String
            
            cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
            cell.textLabel?.text = title
            cell.detailTextLabel?.text = times
            cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
            if imageURL == nil {
                cell.imageView?.image = nil
            }
            else {
                if cell.imageView?.bounds.size == .zero {
                    cell.imageView?.frame.size = CGSize(width: 106, height: 66)
                }
                cell.imageView?.contentMode = .scaleAspectFit
                cell.imageView?.hnk_setImageFromURL(URL(string: imageURL!)!, placeholder: UIImage(named: "Placeholder"))
            }
            cell.contentView.setNeedsLayout()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    //  MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let today = today else { return }
        let show = today[indexPath.row]
        guard let title = show["title"] as? String else { return }
        guard let times = show["times"] as? String else { return }
        let key = "\(title).\(times)"
        let urlComponents = NSURLComponents()
        urlComponents.scheme = "cinecenta"
        urlComponents.host = ""
        urlComponents.path = "/show"
        urlComponents.queryItems = [URLQueryItem(name: "key", value: key)]

        extensionContext?.open(urlComponents.url!, completionHandler: { (success) in
            print("completed: \(success ? "success" : "failure")")
        })
        
        print("show: \(show)")
    }

}
