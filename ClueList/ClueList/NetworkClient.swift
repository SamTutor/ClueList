//
//  NetworkClient.swift
//  ClueList
//
//  Created by Ryan Rose on 10/30/15.
//  Copyright © 2015 GE. All rights reserved.
//

import Alamofire
import SwiftyJSON

class NetworkClient: NSObject {
    
    // Method for invoking GET requests on API
    func taskForGETMethod(method: String, params: [String: AnyObject]?, completionHandler: (result: JSON!) -> Void) {
        // Build URL, configure request
        let urlString = Constants.API.BASE_URL + method
        
        Alamofire.request(.GET, urlString, parameters: params, encoding: ParameterEncoding.URL).responseJSON { response in
            switch response.result {
            case .Success(let data):
                let json = JSON(data)
                completionHandler(result: json)
            case .Failure(let error):
                print("Request failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Shared Instance
    
    class func sharedInstance() -> NetworkClient {
        struct Singleton {
            static var sharedInstance = NetworkClient()
        }
        return Singleton.sharedInstance
    }
}
