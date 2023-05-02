//
//  ContourDemoViewController.swift
//  ChartsDemo-macOS
//
//  Created by Steve Wainwright on 27/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

import Foundation
import Cocoa
import DGCharts
import KDTree

#if canImport(Quartz)
import Quartz
#endif

struct DataStructure: Equatable {
    var x: Double
    var y: Double
    var z: Double
}

struct ConvexHullPoint: Equatable {
    var point: CGPoint
    var index: Int
    
    static func == (lhs: ConvexHullPoint, rhs: ConvexHullPoint) -> Bool {
        return __CGPointEqualToPoint(lhs.point, rhs.point)
    }
}

struct ContourManagerRecord {
    var fillContours: Bool = false
    var extrapolateToARectangleOfLimits: Bool = true
    var krigingSurfaceInterpolation: Bool = true
    var krigingSurfaceModel : KrigingMode = .exponential
    var trig: Bool = false
    var functionLimits:[Double]?
    var firstResolution: Int = 64
    var secondaryResolution: Int = 512
    var plottitle: String = ""
    var functionExpression : ContourChartDataSetFieldBlock?
    var data: [DataStructure]?
}


class ContourDemoViewController: NSViewController, ChartViewDelegate, ContourChartViewDelegate, NSMenuDelegate {

    @IBOutlet var chartView: ContourChartView?
    @IBOutlet var changeButton: NSComboButton?
    @IBOutlet var pdfButton: NSButton?
    
    private var spinner: SpinnerView?
    private var message: String = "Generating the contour plot, please wait..."
    
    private var plotdata: [DataStructure] = []
    private var discontinuousData: [DataStructure] = []
    
    private var hull = Hull()
    
    private var minX = 0.0
    private var maxX = 0.0
    private var minY = 0.0
    private var maxY = 0.0
    private var minFunctionValue = 0.0
    private var maxFunctionValue = 0.0
    
    private var contourManagerCounter: Int = 5
    private var currentContour: ContourManagerRecord?
    private var contourManagerRecords: [ContourManagerRecord] = []
    
    private let piFormatter = PiNumberFormatter()
    private let regFormatter = DefaultAxisValueFormatter(decimals: 2)
        
    // MARK: - ViewController Life Cycle
        
    override func viewDidLoad() {
        super.viewDidLoad()
            
        contourManagerRecords.append(ContourManagerRecord(fillContours: true, trig: true, functionLimits: [-.pi, .pi, -.pi, .pi], firstResolution: 128, secondaryResolution: 2048, plottitle: "0.5(sin(x+π/4) + cos(y+π/4)", functionExpression: { (x: Double, y: Double) -> Double in return 0.5 * (cos(x + .pi / 4.0) + sin(y + .pi / 4.0)) }, data: nil))
        contourManagerRecords.append(ContourManagerRecord(fillContours: false, trig: false, functionLimits: [-3, 3, -3, 3], firstResolution: 128, secondaryResolution: 2048, plottitle: "log(2xy + x + y + 1)", functionExpression: { (x: Double, y: Double) -> Double in return log(2 * x * y + x + y + 1) }, data: nil))
        contourManagerRecords.append(ContourManagerRecord(fillContours: true, trig: false, functionLimits: [-3, 3, -3, 3], plottitle: "sin(√(x² + y²)) + 1 / √((x - 5)² + y²)", functionExpression: { (x: Double, y: Double) -> Double in return sin(sqrt(x * x + y * y)) + 1 / sqrt(pow(x - 5, 2.0) + y * y) }, data: nil))
        contourManagerRecords.append(ContourManagerRecord(fillContours: false, trig: false, functionLimits:  [-3, 3, -3, 3], plottitle: "xy/(x² + y²)", functionExpression: { (x: Double, y: Double) -> Double in return x * y / ( x * x + y * y) }, data: nil))
        contourManagerRecords.append(ContourManagerRecord(fillContours: false, trig: false, functionLimits:  [-1, 1, -1, 1], firstResolution: 64, secondaryResolution: 1024, plottitle: "(x³ - x²y + 9xy²) / (5x²y + 7y³)", functionExpression: { (x: Double, y: Double) -> Double in return (x * x * x - x * x * y + 9 * x * y * y) / (5 * x * x * y + 7 * y * y * y) }, data: nil))
        contourManagerRecords.append(ContourManagerRecord(fillContours: true, extrapolateToARectangleOfLimits: false, krigingSurfaceInterpolation: true, krigingSurfaceModel: .exponential, trig: false, functionLimits: [500, 500], plottitle: "Barametric Contours", functionExpression: nil, data:[
            DataStructure(x: 875.0, y: 3375.0, z: 632.0),
            DataStructure(x: 500.0, y: 4000.0, z: 634.0),
            DataStructure(x: 2250.0, y: 1250.0, z: 654.2),
            DataStructure(x: 3000.0, y: 875.0, z: 646.4),
            DataStructure(x: 2560.0, y: 1187.0, z: 641.5),
            DataStructure(x: 1000.0, y: 750.0, z: 650.0),
            DataStructure(x: 2060.0, y: 1560.0, z: 634.0),
            DataStructure(x: 3000.0, y: 1750.0, z: 643.3),
            DataStructure(x: 2750.0, y: 2560.0, z: 639.4),
            DataStructure(x: 1125.0, y: 2500.0, z: 630.1),
            DataStructure(x: 875.0, y: 3125.0, z: 638.0),
            DataStructure(x: 1000.0, y: 3375.0, z: 632.3),
            DataStructure(x: 1060.0, y: 3500.0, z: 630.8),
            DataStructure(x: 1250.0, y: 3625.0, z: 635.8),
            DataStructure(x: 750.0, y: 3375.0, z: 625.6),
            DataStructure(x: 560.0, y: 4125.0, z: 632.0),
            DataStructure(x: 185.0, y: 3625.0, z: 624.2)]))
        contourManagerRecords.append(ContourManagerRecord(fillContours: false, extrapolateToARectangleOfLimits: false, krigingSurfaceInterpolation: false, krigingSurfaceModel: .exponential, trig: false, functionLimits:  [10000, 10000], plottitle: "Elevation Contours", functionExpression: nil, data:[
            DataStructure(x: 1772721, y: 582282, z: -3547),
            DataStructure(x: 1781139, y: 585845, z: -3663),
            DataStructure(x: 1761209, y: 581803, z: -3469),
            DataStructure(x: 1761897, y: 586146, z: -3511),
            DataStructure(x: 1757824, y: 586542, z: -3474),
            DataStructure(x: 1759248, y: 593855, z: -3513),
            DataStructure(x: 1751962, y: 595979, z: -3488),
            DataStructure(x: 1748562, y: 600461, z: -3495),
            DataStructure(x: 1749475, y: 601824, z: -3545),
            DataStructure(x: 1748429, y: 612332, z: -3656),
            DataStructure(x: 1747542, y: 610708, z: -3631),
            DataStructure(x: 1752576, y: 610150, z: -3650),
            DataStructure(x: 1749236, y: 605604, z: -3612),
            DataStructure(x: 1777262, y: 614320, z: -3984),
            DataStructure(x: 1783097, y: 614590, z: -3928),
            DataStructure(x: 1788724, y: 614569, z: -3922),
            DataStructure(x: 1788779, y: 602482, z: -3928),
            DataStructure(x: 1783525, y: 602816, z: -3827),
            DataStructure(x: 1782876, y: 595479, z: -3805),
            DataStructure(x: 1790263, y: 601620, z: -3956),
            DataStructure(x: 1786390, y: 587821, z: -3748),
            DataStructure(x: 1772472, y: 591331, z: -3549),
            DataStructure(x: 1774055, y: 585498, z: -3580),
            DataStructure(x: 1771047, y: 582144, z: -3528),
            DataStructure(x: 1769765, y: 592200, z: -3586),
            DataStructure(x: 1784676, y: 602478, z: -3866),
            DataStructure(x: 1769118, y: 593814, z: -3606),
            DataStructure(x: 1774711, y: 589327, z: -3632),
            DataStructure(x: 1762207, y: 601476, z: -3666),
            DataStructure(x: 1767705, y: 611207, z: -3781),
            DataStructure(x: 1760792, y: 601961, z: -3653),
            DataStructure(x: 1768391, y: 602228, z: -3758),
            DataStructure(x: 1760453, y: 592626, z: -3441),
            DataStructure(x: 1786913, y: 605529, z: -3748),
            DataStructure(x: 1746521, y: 614853, z: -3654)]))
        contourManagerRecords.append(ContourManagerRecord(fillContours: true, extrapolateToARectangleOfLimits: true, krigingSurfaceInterpolation: true, krigingSurfaceModel: .exponential, trig: false, functionLimits:  [10, 10], firstResolution: 64, secondaryResolution: 1024, plottitle: "Kriging Contours", functionExpression: nil, data:[
            DataStructure(x: 134.170, y: 96.720, z:3.1),
            DataStructure(x: 131.430, y: 92.280, z:4.5),
            DataStructure(x: 116.900, y: 91.720, z:4.5),
            DataStructure(x: 133.280, y: 92.280, z:3.5),
            DataStructure(x: 127.720, y: 93.390, z:10.5),
            DataStructure(x: 123.810, y: 97.170, z:3.3),
            DataStructure(x: 125.870, y: 93.390, z:11.5),
            DataStructure(x: 128.180, y: 93.390, z:9.5),
            DataStructure(x: 132.400, y: 91.170, z:4.0),
            DataStructure(x: 127.720, y: 92.280, z:9.0),
            DataStructure(x: 133.210, y: 102.280, z:7.0),
            DataStructure(x: 131.440, y: 90.050, z:5.75),
            DataStructure(x: 133.280, y: 92.390, z:2.1),
            DataStructure(x: 120.590, y: 93.950, z:5.5),
            DataStructure(x: 132.360, y: 91.170, z:5.0),
            DataStructure(x: 115.220, y: 93.060, z:4.0),
            DataStructure(x: 143.860, y: 100.390, z:3.6),
            DataStructure(x: 112.210, y: 102.280, z:8.0),
            DataStructure(x: 141.590, y: 94.500, z:4.2),
            DataStructure(x: 119.210, y: 92.610, z:5.3),
            DataStructure(x: 119.110, y: 92.610, z:3.0),
            DataStructure(x: 116.900, y: 91.830, z:3.7),
            DataStructure(x: 111.920, y: 103.400, z:5.6),
            DataStructure(x: 112.180, y: 106.510, z:26),
            DataStructure(x: 128.370, y: 92.610, z:7.3),
            DataStructure(x: 121.460, y: 101.950, z:4.0),
            DataStructure(x: 116.810, y: 91.830, z:5.2),
            DataStructure(x: 128.460, y: 93.390, z:5.1),
            DataStructure(x: 128.600, y: 98.950, z:3.0),
            DataStructure(x: 132.550, y: 63.370, z:2.5),
            DataStructure(x: 133.520, y: 57.810, z:1.4),
            DataStructure(x: 130.470, y: 96.720, z:5.5),
            DataStructure(x: 129.570, y: 93.390, z:7.6),
            DataStructure(x: 120.120, y: 80.600, z:4.5),
            DataStructure(x: 112.490, y: 102.280, z:12.0),
            DataStructure(x: 124.900, y: 98.950, z:4.0),
            DataStructure(x: 120.680, y: 93.390, z:7.0),
            DataStructure(x: 133.240, y: 97.840, z:3.8),
            DataStructure(x: 131.420, y: 93.390, z:4.5),
            DataStructure(x: 124.640, y: 96.720, z:4.0),
            DataStructure(x: 124.730, y: 96.720, z:4.0),
            DataStructure(x: 116.990, y: 91.720, z:4.25),
            DataStructure(x: 131.420, y: 93.170, z:5.4),
            DataStructure(x: 122.720, y: 93.390, z:6.8),
            DataStructure(x: 129.790, y: 87.940, z:5.2),
            DataStructure(x: 128.270, y: 93.390, z:10.5)]))
        
        // Do any additional setup after loading the view.
        self.title = "Contour Chart"
        
        chartView?.chartDescription.enabled = false
        
        chartView?.dragEnabled = true
        chartView?.setScaleEnabled(true)
        chartView?.maxVisibleCount = 128 * 128
        chartView?.pinchZoomEnabled = true
        
        if let l = chartView?.legend {
            l.horizontalAlignment = .right
            l.verticalAlignment = .center
            l.orientation = .vertical
            l.drawInside = true
            l.font = .systemFont(ofSize: 14, weight: .light)
            l.xOffset = 20
        }
        
        self.piFormatter.multiplier = 16
    }
        
