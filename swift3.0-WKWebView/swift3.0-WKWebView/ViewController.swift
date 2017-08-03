//
//  ViewController.swift
//  swift3.0-WKWebView
//
//  Created by ShuYan Feng on 2017/8/1.
//  Copyright © 2017年 Yan. All rights reserved.
//

import UIKit
import WebKit
import SnapKit
import Alamofire
import SwiftyJSON
import SVProgressHUD

let kScreen_width = UIScreen.main.bounds.size.width
let kScreen_height = UIScreen.main.bounds.size.height

class ViewController: UIViewController {

    // 设置webView的高
    var webContentHeight: CGFloat?
    // webview的scrollView
    var wbScrollView: UIScrollView?
    // 是否添加了观察者
    var isAddObserver = false
    // 评论的数据
    var commentData: [String]?
    
    // MARK: - life cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewConfig()
        request()
    }
    
    deinit {
        if isAddObserver {
            self.wbScrollView?.removeObserver(self, forKeyPath: "contentSize")
        }
    }
    
    // MARK: - private method
    func viewConfig() {
        self.title = "资讯详情"
        self.view.backgroundColor = UIColor.white
        view.addSubview(newsTableView)
        newsTableView.snp.makeConstraints { (make) in
            make.edges.equalTo(UIEdgeInsetsMake(0, 0, 0, 0))
        }
        newsTableView.isHidden = true
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "评论", style: .done, target: self, action: #selector(chickCommentDetail))
    }
    func request() {
        let url = "http://ticket.fenxianghulian.com/Mob/news/index.html?uid=296&news_id=792"
        let urlString = URL(string: url)
        let request = URLRequest(url: urlString!)
        newsWebView.load(request)
    }
    
    func loadCommentData() {
        let parameter = ["access_token": "4170fa02947baeed645293310f478bb4",
                         "method": "POST",
                         "news_id": "752",
                         "uid": "296"]
        Alamofire.request("http://ticket.fenxianghulian.com/api/commentList", method: .post, parameters: parameter, encoding: URLEncoding.default, headers: nil).responseJSON { (response) in
            switch response.result {
            case .success:
                let json = JSON(response.result.value!)
                // 获取code码
                let code = json["code"].intValue
                // 获取info信息
                let info = json["info"].stringValue
                if code == 400 {
                    SVProgressHUD.showError(withStatus: info)
                } else {
                    let dic = json.rawValue as? NSDictionary
                    self.commentData = dic?.value(forKey: "data") as? [String]
                }
            case .failure(let error):
                print(error)
            }
        }
    }
    
    // MARK: - event response
    func chickCommentDetail() {
        
        newsWebView.frame = CGRect(x: 0, y: 0, width: kScreen_width, height: webContentHeight ?? 0)
        newsTableView.reloadData()
        let oneIndex = IndexPath(row: 0, section: 0)
        self.newsTableView.scrollToRow(at: oneIndex, at: .top, animated: true)
    }

    // MARK: - setter and getter
    lazy var newsWebView: WKWebView = {
        let newsWebView = WKWebView(frame: CGRect(x: 0, y: 0, width: kScreen_width, height: kScreen_height))
        newsWebView.backgroundColor = UIColor.clear
        newsWebView.isOpaque = false
        newsWebView.uiDelegate = self
        newsWebView.navigationDelegate = self
        newsWebView.scrollView.isScrollEnabled = false
        newsWebView.scrollView.showsVerticalScrollIndicator = false
        
        return newsWebView
    }()

    lazy var newsTableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.register(CommentCell.self, forCellReuseIdentifier: "replyCell")
        
        
        return tableView
    }()
    
    // 监听 WKWebView
    // 获取高度
    func resetWebViewFrameWidthHeight(height: CGFloat) {
        // 如果是新高度，那就重置
        if height != webContentHeight {
            if height >= kScreen_height {
                newsWebView.frame = CGRect(x: 0, y: 0, width: kScreen_width, height: kScreen_height)
            } else {
                newsWebView.frame = CGRect(x: 0, y: 0, width: kScreen_width, height: height)
            }
            newsTableView.reloadData()
            webContentHeight = height
        }
    }
    // 监听
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // 根据内容的高度重置webview视图的高度
        let newHeight = wbScrollView?.contentSize.height
        resetWebViewFrameWidthHeight(height: newHeight!)
    }
    
}

extension ViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        SVProgressHUD.setDefaultMaskType(.none)
        SVProgressHUD.show(withStatus: "加载中")
        SVProgressHUD.dismiss(withDelay: 10)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        SVProgressHUD.dismiss()
        
        //这个方法也可以计算出webView滚动视图滚动的高度
        webView.evaluateJavaScript("document.body.scrollWidth") { (result, error) in
            
            let webViewW = result as! CGFloat
            let ratio = self.newsWebView.frame.width/webViewW
            
            webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (result, error) in
                
                let newHeight = (result as! CGFloat) * ratio
                self.resetWebViewFrameWidthHeight(height: newHeight)
                if newHeight < kScreen_height {
                    //如果webView此时还不是满屏，就需要监听webView的变化  添加监听来动态监听内容视图的滚动区域大小
                    self.wbScrollView?.addObserver(self, forKeyPath: "contentSize", options: NSKeyValueObservingOptions.new, context: nil)
                    self.isAddObserver = true
                }
            })
        }
        newsTableView.tableHeaderView = newsWebView
        wbScrollView = self.newsWebView.scrollView
        wbScrollView?.bounces = false
        wbScrollView?.isScrollEnabled = true
        newsTableView.isHidden = false
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "replyCell") as! CommentCell
        return cell
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isEqual(newsTableView) {
            
            let offsetY = scrollView.contentOffset.y
            if offsetY <= 0 {
                wbScrollView?.isScrollEnabled = true
                newsTableView.bounces = false
            } else {
                wbScrollView?.isScrollEnabled = false
                newsTableView.bounces = true
            }
        }
    }
}

