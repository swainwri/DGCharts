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
    
    @IBOutlet var chartView: VectorFieldChartView!
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
        
        chartView.delegate = self

        chartView.chartDescription.enabled = false
        
        chartView.dragEnabled = true
        chartView.setScaleEnabled(true)
        chartView.maxVisibleCount = 128 * 128
        chartView.pinchZoomEnabled = true
        
        let l = chartView.legend
        l.horizontalAlignment = .right
        l.verticalAlignment = .top
        l.orientation = .vertical
        l.drawInside = false
        l.font = .systemFont(ofSize: 10, weight: .light)
        l.xOffset = 5
        
        let leftAxis = chartView.leftAxis
        leftAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        leftAxis.axisMinimum = -2 * .pi
        let piFormatter = PiNumberFormatter()
        piFormatter.multiplier = 16
        leftAxis.valueFormatter = piFormatter
        leftAxis.granularity = .pi / 4
        chartView.rightAxis.enabled = false
        
        
        let xAxis = chartView.xAxis
        xAxis.labelFont = .systemFont(ofSize: 10, weight: .light)
        xAxis.valueFormatter = piFormatter
        xAxis.granularity = .pi / 4
        xAxis.forceLabelsEnabled = true
        
        sliderX.maximumValue = 32
        sliderX.minimumValue = 8
        sliderX.value = 16
        
        slidersValueChanged(nil)
    }
    
    override func updateChartData() {
        if self.shouldHideData {
            chartView.data = nil
            return
        }
        
        self.setDataCount(Int(sliderX.value))
    }
    
    func setDataCount(_ count: Int) {
        
        var values1: [FieldChartDataEntry] = []
        values1.reserveCapacity(count * count)

        let divisor = Double(16) / Double(count)
        
        var x = -2.0 * .pi
        while x <= 2.0 * .pi {
            var y = -2.0 * .pi
            while y <= 2.0 * .pi {
                let fx = sin(x)
                let fy = sin(y)
                let length = sqrt(fx * fx + fy * fy) / sqrt(2.0)
                let direction = atan2(fy, fx)
                values1.append(FieldChartDataEntry(x: x, y: y, magnitude: length, direction: direction))
                y += .pi / 8.0 * divisor
            }
            x += .pi / 8.0 * divisor
        }
        
        let set1 = VectorFieldChartDataSet(entries: values1, label: "DS 1")
        set1.arrowType = .solid
        set1.setColor(ChartColorTemplates.colorful()[0])
        set1.arrowSize = 5
        set1.normalisedVectorLength = 20
        
        let data: VectorFieldChartData = [set1]
        data.setValueFont(.systemFont(ofSize: 7, weight: .light))

        chartView.data = data
    }
    
    override func optionTapped(_ option: Option) {
        super.handleOption(option, forChartView: chartView)
    }
    
    @IBAction func slidersValueChanged(_ sender: Any?) {
        sliderTextX.text = "\(Int(sliderX.value))"
        
        self.updateChartData()
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