    override func viewWillAppear() {
        super.viewWillAppear()
        
        currentContour = contourManagerRecords[contourManagerCounter]
        
        if let _changeButton = self.changeButton {
            menuItemsUpdate(_changeButton.menu)
        }
        
        //        createNavigationButtons(view, target: self, actions: [#selector(scrollUpButton(_:)), #selector(scrollDownButton(_:)), #selector(scrollLeftButton(_:)), #selector(scrollRightButton(_:)), #selector(zoomInButton(_:)), #selector(zoomOutButton(_:))])
        //        setupConfigurationButtons()
        
        if self.spinner == nil {
            self.spinner = SpinnerView(frame: CGRect(x: self.view.frame.width / 2 - 100, y: self.view.frame.height / 2 - 100, width: 200, height: 200))
            if let _spinner = self.spinner {
                _spinner.translatesAutoresizingMaskIntoConstraints = false
                self.view.addSubview(_spinner)
                self.view.addConstraints([
                    NSLayoutConstraint(item: _spinner, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1.0, constant: 0.0),
                    NSLayoutConstraint(item: _spinner, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1.0, constant: 0.0),
                    NSLayoutConstraint(item: _spinner, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant: _spinner.bounds.size.width),
                    NSLayoutConstraint(item: _spinner, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 0.0, constant: _spinner.bounds.size.height)])
                showSpinner(completion: nil)
            }
        }
        changeContour(nil)
        chartView?.delegate = self
    }
        
    // MARK: - Setup Charts
        
