//
//  WHEPopoverMapViewController.swift
//  Whesit
//
//  Created by Admin on 24.07.17.
//  Copyright © 2017 Sergey Artemyev. All rights reserved.
//

import UIKit
import MapKit

struct Region {
    var centre: (Double,Double)
    var radius: Double
}

class WHEPopoverMapViewController: UIViewController {
    
    struct CurrentSelectedRegion {
        let map: MKMapView!
        var centerLatitude: Double {
            return self.map.region.center.latitude
        }
        var centerLongitude: Double {
            return self.map.region.center.longitude
        }
        var northEastLatitude: Double {
            return self.centerLatitude + self.map.region.span.latitudeDelta/2
        }
        var northEastLongitude: Double {
            return self.centerLongitude + self.map.region.span.longitudeDelta/2
        }
        var southWestLatitude: Double {
            return self.centerLatitude - self.map.region.span.latitudeDelta/2
        }
        var southWestLongitude: Double {
            return self.centerLongitude - self.map.region.span.longitudeDelta/2
        }
        var bounds: String {
            return String.init(format: "%f,%f|%f,%f", self.northEastLatitude, self.northEastLongitude, self.southWestLatitude, self.southWestLongitude)
        }
        var approximateRadius: Double {
            return self.map.region.span.latitudeDelta * 111//1 degree ~ 111km
        }
    }
    
    @IBOutlet weak var mapView: MKMapView!
    var currentRegion: CurrentSelectedRegion!
    var selectedRegion: Region?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.currentRegion = CurrentSelectedRegion.init(map: self.mapView)
        if let selectedRegion = selectedRegion {
            var region = MKCoordinateRegion()
            region.center.latitude = selectedRegion.centre.0
            region.center.longitude = selectedRegion.centre.1
            region.span.latitudeDelta = selectedRegion.radius / 111
            region.span.longitudeDelta = selectedRegion.radius / 111 / 1.5
            mapView.region = region
            print(mapView.region)
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Done" {
            //print(self.mapView!.region)
            let newVC = segue.destination as! WHEMainViewController
            newVC.chosenRegion = Region(centre: (currentRegion.centerLatitude, currentRegion.centerLongitude), radius: currentRegion.approximateRadius)
        }
    }
    

}
