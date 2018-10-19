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

    private func scrapeSite(ignoreCache: Bool = true) {
        refreshControl?.beginRefreshing()
        if ignoreCache {
            Shared.JSONCache.remove(key: cinecentaURL.absoluteString) // force a reload!
        }
        Shared.JSONCache.fetch(URL: cinecentaURL).onSuccess { json in
            print("JSON: \(json)")
            
            self.today = json.dictionary["today"] as? [[String:AnyObject]]
            self.tomorrow = json.dictionary["tomorrow"] as? [[String:AnyObject]]
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        scrapeSite(ignoreCache: true)
    }

    @objc func handleRefresh(_ refreshControl: UIRefreshControl) {
        scrapeSite(ignoreCache: true)
    }

    public func refresh() {
        scrapeSite()
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
    
    private func showForIndexPath(indexPath: IndexPath) -> [String:AnyObject]? {
        guard let shows = showsForSection(section: indexPath.section) else { return nil }
        let show = shows[indexPath.row]
        
        return show
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
        guard let show = showForIndexPath(indexPath: indexPath) else { return cell }
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
        guard let show = showForIndexPath(indexPath: indexPath) else { return }
        let infoURL = show["href"] as! String

        print("selected show: \(show)")
        
        let viewController = SFSafariViewController(url: URL(string: infoURL)!)
        
        present(viewController, animated: true, completion: nil)
    }
}

