//
//  VectorFieldChartViewController.swift
//  ChartsDemo-iOS-Swift
//
//  Created by Steve Wainwright on 09/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

#if canImport(UIKit)
    import UIKit
#endif
import DGCharts

class VectorFieldChartViewController: DemoBaseViewController, VectorFieldChartViewDelegate {
    
    @IBOutlet var chartView: VectorFieldChartView?
    @IBOutlet var sliderX: UISlider!
   
    @IBOutlet var sliderTextX: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.title = "Vector Field Chart"
        self.options = [.toggleValues,
                        .toggleHighlight,
                        .animateX,
                        .animateY,
                        .animateXY,
                        .saveToGallery,
                        .togglePinchZoom,
                        .toggleAutoScaleMinMax,
                        .toggleData]
        
        chartView?.delegate = self

        chartView?.chartDescription.enabled = false
        
        chartView?.dragEnabled = true
        chartView?.setScaleEnabled(true)
        chartView?.maxVisibleCount = 128 * 128
        chartView?.pinchZoomEnabled = true
        
        if let l = chartView?.legend {
            l.horizontalAlignment = .right
            l.verticalAlignment = .top
            l.orientation = .vertical
            l.drawInside = true
            l.font = .systemFont(ofSize: 10, weight: .light)
            l.xOffset = 5
        }
        
        let piFormatter = PiNumberFormatter()
        piFormatter.multiplier = 16
        if let leftAxis = chartView?.leftAxis {
            leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
            leftAxis.axisMinimum = -2 * .pi
            leftAxis.axisMaximum = 2 * .pi
            leftAxis.valueFormatter = piFormatter
            leftAxis.granularity = .pi / 4
            chartView?.rightAxis.enabled = false
        }
        
        if let xAxis = chartView?.xAxis {
            xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
            xAxis.valueFormatter = piFormatter
            xAxis.granularity = .pi / 4
            xAxis.axisMinimum = -2 * .pi
            xAxis.axisMaximum = 2 * .pi
            //xAxis.forceLabelsEnabled = true
        }
        
        sliderX.maximumValue = 32
        sliderX.minimumValue = 8
        sliderX.value = 16
        
        slidersValueChanged(nil)
        
        if let _chartView = self.chartView,
           let xAxisValueFormatter = _chartView.xAxis.valueFormatter,
           let yAxisValueFormatter = _chartView.leftAxis.valueFormatter {
            let angleFormatter = NumberFormatter() //DegreeFormatter()
            angleFormatter.maximumFractionDigits = 3
            let marker = VectorFieldMarkerView(color: UIColor(white: 180/250, alpha: 1),
                                               font: .systemFont(ofSize: 12),
                                               textColor: .white,
                                               insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8),
                                               xAxisValueFormatter: xAxisValueFormatter,
                                               yAxisValueFormatter: yAxisValueFormatter,
                                               directionFormatter: angleFormatter)
            marker.chartView = _chartView
            marker.minimumSize = CGSize(width: 80, height: 40)
            chartView?.marker = marker
        }
    }
    
    override func updateChartData() {
        if self.shouldHideData {
            chartView?.data = nil
            return
        }
        
        self.setDataCount(Int(sliderX.value))
    }
    
    func setDataCount(_ count: Int) {
        
        var values: [FieldChartDataEntry] = []
        values.reserveCapacity(count * count)

        let divisor = Double(16) / Double(count)
        
        var x = -2.0 * .pi
        while x <= 2.0 * .pi {
            var y = -2.0 * .pi
            while y <= 2.0 * .pi {
                let fx = sin(x)
                let fy = sin(y)
                let length = sqrt(fx * fx + fy * fy) / sqrt(2.0)
                let direction = atan2(fy, fx)
                values.append(FieldChartDataEntry(x: x, y: y, magnitude: length, direction: direction))
                y += .pi / 8.0 * divisor
            }
            x += .pi / 8.0 * divisor
        }
        
        let set = VectorFieldChartDataSet(entries: values, label: "sin(x) sin(y)")
        set.arrowType = .solid
        set.setColor(ChartColorTemplates.colorful()[0])
        set.arrowSize = 5
        set.normalisedVectorLength = 20
        
        let data: VectorFieldChartData = [set]
        data.setValueFont(.systemFont(ofSize: 7, weight: .light))

        chartView?.data = data
    }
    
    override func optionTapped(_ option: Option) {
        super.handleOption(option, forChartView: chartView!)
    }
    
    @IBAction func slidersValueChanged(_ sender: Any?) {
        sliderTextX.text = "\(Int(sliderX.value))"
        
        self.updateChartData()
    }
    
    // MARK: - ChartViewDelegate
    
    override func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        super.chartValueSelected(chartView, entry: entry, highlight: highlight)
        
        chartView.marker?.refreshContent(entry: entry, highlight: highlight)
    }
    
    // MARK: - VectorFieldChartViewDelegate
    
    func chartValueStyle(entry: FieldChartDataEntry, vectorWidth: UnsafeMutablePointer<CGFloat>, color: UnsafeMutablePointer<NSUIColor>, fill: UnsafeMutablePointer<ColorFill>) {
        if entry.magnitude > 0.9 {
            vectorWidth.pointee = CGFloat(2.5)
            color.pointee = NSUIColor.red
            fill.pointee = ColorFill(color: NSUIColor.red)
        }
        else if entry.magnitude > 0.7 {
            vectorWidth.pointee = CGFloat(1.5)
            color.pointee = NSUIColor.orange
            fill.pointee = ColorFill(color: NSUIColor.orange)
        }
        else if entry.magnitude > 0.4 {
            vectorWidth.pointee = CGFloat(1)
            color.pointee = NSUIColor.green
            fill.pointee = ColorFill(color: NSUIColor.green)
        }
        else {
            vectorWidth.pointee = CGFloat(0.5)
            color.pointee = NSUIColor.blue
            fill.pointee = ColorFill(color: NSUIColor.blue)
        }
    }
    
}
