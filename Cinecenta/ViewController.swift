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
    private var noResultsLabel : UILabel?

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
            
            if self.today == nil && self.tomorrow == nil {
                self.tableView.backgroundView = self.noResultsLabel!
                self.tableView.separatorStyle = .none
            }
            else {
                self.tableView.backgroundView = nil
                self.tableView.separatorStyle = .singleLine
            }
        }
    }
    
    private func timerFired(_ timer: Timer) {
        refresh()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //  Setup header view
        let imageTopSpacing = CGFloat(10)
        guard let image = UIImage(named: "Cinecenta") else { fatalError() }
        let imageView = UIImageView(frame: CGRect(origin: CGPoint(x: 0, y: imageTopSpacing), size: CGSize(width: 100, height: image.size.height)))
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.translatesAutoresizingMaskIntoConstraints = true
        
        let headerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 100, height: image.size.height + imageTopSpacing)))
        headerView.addSubview(imageView)
        tableView.tableHeaderView = headerView
        
        //  Setup "empty" display
        noResultsLabel = UILabel()
        noResultsLabel!.text = "No Movies Showing"
        noResultsLabel!.font = UIFont.systemFont(ofSize: 22)
        noResultsLabel!.textAlignment = .center
        noResultsLabel!.sizeToFit()

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
        self.refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        shownURL = nil
    }
    
    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        scrapeSite(flushCache: true)
    }

    public func pause() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    public func refresh() {
        scrapeSite()
        
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: Date.tomorrow.timeIntervalSinceNow + 60 * 60 * 3 /* tomorrow + 3 hours */,
            repeats: false,
            block: timerFired)
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
        let imageURL = show["image"] as? String
        
        cell.textLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.headline)
        cell.textLabel?.text = title
        cell.detailTextLabel?.text = times
        cell.detailTextLabel?.font = UIFont.preferredFont(forTextStyle: UIFont.TextStyle.subheadline)
        if imageURL == nil {
            cell.imageView?.image = nil
        }
        else {
            cell.imageView?.contentMode = .scaleAspectFit
            cell.imageView?.hnk_setImageFromURL(URL(string: imageURL!)!, placeholder: UIImage(named: "Placeholder"))
        }
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