    private func setupContour(noIsoCurves: Int = 9) -> ContourChartDataSet? {
        var contourChartDataSet: ContourChartDataSet?
        
        if let _chartView = self.chartView,
           let _currentContour = currentContour {
            createData()
            searchForLimits()
            let contourLimits = [ minX, maxX, minY, maxY ].map( { CGFloat($0) } )
            var deltaX = (maxX - minX) / 20.0
            var deltaY = (maxY - minY) / 20.0
            if !_currentContour.extrapolateToARectangleOfLimits && _currentContour.functionExpression == nil {
                if _currentContour.krigingSurfaceInterpolation { // in order to prevent any borders make extra 25% on all 4 sides
                    deltaX = (maxX - minX) / 4.0
                    deltaY = (maxY - minY) / 4.0
                }
                else {
                    deltaX = (maxX - minX) / 10.0
                    deltaY = (maxY - minY) / 10.0
                }
            }
            minX -= deltaX
            maxX += deltaX
            minY -= deltaY
            maxY += deltaY
            //            self.plotdata.sort { (a: DataStructure, b: DataStructure) -> Bool in
            //                return a.x < b.x
            //            }
            //            hull = Hull(concavity: .infinity)
            //            let _ = hull.hull(self.discontinuousData.map({ [$0.x, $0.y] }), nil)
            //            print(hull.hull)
            //
            //            let _/*continuousData*/ = self.plotdata.filter( {
            //                var have = true
            //                for i in 0..<discontinuousData.count {
            //                    if ( $0.x == discontinuousData[i].x && $0.y == discontinuousData[i].y ) {
            //                        have = false
            //                        break
            //                    }
            //                }
            //                return have
            //            })
            
            
            //            self.discontinuousData.sort { (a: DataStructure, b: DataStructure) -> Bool in
            //                return a.x < b.x
            //            }
            //            hull.concavity = 1.0
            //            let _ = hull.hull(self.discontinuousData.map({ [$0.x, $0.y] }), nil)
            //            let _ = hull.hull(continuousData.map({ [$0.x, $0.y] }), nil)
            //            for pt in hull.hull {
            //                if let _pt = pt as? [Double] {
            //                    print(_pt[0], ",", _pt[1])
            //                }
            //            }
            
            //  print(hull.hull)
            
            //            let _ = hull.hull(data.map({ [$0.x, $0.y]  }), nil)
            //            print("hull")
            //            for pt in hull.hull {
            //                if let _pt = pt as? [Double] {
            //                    print("\(_pt[0]), \(_pt[1])")
            //                }
            //            }
            
            //            let objcHull = _CPTHull(concavity: 5.0)
            //            var cgPoints = /*self.discontinuousData*/data.map({ CGPoint(x: $0.x, y: $0.y) })
            //
            //            let p = withUnsafeMutablePointer(to: &cgPoints[0]) { (p) -> UnsafeMutablePointer<CGPoint> in
            //                return p
            //            }
            //            objcHull.quickConvexHull(onViewPoints: p, dataCount:  UInt(/*self.discontinuousData*/data.count))
            //            print("convex")
            //            for point in UnsafeBufferPointer(start: objcHull.hullpointsArray(), count: Int(objcHull.hullpointsCount())) {
            //                print("\(point.point.x), \(point.point.y)")
            //            }
            
            //            objcHull.concaveHull(onViewPoints: p, dataCount: UInt(self.discontinuousData.count))
            //            for point in UnsafeBufferPointer(start: objcHull.hullpointsArray(), count: Int(objcHull.hullpointsCount())) {
            //                print(point)
            //            }
            //            objcHull.concavity = 2.0
            //            objcHull.concaveHull(onViewPoints: p, dataCount: UInt(/*self.discontinuousData*/data.count))
            //            print("objc")
            //            for point in UnsafeBufferPointer(start: objcHull.hullpointsArray(), count: Int(objcHull.hullpointsCount())) {
            ////                print(point)
            //                print("\(point.point.x), \(point.point.y)")
            //            }
            
            //            let boundaryPoints = quickHullOnPlotData(plotdata: self.plotdata)
            //            if !boundaryPoints.isEmpty {
            //                print(boundaryPoints)
            //            }
            //        }
            
            let ratio = _chartView.bounds.size.width / _chartView.bounds.size.height
            var xRange: Range, yRange: Range
            var granularity: Double, adjustedMax: Double = 0, adjustedMin: Double = 0, adjustedStep: Double = 0
            if ratio > 1 {
                let _ = Utilities.easyOnTheEyeScaling(fMin: minY, fMax: maxY, N: 11, valueMin: &adjustedMin, valueMax: &adjustedMax, step: &adjustedStep)
                yRange = Range(from: adjustedMin, to: adjustedMax)
                let _ = Utilities.easyOnTheEyeScaling(fMin: minX, fMax: maxX, N: Int(11.0 / ratio), valueMin: &adjustedMin, valueMax: &adjustedMax, step: &adjustedStep)
                xRange = Range(from: adjustedMin, to: adjustedMax)
                granularity = adjustedStep / 10
            }
            else {
                let _ = Utilities.easyOnTheEyeScaling(fMin: minX, fMax: maxX, N: 11, valueMin: &adjustedMin, valueMax: &adjustedMax, step: &adjustedStep)
                xRange = Range(from: adjustedMin, to: adjustedMax)
                let _ = Utilities.easyOnTheEyeScaling(fMin: minY, fMax: maxY, N: Int(11.0 / ratio), valueMin: &adjustedMin, valueMax: &adjustedMax, step: &adjustedStep)
                yRange = Range(from: adjustedMin, to: adjustedMax)
                granularity = adjustedStep / 10
            }
            
            // Axes
            if let leftAxis = chartView?.leftAxis {
                leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
                leftAxis.axisMinimum = yRange.minLimit
                leftAxis.axisMaximum = yRange.maxLimit
                if _currentContour.trig {
                    leftAxis.valueFormatter = self.piFormatter
                    leftAxis.granularity = .pi / 4
                }
                else {
                    leftAxis.valueFormatter = self.regFormatter
                    leftAxis.granularity = granularity
                }
                leftAxis.granularityEnabled = true
                leftAxis.labelPosition = .insideChart
                leftAxis.axisMaxLabels =  Int(floor(yRange.length / adjustedStep))
                leftAxis.forceLabelsEnabled = true
            }
            if let rightAxis = chartView?.rightAxis {
                rightAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
                rightAxis.axisMinimum = yRange.minLimit
                rightAxis.axisMaximum = yRange.maxLimit
                if _currentContour.trig {
                    rightAxis.valueFormatter = self.piFormatter
                    rightAxis.granularity = .pi / 4
                }
                else {
                    rightAxis.valueFormatter = self.regFormatter
                    rightAxis.granularity = granularity
                }
                rightAxis.labelPosition = .insideChart
                rightAxis.axisMaxLabels =  Int(floor(yRange.length / adjustedStep))
                rightAxis.forceLabelsEnabled = true
                chartView?.rightAxis.enabled = true
            }
            
            if let xAxis = chartView?.xAxis {
                xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
                if _currentContour.trig {
                    xAxis.valueFormatter = self.piFormatter
                }
                else {
                    xAxis.valueFormatter = self.regFormatter
                }
                xAxis.granularity = _currentContour.trig ? .pi / 4 : granularity
                xAxis.granularityEnabled = true
                xAxis.axisMinimum = xRange.minLimit
                xAxis.axisMaximum = xRange.maxLimit
                xAxis.labelPosition = .bothInsided
                xAxis.axisMaxLabels =  Int(floor(xRange.length / adjustedStep))
                xAxis.forceLabelsEnabled = true
            }
            
            
            // Contour properties
            if let _chartView = self.chartView,
                let xAxisValueFormatter = _chartView.xAxis.valueFormatter,
                let yAxisValueFormatter = _chartView.leftAxis.valueFormatter {
                
//                    let marker = ContourMarkerView(color: NSUIColor(white: 180/250, alpha: 1),
//                                                       font: .systemFont(ofSize: 12),
//                                                       textColor: .white,
//                                                       insets: NSEdgeInsets(top: 8, left: 8, bottom: 20, right: 8),
//                                                       xAxisValueFormatter: xAxisValueFormatter,
//                                                       yAxisValueFormatter: yAxisValueFormatter)
//                    marker.chartView = _chartView
//                    marker.minimumSize = CGSize(width: 80, height: 40)
//                    chartView?.marker = marker
//
                var dataSet = ContourChartDataSet(label: _currentContour.plottitle)
                
                dataSet.noColumnsFirst =  _currentContour.firstResolution
                dataSet.noRowsFirst =  _currentContour.firstResolution
                dataSet.noColumnsSecondary = _currentContour.secondaryResolution
                dataSet.noRowsSecondary = _currentContour.secondaryResolution
                if _currentContour.functionExpression != nil {
                    dataSet.identifier = "function"
                }
                else {
                    dataSet.identifier = "data"
                    
                }
                dataSet.interpolationMode = .linear
                dataSet.cubicInterpolation = .normal
                dataSet.catmullCustomAlpha = 0.7
                
                dataSet.alignsPointsToPixels = true
                dataSet.noIsoCurves = noIsoCurves
                dataSet.functionPlot = _currentContour.functionExpression != nil
                dataSet.minFunctionValue = minFunctionValue
                dataSet.maxFunctionValue = maxFunctionValue
                dataSet.limits = contourLimits
                dataSet.extrapolateToLimits = _currentContour.extrapolateToARectangleOfLimits
                dataSet.fillIsoCurves = _currentContour.fillContours
                dataSet.easyOnTheEye = true
                
                dataSet.isoCurvesLineWidth = 3
                dataSet.isoCurvesLineColour = .blue
                
                dataSet.isoCurvesLabelFont = .systemFont(ofSize: 14.0, weight: .light)
                dataSet.isoCurvesLabelTextColor = .black
                let labelFormatter = NumberFormatter()
                labelFormatter.maximumFractionDigits = 2
                dataSet.isoCurvesLabelFormatter = labelFormatter
                
                if let identifier = dataSet.identifier,
                    identifier == "data" {
                    currentContour?.functionLimits = [ minX , maxX, minY, maxY ]
                    dataSet.limits = [ minX , maxX, minY, maxY ]
                    let values = self.plotdata.map { ChartDataEntry(x: $0.x , y: $0.y, data: $0.z) }
                    dataSet.replaceEntries(values)
                    dataSet.fieldBlock = setupContoursForInterpolation(dataSet: &dataSet, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
                }
                else {
                    let values = self.plotdata.map { ChartDataEntry(x: $0.x , y: $0.y, data: $0.z) }
                    dataSet.replaceEntries(values)
                    dataSet.fieldBlock = { xValue, yValue in
                        var functionValue: Double = Double.greatestFiniteMagnitude
                        do {
                            functionValue = try self.calculateFunctionValueAtXY(xValue, y: yValue)
                        }
                        catch let exception as NSError {
                            print("An exception occurred: \(exception.localizedDescription)")
                            print("Here are some details: \(String(describing: exception.localizedFailureReason))")
                        }
                        return functionValue
                    }
                }
                    
                contourChartDataSet = dataSet
            }
            
//            if let _ = _currentContour.functionExpression {
//                self.toggleExtrapolateToLimitsRectangleButton?.isEnabled = false
//                self.chooseSurfaceInterpolationMethodButton?.isEnabled = false
//            }
//            else {
//                self.toggleExtrapolateToLimitsRectangleButton?.isEnabled = true
//                self.chooseSurfaceInterpolationMethodButton?.isEnabled = true
//            }
        }
        return contourChartDataSet
    }
        
    private func createData() {
        // clean up old data
        if self.plotdata.count > 0 {
            self.plotdata.removeAll()
        }
        if let _currentContour = currentContour {
            if let _ = _currentContour.functionExpression {
                do {
                    try generateInitialFunctionData()
                    if !discontinuousData.isEmpty {
                        let outerDiscontinuousPoints = quickHullOnPlotData(plotdata: discontinuousData)
                        print(outerDiscontinuousPoints)
                    }
                }
                catch let error as NSError {
                    print("Error: \(error.localizedDescription)")
                    print("Error: \(String(describing: error.localizedFailureReason))")
                }
            }
            else if let _data = _currentContour.data {
                for i in 0..<_data.count {
                    self.plotdata.append(_data[i])
                }
            }
        }
    }
        
    private func searchForLimits() {
        if let _currentContour = currentContour,
            _currentContour.functionExpression != nil,
            let _functionLimits = _currentContour.functionLimits {
            minX = _functionLimits[0]
            maxX = _functionLimits[1]
            minY = _functionLimits[2]
            maxY = _functionLimits[3]
        }
        else {
            if let _minX = self.plotdata.map({ $0.x }).min() {
                minX = _minX
            }
            if let _maxX = self.plotdata.map({ $0.x }).max() {
                maxX = _maxX
            }
            if let _minY = self.plotdata.map({ $0.y }).min() {
                minY = _minY
            }
            if let _maxY = self.plotdata.map({ $0.y }).max() {
                maxY = _maxY
            }
        }
        if let _minFunctionValue = self.plotdata.map({ $0.z }).min() {
            minFunctionValue = _minFunctionValue
        }
        if let _maxFunctionValue = self.plotdata.map({ $0.z }).max() {
            maxFunctionValue = _maxFunctionValue
        }
    }
        
    private func setupContoursForInterpolation(dataSet: inout ContourChartDataSet, minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) -> ContourChartDataSetFieldBlock? {
        var fieldBlock: ContourChartDataSetFieldBlock?
        if var _currentContour = currentContour {
            
            // use delaunay triangles to extrapolate to rectangle limits
            var vertices: [Point] = []
            var index = 0
            for entry in dataSet.entries {
                var point = Point(x: entry.x, y: entry.y)
                point.value = entry.data as! Double
                point.index = index
                vertices.append(point)
                index += 1
            }
            
            let tree: KDTree<Point> = KDTree(values: vertices)
            if _currentContour.extrapolateToARectangleOfLimits {
                let edgePoints = [Point(x: minX, y: minY), Point(x: minX, y: (minY + maxY) / 3.0), Point(x: minX, y: (minY + maxY) * 2.0 / 3.0), Point(x: minX, y: maxY), Point(x: (minX + maxX) / 3.0, y: maxY), Point(x: (minX + maxX) * 2.0 / 3.0, y: maxY), Point(x: maxX, y: minY), Point(x: maxX, y: (minY + maxY) / 3.0), Point(x: maxX, y: (minY + maxY) * 2.0 / 3.0), Point(x: maxX, y: maxY), Point(x: (minX + maxX) / 3.0, y: minY), Point(x: (minX + maxX) * 2.0 / 3.0, y: minY)]
                
                for var point in edgePoints {
                    if !vertices.contains(point) {
                        let nearestPoints: [Point] = tree.nearestK(2, to: point)
                        point.value = TriangleInterpolation.triangle_extrapolate_linear_singleton( p1: [nearestPoints[0].x, nearestPoints[0].y], p2: [nearestPoints[1].x, nearestPoints[1].y], p: [point.x, point.y], v1: nearestPoints[0].value, v2: nearestPoints[1].value)
                        point.index = index
                        vertices.append(point)
                        index += 1
                    }
                }
            }
            
            if _currentContour.krigingSurfaceInterpolation {
                var knownXPositions: [Double] = self.plotdata.map({ $0.x })
                var knownYPositions: [Double] = self.plotdata.map({ $0.y })
                var knownValues: [Double] = self.plotdata.map({ $0.z })
                // include edges
                knownXPositions += vertices[self.plotdata.count..<vertices.count].map({ $0.x })
                knownYPositions += vertices[self.plotdata.count..<vertices.count].map({ $0.y })
                knownValues += vertices[self.plotdata.count..<vertices.count].map({ $0.value })
                let kriging: Kriging = Kriging()
                kriging.train(t: knownValues, x: knownXPositions, y: knownYPositions, model: _currentContour.krigingSurfaceModel, sigma2: 1.0, alpha: 10.0)
                if kriging.error == KrigingError.none {
                    fieldBlock = generateInterpolatedDataForContoursUsingKriging(kriging: kriging)
                }
                else {
                    _currentContour.krigingSurfaceInterpolation = false
                }
            }
            if !_currentContour.krigingSurfaceInterpolation {
                let triangles = Delaunay().triangulate(vertices) // Delauney uses clockwise ordered nodes
                fieldBlock = generateInterpolatedDataForContoursUsingDelaunay(triangles: triangles)
            }
        }
        return fieldBlock
    }
        
    private func generateInterpolatedDataForContoursUsingDelaunay(triangles:[Triangle]) -> ContourChartDataSetFieldBlock? {
        return { xValue, yValue in
            var functionValue: Double = 0 // Double.nan // such that if x,y outside triangle returns nonsnese
            let point = Point(x: xValue, y: yValue)
            for triangle in triangles {
                if triangle.contain(point) {
                    let v = TriangleInterpolation.triangle_interpolate_linear( m: 1, n: 1, p1: [triangle.point1.x, triangle.point1.y], p2: [triangle.point2.x, triangle.point2.y], p3: [triangle.point3.x, triangle.point3.y], p: [xValue, yValue], v1: [triangle.point1.value], v2: [triangle.point2.value], v3: [triangle.point3.value])
                    functionValue = v[0]
                    break
                }
            }
            return functionValue
        }
    }
        
    private func generateInterpolatedDataForContoursUsingKriging(kriging: Kriging) -> ContourChartDataSetFieldBlock? {
        return { xValue, yValue in
            return kriging.predict(x: xValue, y: yValue)
        }
    }
        
    private func generateFunctionDataForContours() throws -> ContourChartDataSetFieldBlock? {
        return { xValue, yValue in
            var functionValue: Double = Double.greatestFiniteMagnitude
            do {
                functionValue = try self.calculateFunctionValueAtXY(xValue, y: yValue)
            }
            catch let exception as NSError {
                print("An exception occurred: \(exception.localizedDescription)")
                print("Here are some details: \(String(describing: exception.localizedFailureReason))")
            }
            return functionValue
            
        }
    }
        
    private func generateInitialFunctionData() throws -> Void {
        if let _currentContour = self.currentContour,
            let functionLimits = _currentContour.functionLimits,
            functionLimits.count == 4 && functionLimits[0] < functionLimits[1] && functionLimits[2] < functionLimits[3] {
            var _y: Double = functionLimits[2]
            let increment: Double = (functionLimits[1] - functionLimits[0]) / 32.0
            while _y < functionLimits[3] + increment - 0.000001 {
                var _x: Double = functionLimits[0]
                while _x < functionLimits[1] + increment - 0.000001 {
                    do {
                        let _z = try calculateFunctionValueAtXY(_x, y: _y)
                        let data = DataStructure(x: _x, y: _y, z: _z)
                        if _z.isNaN || _z.isInfinite /*_z == Double.greatestFiniteMagnitude || _z == -Double.greatestFiniteMagnitude*/ {
                            self.discontinuousData.append(data)
                        }
                        else {
                            self.plotdata.append(data)
                        }
                        _x += increment
                    }
                    catch let error as NSError {
                        print("An exception occurred: \(error.domain)")
                        print("Here are some details: \(String(describing: error.code)), \(error.localizedDescription)")
                        throw error
                    }
                }
                _y += increment
            }
        }
    }
        
    private func calculateFunctionValueAtXY(_ x: Double, y: Double) throws -> Double {
        if let _currentContour = self.currentContour,
           let functionExpression = _currentContour.functionExpression {
            return functionExpression(x, y)
        }
        else {
            return -0
        }
    }
        
        // MARK: - Options actions
    @IBAction func changeContour(_ sender: Any?) {
        var noIsoCurves: Int = 6
        if let _chartView = self.chartView {
            if let _contourData = _chartView.contourData,
               let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
               let oldContour = _dataSets.first(where: { $0.identifier == (self.currentContour?.functionExpression == nil ? "data" : "function") } ) {   // should only be one contour set per chart!!
                
                contourManagerCounter += 1
                if contourManagerCounter >= contourManagerRecords.count {
                    contourManagerCounter = 0
                }
                currentContour = contourManagerRecords[contourManagerCounter]
                
                noIsoCurves = oldContour.noIsoCurves
                if let newContour = setupContour(noIsoCurves: noIsoCurves) {
                    self.chartView?.data?.dataSets.remove(object: oldContour)
                    if let l = chartView?.legend {
                        l.resetCustom()
                    }
                    showChart(newContour, renewal: true)
                }
            }
            else {
                if let newContour = setupContour(noIsoCurves: noIsoCurves) {
                    showChart(newContour, renewal: false)
                }
            }
        }
    }
    
    private func showChart(_ newContour: ContourChartDataSet, renewal: Bool) {
        if let _currentContour = self.currentContour {
            if let _ /*spinner*/ = self.spinner {
                showSpinner() { _ in
                    newContour.fillIsoCurves = _currentContour.fillContours
                    newContour.drawIsoCurvesLabelsEnabled = true
                    if _currentContour.functionExpression == nil {
                        newContour.drawValuesEnabled = true
                        newContour.drawCirclesEnabled = true
                        newContour.circleRadius = 3
                        newContour.drawCircleHoleEnabled = false
                    }
                    else {
                        newContour.drawValuesEnabled = false
                        newContour.drawCirclesEnabled = false
                    }
                    if renewal {
                        self.chartView?.contourData?.dataSets.append(newContour)
                        self.chartView?.notifyDataSetChanged()
                    }
                    else {
                        self.chartView?.contourData = [ newContour ]
                    }
                    self.updateLegend()
                    if let _changeButton = self.changeButton {
                        self.menuItemsUpdate(_changeButton.menu)
                    }
                }
            }
            else {
                newContour.fillIsoCurves = _currentContour.fillContours
                newContour.drawIsoCurvesLabelsEnabled = true
                if _currentContour.functionExpression == nil {
                    newContour.drawValuesEnabled = true
                    newContour.drawCirclesEnabled = true
                    newContour.circleRadius = 3
                    newContour.drawCircleHoleEnabled = false
                }
                else {
                    newContour.drawValuesEnabled = false
                    newContour.drawCirclesEnabled = false
                }
                if renewal {
                    self.chartView?.contourData?.dataSets.append(newContour)
                    self.chartView?.notifyDataSetChanged()
                }
                else {
                    self.chartView?.contourData = [ newContour ]
                }
                updateLegend()
                if let _changeButton = changeButton {
                    menuItemsUpdate(_changeButton.menu)
                }
            }
        }
    }
    
    private func updateLegend() {
        if let l = self.chartView?.legend {
            l.resetCustom()
            
            var legendEntries: [LegendEntry]?
            if let dataSet = self.chartView?.contourData?.dataSets.first as? ContourChartDataSet {
                if dataSet.fillIsoCurves {
                    if let _fillings = dataSet.isoCurvesFillings {
                        legendEntries = []
                        for i in 0..<_fillings.count {
                            let legendEntry = LegendEntry()
                            let filling = _fillings[i]
                            if let fill = filling.fill as? ColorFill {
                                legendEntry.formColor = NSColor(cgColor: fill.color)
                            }
                            else if let image = filling.fill as? ImageFill {
                                //legendEntry.formColor = _fillings[0].fill
                            }
                            legendEntry.formSize = 10
                            legendEntry.form = .square
                            
                            if filling.first == nil,
                                let second = filling.second {
                                legendEntry.label = String(format:">%0.2f", second)
                            }
                            else if filling.second == nil,
                                let first = filling.first {
                                legendEntry.label = String(format:"<%0.2f", first)
                            
                            }
                            else {
                                if let first = filling.first,
                                   let second = filling.second {
                                    if first == second {
                                        legendEntry.label = String(format:"%0.2f", first)
                                    }
                                    else if first > second {
                                        legendEntry.label = String(format:"%0.2f - %0.2f", second, first)
                                    }
                                    else {
                                        legendEntry.label = String(format:"%0.2f - %0.2f", first, second)
                                    }
                                }
                            }
                            legendEntries?.append(legendEntry)
                        }
                    }
                    else if let _isoCurveValues = dataSet.isoCurvesValues {
                        let _isoCurveIndices = dataSet.isoCurvesIndices
                        if dataSet.isIsoCurveFillsUsingColour,
                            let _isoCurvesColourFills = dataSet.isoCurvesColourFills {
                            legendEntries = []
                            var firstValue = _isoCurveValues[_isoCurveIndices[0]]
                            let legendEntry0 = LegendEntry()
                            legendEntry0.formColor = NSUIColor(cgColor: _isoCurvesColourFills[0].color)
                            legendEntry0.formSize = 10
                            legendEntry0.form = .square
                            if firstValue == 1000.0 * _isoCurveValues[_isoCurveIndices[1]] {
                                legendEntry0.label = "Discontinuous"
                            }
                            else {
                                legendEntry0.label = String(format:"<%0.2f", _isoCurveValues[_isoCurveIndices[0]])
                                
                            }
                            legendEntries?.append(legendEntry0)
                            for i in 1..<_isoCurveIndices.count-1 {
                                let legendEntry = LegendEntry()
                                legendEntry.label = String(format:"%0.2f - %0.2f", firstValue, _isoCurveValues[_isoCurveIndices[i]])
                                firstValue = _isoCurveValues[_isoCurveIndices[i]]
                            
                                legendEntry.formColor = NSUIColor(cgColor: _isoCurvesColourFills[i].color)
                                legendEntry.formSize = 10
                                legendEntry.form = .square
                                legendEntries?.append(legendEntry)
                            }
                            let legendEntry1 = LegendEntry()
                            legendEntry1.formColor = NSUIColor(cgColor: _isoCurvesColourFills[_isoCurvesColourFills.count-1].color)
                            legendEntry1.formSize = 10
                            legendEntry1.form = .square
                            if _isoCurveValues[_isoCurveIndices[_isoCurveIndices.count - 1]] == 1000.0 * _isoCurveValues[_isoCurveIndices[_isoCurveIndices.count - 2]] {
                                legendEntry1.label = "Discontinuous"
                                
                            }
                            else {
                                legendEntry1.label = String(format: ">%0.2f", _isoCurveValues[_isoCurveIndices[_isoCurveIndices.count - 1]])
                            }
                            legendEntries?.append(legendEntry1)
                        }
                        else {
                            
                        }
                    }
                }
                else if let _isoCurveValues = dataSet.isoCurvesValues,
                    let _isoCurveLineColours = dataSet.isoCurvesLineColours {
                    let _isoCurveIndices = dataSet.isoCurvesIndices
                    legendEntries = []
                    for i in 0..<_isoCurveIndices.count {
                        let legendEntry = LegendEntry()
                        
                        if (i == 0 && _isoCurveValues[_isoCurveIndices[i]] == 1000.0 * _isoCurveValues[_isoCurveIndices[i + 1]]) || (i == _isoCurveIndices.count - 1 &&  _isoCurveValues[_isoCurveIndices[i]] == 1000 * _isoCurveValues[_isoCurveIndices[i - 1]]) {
                            legendEntry.label = "Discontinuous"
                        }
                        else {
                            legendEntry.label = String(format:"%0.2f", _isoCurveValues[_isoCurveIndices[i]])
                        }
                        legendEntry.formColor = _isoCurveLineColours[i]
                        legendEntry.formLineWidth = dataSet.isoCurvesLineWidth
                        legendEntry.form = .line
                        legendEntries?.append(legendEntry)
                    }
                }
            }
            if let _legendEntries = legendEntries {
                l.setCustom(entries: _legendEntries)
            }
        }
    }
    
    @IBAction func changeNoOfIsoCurves(_ sender: Any?) {
        if let _chartView = self.chartView {
            if let _contourData = _chartView.contourData,
               let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
               let set = _dataSets.first {   // should only be one contour set per chart!!
                set.noIsoCurves = set.noIsoCurves + 1 > 21 ? 6 : set.noIsoCurves + 1
                if let _ /*spinner*/ = self.spinner {
                    showSpinner() { _ in
                        _chartView.notifyDataSetChanged()
                        self.updateLegend()
                        if let _changeButton = self.changeButton {
                            self.menuItemsUpdate(_changeButton.menu, tag: 1)
                        }
                    }
                }
                else {
                    _chartView.notifyDataSetChanged()
                    updateLegend()
                    if let _changeButton = changeButton {
                        menuItemsUpdate(_changeButton.menu, tag: 1)
                    }
                }
                
            }
        }
    }
        
    @IBAction func changeFilled(_ sender: Any?) {
        if let _chartView = self.chartView,
           let set = _chartView.contourData?.dataSets.first as? ContourChartDataSet {
            set.fillIsoCurves = !set.fillIsoCurves
            self.currentContour?.fillContours = set.fillIsoCurves
            if let _ = self.spinner {
                showSpinner() { _ in
                    _chartView.notifyDataSetChanged()
                    self.updateLegend()
                    if let _changeButton = self.changeButton {
                        self.menuItemsUpdate(_changeButton.menu, tag: 2)
                    }
                }
            }
            else {
                _chartView.notifyDataSetChanged()
                updateLegend()
                if let _changeButton = changeButton {
                    menuItemsUpdate(_changeButton.menu, tag: 2)
                }
            }
        }
    }
    
    @IBAction func changePrimaryResolution(_ sender: Any?) {
        if let _chartView = self.chartView,
           var _currentContour = self.currentContour,
           let set = _chartView.contourData?.dataSets.first as? ContourChartDataSet{
            let resolutions: [Int] = [ 8, 16, 32, 64, 128 ]
            if var index = resolutions.firstIndex(where: { $0 == _currentContour.firstResolution }) {
                index = index + 1 == resolutions.count ? 0 : index + 1
                _currentContour.firstResolution = resolutions[index]
                self.currentContour?.firstResolution = resolutions[index]
                set.noRowsFirst = _currentContour.firstResolution
                set.noColumnsFirst = _currentContour.firstResolution
                if let _ = self.spinner {
                    showSpinner() { _ in
                        _chartView.notifyDataSetChanged()
                        if let _changeButton = self.changeButton {
                            self.menuItemsUpdate(_changeButton.menu, tag: 3)
                        }
                    }
                }
                else {
                    _chartView.notifyDataSetChanged()
                    if let _changeButton = changeButton {
                        menuItemsUpdate(_changeButton.menu, tag: 3)
                    }
                }
            }
        }
    }
    
    @IBAction func changeSecondaryResolution(_ sender: Any?) {
        if let _chartView = self.chartView,
           var _currentContour = self.currentContour,
           let set = _chartView.contourData?.dataSets.first as? ContourChartDataSet {
            let resolutions: [Int] = [ 256, 512, 1024, 2048, 4096 ]
            if var index = resolutions.firstIndex(where: { $0 == _currentContour.secondaryResolution }) {
                index = index + 1 == resolutions.count ? 0 : index + 1
                _currentContour.secondaryResolution = resolutions[index]
                self.currentContour?.secondaryResolution = resolutions[index]
                set.noRowsSecondary = _currentContour.secondaryResolution
                set.noColumnsSecondary = _currentContour.secondaryResolution
                if let _ = self.spinner {
                    showSpinner() { _ in
                        _chartView.notifyDataSetChanged()
                        if let _changeButton = self.changeButton {
                            self.menuItemsUpdate(_changeButton.menu, tag: 4)
                        }
                    }
                }
                else {
                    _chartView.notifyDataSetChanged()
                    if let _changeButton = changeButton {
                        menuItemsUpdate(_changeButton.menu, tag: 4)
                    }
                }
            }
        }
    }
    
    @IBAction func changeInterpolationMethod(_ sender: Any?) {
        if let _chartView = self.chartView,
           let set = _chartView.contourData?.dataSets.first as? ContourChartDataSet {
            if set.interpolationMode == .linear {
                set.interpolationMode = .cubic
                set.cubicInterpolation = .normal
            }
            else {
                let option = set.cubicInterpolation.rawValue + 1 == ContourChartDataSet.CubicInterpolation.count ? 0 : set.cubicInterpolation.rawValue + 1
                if option == 0 {
                    set.interpolationMode = .linear
                    set.cubicInterpolation = .normal
                }
                else {
                    set.interpolationMode = .cubic
                    set.cubicInterpolation = ContourChartDataSet.CubicInterpolation(rawValue: option) ?? .normal
                }
            }
            if let _ = self.spinner {
                showSpinner() { _ in
                    _chartView.notifyDataSetChanged()
                    if let _changeButton = self.changeButton {
                        self.menuItemsUpdate(_changeButton.menu, tag: 5)
                    }
                }
            }
            else {
                _chartView.notifyDataSetChanged()
                if let _changeButton = changeButton {
                    menuItemsUpdate(_changeButton.menu, tag: 5)
                }
            }
        }
    }
    
    @IBAction func changeExtrapolateToCorners(_ sender: Any?) {
        if let _chartView = self.chartView,
           let _currentContour = self.currentContour,
           _currentContour.functionExpression == nil,
           var set = _chartView.contourData?.dataSets.first as? ContourChartDataSet {
            self.currentContour?.extrapolateToARectangleOfLimits = !_currentContour.extrapolateToARectangleOfLimits
            set.extrapolateToLimits = _currentContour.extrapolateToARectangleOfLimits
            set.fieldBlock = setupContoursForInterpolation(dataSet: &set, minX: self.minX, maxX: self.maxX, minY: self.minY, maxY: self.maxY)
            if let _ = self.spinner {
                showSpinner() { _ in
                    _chartView.notifyDataSetChanged()
                    if let _changeButton = self.changeButton {
                        self.menuItemsUpdate(_changeButton.menu, tag: 6)
                    }
                }
            }
            else {
                _chartView.notifyDataSetChanged()
                if let _changeButton = changeButton {
                    menuItemsUpdate(_changeButton.menu, tag: 6)
                }
            }
        }
    }

        
    @IBAction func changeSurfaceInterpolationMethod(_ sender: Any?) {
        if let _chartView = self.chartView,
           var set = _chartView.contourData?.dataSets.first as? ContourChartDataSet,
           var _currentContour = self.currentContour {
            _currentContour.krigingSurfaceInterpolation = !_currentContour.krigingSurfaceInterpolation
            self.currentContour?.krigingSurfaceInterpolation = _currentContour.krigingSurfaceInterpolation
            set.fieldBlock = setupContoursForInterpolation(dataSet: &set, minX: minX, maxX: maxX, minY: minY, maxY: maxY)
            
            if let _ = self.spinner {
                showSpinner() { _ in
                    _chartView.notifyDataSetChanged()
                    if let _changeButton = self.changeButton {
                        self.menuItemsUpdate(_changeButton.menu, tag: 7)
                    }
                }
            }
            else {
                _chartView.notifyDataSetChanged()
                if let _changeButton = changeButton {
                    menuItemsUpdate(_changeButton.menu, tag: 7)
                }
            }
            
        }
    }
    
    // MARK: - PDF
    
    @IBAction func savePDF(_ sender: Any) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [ .pdf ]
        panel.beginSheetModal(for: self.view.window!) { (result) -> Void in
            if result == NSApplication.ModalResponse.OK {
                if let _chartView = self.chartView,
                   let path = panel.url?.path {
                    let _ = _chartView.savePDF(to: path)
                }
            }
        }
    }
    
