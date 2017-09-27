//
//  WHEDetailedViewController.swift
//  Whesit
//
//  Created by Admin on 12.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import UIKit
import MapKit

class WHEDetailedViewController: UIViewController {
    
    var placeDescription: RespondsForRequest?//объект с описанием места
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //NSLog(@"%@",_placeDescription);
        
        //формирование отметки на карте
        var placeCoordinates = CLLocationCoordinate2D()
        placeCoordinates.latitude = placeDescription!.centerLatitude
        placeCoordinates.longitude = placeDescription!.centerLongitude
        let placePoint = MKPointAnnotation()
        placePoint.coordinate = placeCoordinates
        placePoint.title = "Address"
        placePoint.subtitle = placeDescription!.formattedAddress
        
        //настройка вида карты
        var selectedRegion = MKCoordinateRegion()
        selectedRegion.center = placeCoordinates
        selectedRegion.span = MKCoordinateSpanMake(placeDescription!.northEastLatitude - placeDescription!.southWestLatitude, placeDescription!.northEastLongitude - placeDescription!.southWestLongitude)
        mapView.addAnnotation(placePoint)
        mapView.setRegion(selectedRegion, animated: true)
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
