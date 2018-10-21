//
//  ViewController.swift
//  Cinecenta
//
//  Created by Mark Alldritt on 2018-10-16.
//  Copyright © 2018 Mark Alldritt. All rights reserved.
//

import UIKit
import SafariServices
import Haneke

class ViewController: UITableViewController {

    private var today: [[String:AnyObject]]?
    private var tomorrow: [[String:AnyObject]]?
    private var timer: Timer?
    private var shownURL: URL?

    deinit {
        timer?.invalidate()
    }
    
    private func scrapeSite(flushCache: Bool = false) {
        refreshControl?.beginRefreshing()
        AppDelegate.scrapeSite(flushCache: flushCache) { (today, tomorrow) in
            self.today = today
            self.tomorrow = tomorrow
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()

        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        timer = Timer.scheduledTimer(withTimeInterval: Date.tomorrow.timeIntervalSinceNow + 60 * 60 * 6 /* tomorrow + 3 hours */,
                                     repeats: false,
                                     block: { [unowned self] (timer) in
                                        self.scrapeSite()
                                        self.timer = Timer.scheduledTimer(withTimeInterval: 60 * 60 * 24, /* 1 day */
                                                                          repeats: true,
                                                                          block: { [unowned self] (timer) in
                                                self.scrapeSite()
                                        })
        })

        //  Configure pull-to-refresh
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(ViewController.handleRefresh(_:)), for: UIControl.Event.valueChanged)
        refreshControl = refresh
        
        //  Dynamic type
        //  A combination of these two URLs:
        //  https://useyourloaf.com/blog/static-tables-and-dynamic-type/
        //  https://forums.developer.apple.com/thread/90145
        tableView.estimatedRowHeight = 67
        NotificationCenter.default.removeObserver(tableView!, name: UIContentSizeCategory.didChangeNotification, object: nil)

        //  Populate the table
        scrapeSite()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        shownURL = nil
    }
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        scrapeSite(flushCache: true)
    }

    public func refresh() {
        scrapeSite()
    }
    
    public func show(key: String) {
        guard let aShow = showFor(key: key) else { return }
        
        show(show:aShow)
    }

    public func show(show: [String:AnyObject]) {
        print("show: \(show)")
        
        let url = URL(string:show["href"] as! String)!
        guard url != shownURL else { return }
        
        if shownURL != nil {
            presentedViewController?.dismiss(animated: false, completion: {
                let viewController = SFSafariViewController(url: url)
                
                self.present(viewController, animated: true, completion: nil)
            })
        }
        else {
            let viewController = SFSafariViewController(url: url)
            
            present(viewController, animated: true, completion: nil)
        }
        shownURL = url
    }

    private func showsForSection(section: Int) -> [[String:AnyObject]]? {
        switch section {
        case 0:
            if today != nil {
                return today
            }
            if tomorrow != nil {
                return tomorrow
            }
            return nil
            
        case 1:
            return tomorrow
            
        default:
            return nil
        }
    }
    
    private func showFor(indexPath: IndexPath) -> [String:AnyObject]? {
        guard let shows = showsForSection(section: indexPath.section) else { return nil }
        let show = shows[indexPath.row]
        
        return show
    }
    
    private func showFor(key: String) -> [String:AnyObject]? {
        if let today = today {
            for show in today {
                let title = show["title"] as! String
                let times = show["times"] as! String
                let showKey = "\(title).\(times)"
                
                if key == showKey {
                    return show
                }
            }
        }
        if let tomorrow = tomorrow {
            for show in tomorrow {
                let title = show["title"] as! String
                let times = show["times"] as! String
                let showKey = "\(title).\(times)"
                
                if key == showKey {
                    return show
                }
            }
        }

        return nil
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            tableView?.reloadData()
        }
    }

    //  MARK: - UITableViewDataSource
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        var sections = 0
        
        if today != nil {
            sections += 1
        }
        if tomorrow != nil {
            sections += 1
        }

        return sections
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            if today != nil {
                return "Today"
            }
            if tomorrow != nil {
                return "Tomorrow"
            }
            return nil
            
        case 1:
            return "Tomorrow"
            
        default:
            return nil
        }

    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let data = showsForSection(section: section) else { return 0 }
        
        return data.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SHOW")!
        guard let show = showFor(indexPath: indexPath) else { return cell }
        let title = show["title"] as! String
        let times = show["times"] as! String
        let imageURL = show["image"] as! String
        
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = times
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.hnk_setImageFromURL(URL(string: imageURL)!, placeholder: UIImage(named: "Placeholder"))
        cell.contentView.setNeedsLayout()
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    //  MARK: - UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let aShow = showFor(indexPath: indexPath) else { return }
        
        show(show: aShow)
    }
}