    // MARK: - Spinner
    
    private func showSpinner(completion: ((Bool) -> Void)?) { //@escaping(Bool) -> Void) {
        if let _spinner = self.spinner {
            _spinner.isHidden = false
            _spinner.message = self.message
            let startFrame = CGRect(x: _spinner.bounds.midX, y: _spinner.bounds.midY, width: 0, height: 0)
            let endFrame = _spinner.bounds
            _spinner.frame = startFrame
 
            // NSView move animation
            NSAnimationContext.runAnimationGroup({ context in
                // 2 second animation
                context.duration = 0.5
                        
                // The view will animate to the new origin
                _spinner.animator().frame = endFrame
            }) {
                completion?(true)
                _spinner.isHidden = true
            }
        }
    }
    
    // MARK: - Hull Convex Points methods

        private func quickHullOnPlotData(plotdata: [DataStructure]?) -> [ConvexHullPoint] {
            var point: ConvexHullPoint
            var convexHullPoints: [ConvexHullPoint] = []
            if var _plotdata = plotdata {
                if _plotdata.count < 2 {
                    point = ConvexHullPoint(point: CGPoint(x: _plotdata[0].x, y: _plotdata[0].y), index: 0)
                    convexHullPoints.append(point)
                    if _plotdata.count == 2 {
                        point = ConvexHullPoint(point: CGPoint(x: _plotdata[1].x, y: _plotdata[1].y), index: 1)
                        convexHullPoints.append(point)
                    }
                    return convexHullPoints
                }
                else {
                    _plotdata.sort(by: { $0.x < $1.x } )
                    var pts: [ConvexHullPoint] = []
                    for i in 1..<_plotdata.count - 1 {
                        point = ConvexHullPoint(point: CGPoint(x: _plotdata[i].x, y: _plotdata[i].y), index: i)
                        point.point = CGPoint(x: _plotdata[i].x, y: _plotdata[i].y);
                        point.index = i
                        pts.append(point)
                    }
                    
                    // p1 and p2 are outer most points and thus are part of the hull
                    let p1: ConvexHullPoint = ConvexHullPoint(point: CGPoint(x: _plotdata[0].x, y: _plotdata[0].y), index: 0)
                    // left most point
                    convexHullPoints.append(p1)
                    let p2: ConvexHullPoint = ConvexHullPoint(point: CGPoint(x: _plotdata[_plotdata.count - 1].x, y: _plotdata[_plotdata.count - 1].y), index: _plotdata.count - 1)
                    // right most point
                    convexHullPoints.append(p2)

                    // points to the right of oriented line from p1 to p2
                    var s1: [ConvexHullPoint] = []
                    // points to the right of oriented line from p2 to p1
                    var s2: [ConvexHullPoint] = []

                    // p1 to p2 line
                    let lineVec1 = CGPoint(x: p2.point.x - p1.point.x, y: p2.point.y - p1.point.y)
                    var pVec1: CGPoint
                    var sign1: CGFloat
                    for i in 0..<pts.count {
                        point = pts[i]
                        pVec1 = CGPoint(x: point.point.x - p1.point.x, y: point.point.y - p1.point.y)
                        sign1 = lineVec1.x * pVec1.y - pVec1.x * lineVec1.y // cross product to check on which side of the line point p is.
                        if sign1 > 0  { // right of p1 p2 line (in a normal xy coordinate system this would be < 0 but due to the weird iPhone screen coordinates this is > 0
                            s1.append(point)
                        }
                        else { // right of p2 p1 line
                            s2.append(point)
                        }
                    }
                    // find new hull points
                    findHull(points: s1, p1: p1, p2: p2, convexHullPoints: &convexHullPoints)
                    findHull(points: s2, p1: p2, p2: p1, convexHullPoints: &convexHullPoints)
                }
            }
            return convexHullPoints
        }


        private func findHull(points: [ConvexHullPoint], p1: ConvexHullPoint, p2: ConvexHullPoint, convexHullPoints: inout [ConvexHullPoint]) -> Void {
            
            // if set of points is empty there are no points to the right of this line so this line is part of the hull.
            if points.isEmpty {
                return
            }
            
            var pts = points
            if var maxPoint: ConvexHullPoint = pts.first {
                var maxDist: CGFloat = -1
                for p in pts { // for every point check the distance from our line
                    let dist = distance(from: p, to: (p1, p2))
                    if dist > maxDist { // if distance is larger than current maxDist remember new point p
                        maxDist = dist
                        maxPoint = p
                    }
                }
                // insert point with max distance from line in the convexHull after p1
                if let index = convexHullPoints.firstIndex(of: p1) {
                    convexHullPoints.insert(maxPoint, at: index + 1)
                }
                // remove maxPoint from points array as we are going to split this array in points left and right of the line
                if let index = pts.firstIndex(of: maxPoint) {
                    pts.remove(at: index)
                }
                
                // points to the right of oriented line from p1 to p2
                var s1 = [ConvexHullPoint]()

                // points to the right of oriented line from p2 to p1
                var s2 = [ConvexHullPoint]()

                // p1 to maxPoint line
                let lineVec1 = CGPoint(x: maxPoint.point.x - p1.point.x, y: maxPoint.point.y - p1.point.y)
                // maxPoint to p2 line
                let lineVec2 = CGPoint(x: p2.point.x - maxPoint.point.x, y: p2.point.y - maxPoint.point.y)

                for p in pts { // per point check if point is to right or left of p1 to p2 line
                    let pVec1 = CGPoint(x: p.point.x - p1.point.x, y: p.point.y - p1.point.y)
                    let sign1 = lineVec1.x * pVec1.y - pVec1.x * lineVec1.y // cross product to check on which side of the line point p is.
                    let pVec2 = CGPoint(x: p.point.x - maxPoint.point.x, y: p.point.y - maxPoint.point.y) // vector from p2 to p
                    let sign2 = lineVec2.x * pVec2.y - pVec2.x * lineVec2.y // sign to check is p is to the right or left of lineVec2

                    if sign1 > 0 { // right of p1 p2 line (in a normal xy coordinate system this would be < 0 but due to the weird iPhone screen coordinates this is > 0
                        s1.append(p)
                    }
                    else if sign2 > 0 { // right of p2 p1 line
                        s2.append(p)
                    }
                }
                
                // find new hull points
                findHull(points: s1, p1: p1, p2: maxPoint, convexHullPoints: &convexHullPoints)
                findHull(points: s2, p1: maxPoint, p2: p2, convexHullPoints: &convexHullPoints)
            }
        }

        private func distance(from p: ConvexHullPoint, to line: (ConvexHullPoint, ConvexHullPoint)) -> CGFloat {
          // If line.0 and line.1 are the same point, they don't define a line (and, besides,
          // would cause division by zero in the distance formula). Return the distance between
          // line.0 and point p instead.
            if __CGPointEqualToPoint(line.0.point, line.1.point) {
                return sqrt(pow(p.point.x - line.0.point.x, 2) + pow(p.point.y - line.0.point.y, 2))
          }

          // from Deza, Michel Marie; Deza, Elena (2013), Encyclopedia of Distances (2nd ed.), Springer, p. 86, ISBN 9783642309588
            return abs((line.1.point.y - line.0.point.y) * p.point.x
            - (line.1.point.x - line.0.point.x) * p.point.y
            + line.1.point.x * line.0.point.y
            - line.1.point.y * line.0.point.x)
            / sqrt(pow(line.1.point.y - line.0.point.y, 2) + pow(line.1.point.x - line.0.point.x, 2))
        }

        // MARK: - NSMenuItems titles
    
    private func menuItemsUpdate(_ menu: NSMenu, tag: Int? = nil) -> Void {
        
        if let _currentContour = self.currentContour {
            var items: [NSMenuItem]
            if let _tag = tag,
               _tag < menu.items.count {
                items = Array(menu.items[_tag..<_tag+1])
            }
            else {
                items = menu.items
            }
            for item in items {
                switch item.tag {
                    case 0:
                        item.title = String(format: "Contour Data: %@", _currentContour.plottitle)
                    
                    case 1:
                        if let _chartView = self.chartView,
                           let _contourData = _chartView.contourData,
                           let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
                           let set = _dataSets.first {   // should only be one contour set per chart!!
                            item.title = "No IsoCurves: \(set.noIsoCurves)"
                        }
                        
                    case 2:
                        item.title = _currentContour.fillContours ? "Unfill" : "Fill"
                    
                    case 3:
                        if let _chartView = self.chartView,
                           let _contourData = _chartView.contourData,
                           let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
                           let set = _dataSets.first {   // should only be one contour set per chart!!
                            item.title = "Grid Primary Resolution: \(set.noColumnsFirst)"
                        }
                    
                    case 4:
                        if let _chartView = self.chartView,
                           let _contourData = _chartView.contourData,
                           let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
                           let set = _dataSets.first {   // should only be one contour set per chart!!
                            item.title = "Grid Primary Resolution: \(set.noColumnsSecondary)"
                        }
                    
                    case 5:
                        if let _chartView = self.chartView,
                           let _contourData = _chartView.contourData,
                           let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
                           let set = _dataSets.first {   // should only be one contour set per chart!!
                            if set.interpolationMode == .linear {
                                item.title = "Contour Line Method: Linear"
                            }
                            else {
                                item.title = "Contour Line Method: \(set.cubicInterpolation.description)"
                            }
                        }
                    
                    case 6:
                        if let _chartView = self.chartView,
                           let _contourData = _chartView.contourData,
                           let _dataSets = _contourData.dataSets as? [ContourChartDataSet],
                           let set = _dataSets.first {   // should only be one contour set per chart!!
                            item.title = set.extrapolateToLimits ? "Don't extrapolate to Limits" : "Extrapolate to Limits"
                        }
                    
                    default:
                        item.title = "Interpolation Method: \(_currentContour.krigingSurfaceInterpolation ? "Kriging" : "Delaunay")"
                        
                }
            }
            
            if _currentContour.functionExpression == nil {
                menu.item(withTag: 6)?.isHidden = false
                menu.item(withTag: 7)?.isHidden = false
            }
            else {
                menu.item(withTag: 6)?.isEnabled = true
                menu.item(withTag: 7)?.isEnabled = true
            }
        }
    }
    

        
        // MARK: - ChartViewDelegate
        
        func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
            
            chartView.marker?.refreshContent(entry: entry, highlight: highlight)
        }
        
        // MARK: - ContourChartViewDelegate
        
        func chartIsoCurvesLineColour(at plane: Int, dataSet: ContourChartDataSetProtocol, lineColour: UnsafeMutablePointer<NSUIColor>) {
            if let noIsoCurveValues = dataSet.isoCurvesValues?.count {
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                let alpha: CGFloat = 0.5

                let value = CGFloat(plane) / CGFloat(noIsoCurveValues)
                blue = min(max(1.5 - 4.0 * abs(value - 0.25), 0.0), 1.0)
                green = min(max(1.5 - 4.0 * abs(value - 0.5), 0.0), 1.0)
                red  = min(max(1.5 - 4.0 * abs(value - 0.75), 0.0), 1.0)
                let colour = NSUIColor(red: red, green: green, blue: blue, alpha: alpha)
                lineColour.pointee = colour
            }
        }
    }

extension ContourChartView {
    
    public func savePDF(to path: String) -> Bool {
        // Create the PDF context using the default page size of 612 x 792.
        
#if os(OSX)
        // Create an empty PDF document
        let pdfDocument = PDFDocument()

        // Load or create your NSImage
        if let image = self.getChartImage(transparent: true),
           // Create a PDF page instance from your image
           let pdfPage = PDFPage(image: image) {
            // Insert the PDF page into your document
            pdfDocument.insert(pdfPage, at: 0)
            
            // Get the raw data of your PDF document
            if let pdfData = pdfDocument.dataRepresentation() {
                let url = URL(fileURLWithPath: path)
                do {
                    try pdfData.write(to: url, options: .atomic)
                }
                catch {
                    return false
                }
                return true
            }
            else {
                return false
            }
        }
        else {
            return false
        }
        
//        let pdfData: Data = Data()
//        if let image = self.getChartImage(transparent: true),
//           let imageRef = image.cgImage,
//           let url = URL(string: path),
//           let mutableData = CFDataCreateMutable(nil, 0),
//           let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) {
//            CGImageDestinationAddImage(destination, imageRef, nil)
//            if CGImageDestinationFinalize(destination),
//               let pdfConsumer = CGDataConsumer(data: mutableData) {
//
//                 var mediaBox = NSRect.init(x: 0, y: 0, width: image.size.width, height: image.size.height)
//
//                if let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) {
//                     pdfContext.beginPage(mediaBox: &mediaBox)
//
//                     pdfContext.draw(imageRef, in: mediaBox)
//                     pdfContext.endPage()
//
//                     do {
//                         try pdfData.write(to: url, options: .atomic)
//                     }
//                     catch {
//                         return false
//                     }
//                     return true
//                 }
//                 else {
//                     return false
//                 }
//            }
//            else {
//                return false
//            }
//        }
//        else {
//            return false
//        }
        
        //  Automatically open this newly generated file
#else
        UIGraphicsBeginPDFContextToFile(path, CGRect.zero, nil)
        let pdfPageRect = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: self.bounds.size.height)
        if let image = self.getChartImage(transparent: true) {
            // Mark the beginning of a new page.
            UIGraphicsBeginPDFPageWithInfo(pdfPageRect, nil)
            //        CGContextRef pdfContext = UIGraphicsGetCurrentContext();
            //        [graph.hostingView.layer renderInContext:pdfContext];
            // Pre-render the graph into a temporary UIImage
            UIGraphicsBeginImageContextWithOptions(self.frame.size, false, 0.0)
            
            if let graphTmpImage = UIGraphicsGetImageFromCurrentImageContext() {
                UIGraphicsEndImageContext()
                // Draw the pre-rendered pie chart in to the PDF context.
                graphTmpImage.draw(in: CGRect(x: 0, y: 0, width: graphTmpImage.size.width, height: graphTmpImage.size.height))
                // Close the PDF context and write the contents out.
                UIGraphicsEndPDFContext()
                return true
            }
            else {
                return false
            }
        }
        else {
            return false
        }
#endif
    }
}
