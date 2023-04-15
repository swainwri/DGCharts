//
//  PolarChartViewController.swift
//  ChartsDemo-iOS-Swift
//
//  Created by Steve Wainwright on 02/04/2023.
//  Copyright © 2023 dcg. All rights reserved.
//

#if canImport(UIKit)
    import UIKit
#endif
import DGCharts

class PolarChartViewController: DemoBaseViewController {

    @IBOutlet var chartView: PolarChartView?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.title = "Polar Chart"
        self.options = [.toggleRadialValues,
                        .toggleHighlight,
                        .toggleHighlightCircle,
                        .toggleRadialLabels,
                        .toggleMajorMinorLabels,
                        .toggleRotate,
                        .toggleFilled,
                        .animateX,
                        .animateY,
                        .animateXY,
                        .spin,
                        .saveToGallery,
                        .toggleData,
                        .togglePolarMode,
                        .togglePolarCurvedInterpolationOption,
                        .togglePolarHistogramOption
            ]
        
        
        chartView?.delegate = self
        
        chartView?.chartDescription.enabled = false
    
        chartView?.backgroundColor = .white
        
        if let majorAxis = chartView?.majorAxis {
            majorAxis.labelFont = .systemFont(ofSize: 11, weight: .light)
            majorAxis.xOffset = 0
            majorAxis.yOffset = 0
            majorAxis.labelTextColor = .blue
            majorAxis.labelCount = 11
            majorAxis.granularity = 5
            majorAxis.granularityEnabled = true
            majorAxis.axisLineWidth = 2
//            majorAxis.gridLinesToChartRectEdges = true
        }
        
        if let minorAxis = chartView?.minorAxis {
            minorAxis.labelFont = .systemFont(ofSize: 11, weight: .light)
            minorAxis.labelCount = 11
            minorAxis.labelTextColor = .blue
            minorAxis.axisLineWidth = 2
//            minorAxis.gridLinesToChartRectEdges = true
        }
        
        if let radialAxis = chartView?.radialAxis {
            radialAxis.labelFont = .systemFont(ofSize: 11, weight: .light)
            radialAxis.labelCount = 12
            radialAxis.axisMinimum = 0
            radialAxis.axisMaximum = 2 * .pi
            radialAxis.entryCount = 12
            radialAxis.granularity = 2 * .pi / 24
            radialAxis.granularityEnabled = true
            radialAxis.radialAngleMode = .radians
            let piFormatter = PiNumberFormatter()
            piFormatter.multiplier = 16
            radialAxis.valueFormatter = piFormatter
            radialAxis.axisLineWidth = 2
        }
        
        if let l = chartView?.legend {
            l.horizontalAlignment = .center
            l.verticalAlignment = .top
            l.orientation = .horizontal
            l.drawInside = false
            l.font = .systemFont(ofSize: 10, weight: .light)
            l.xEntrySpace = 7
            l.yEntrySpace = 5
            l.textColor = .darkGray
        }
        
        self.updateChartData()
        
        chartView?.animate(xAxisDuration: 1.4, yAxisDuration: 1.4, easingOption: .easeOutBack)
        
        let angleFormatter = NumberFormatter() //DegreeFormatter()
        angleFormatter.maximumFractionDigits = 3
        let marker = PolarMarkerView(color: UIColor(white: 180/250, alpha: 1), font: .systemFont(ofSize: 12), textColor: .white,
                                  insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8), angleValueFormatter: angleFormatter)
        marker.chartView = chartView
        marker.minimumSize = CGSize(width: 80, height: 40)
        chartView?.marker = marker
    }

    override func updateChartData() {
        if self.shouldHideData {
            chartView?.data = nil
            return
        }
        
        self.setChartData()
    }
    
    func setChartData() {
        let mult: UInt32 = 100
        let min: UInt32 = 20
        let cnt = 49
        
        let block1: (Int) -> PolarChartDataEntry = { i in return PolarChartDataEntry(radial: Double(arc4random_uniform(mult) + min), theta: Double(i) / 24.0 * Double.pi) }
        var t: Double = -Double.pi / 24
        let block2: (Int) -> PolarChartDataEntry = { i in
            t += Double.pi / 24
            return PolarChartDataEntry(radial: 50 + 50 * cos(3.0 * t), theta: t/* Double.pi / 4 - sin(t)*/) }
        let entries1 = (0..<cnt).map(block1)
        let entries2 = (0..<cnt).map(block2)
        
        let pointBlock: (_ entry: ChartDataEntry, _ dataSetIndex: Int, _ viewPortHandler: ViewPortHandler?) -> String = { (entry, dataSetIndex, viewPortHandler) in
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 3
            
            if let _radial = formatter.string(from: NSNumber(floatLiteral: entry.y)),
               let _theta = formatter.string(from: NSNumber(floatLiteral: entry.x)) {
                return _radial + "\n" + _theta
            }
            else {
                return ""
            }
        }
        
        let set1 = PolarChartDataSet(entries: entries1, label: "Random")
        set1.setColor(UIColor.red)
        set1.fillColor = UIColor.red
        set1.drawFilledEnabled = false
        set1.fillAlpha = 0.7
        set1.lineWidth = 2
        set1.drawHighlightCircleEnabled = true
        set1.drawValuesEnabled = true
        set1.highlightCircleStrokeColor = UIColor.red
        set1.setDrawHighlightIndicators(false)
        set1.polarMode = .cubic
        set1.polarCurvedInterpolation = .normal
        set1.polarHistogram = .skipFirst
        set1.polarClosePath = true
        set1.setCircleColor(.red)
        
        let set2 = PolarChartDataSet(entries: entries2, label: "Sin Wave")
        set2.setColor(UIColor.orange)
        set2.fillColor = UIColor.orange
        set2.drawFilledEnabled = false
        set2.fillAlpha = 0.7
        set2.lineWidth = 2
        set2.drawCirclesEnabled = false
        set2.drawHighlightCircleEnabled = true
        set2.highlightCircleStrokeColor = UIColor.orange
        set2.setDrawHighlightIndicators(false)
        set2.polarMode = .cubic
        set2.polarCurvedInterpolation = .normal
        set2.polarCatmullCustomAlpha = 0.7
//        set2.polarClosePath = true
        set2.setCircleColor(.orange)
//        set2.drawValuesEnabled = true
        
        let data: PolarChartData = [set1, set2]
        data.setValueFont(.systemFont(ofSize: 10, weight: .light))
        data.setValueTextColor(.blue)
        
        chartView?.data = data
        
        (data[0] as! any PolarChartDataSetProtocol).pointFormatter = DefaultPointFormatter(block: pointBlock)
//        (data[1] as! any PolarChartDataSetProtocol).pointFormatter = DefaultPointFormatter(block: pointBlock)
    }
    
    override func optionTapped(_ option: Option) {
        guard let _chartView = chartView,
            let data = chartView?.data else { return }

        switch option {
        case .toggleMajorMinorLabels:
            _chartView.majorAxis.drawLabelsEnabled = !_chartView.majorAxis.drawLabelsEnabled
            _chartView.minorAxis.drawLabelsEnabled = !_chartView.minorAxis.drawLabelsEnabled
            
            _chartView.data?.notifyDataChanged()
            _chartView.notifyDataSetChanged()
            _chartView.setNeedsDisplay()
            
        case .toggleRadialLabels:
            _chartView.radialAxis.drawLabelsEnabled = !_chartView.radialAxis.drawLabelsEnabled
            _chartView.setNeedsDisplay()
            
        case .toggleRotate:
            _chartView.rotationEnabled = !_chartView.rotationEnabled
            
        case .toggleFilled:
            for case let set as PolarChartDataSet in data {
                set.drawFilledEnabled = !set.drawFilledEnabled
            }
            
            _chartView.setNeedsDisplay()
            
        case .toggleHighlightCircle:
            for case let set as PolarChartDataSet in data {
                set.drawHighlightCircleEnabled = !set.drawHighlightCircleEnabled
            }
            _chartView.setNeedsDisplay()
            
        case .animateX:
            _chartView.animate(xAxisDuration: 1.4)
            
        case .animateY:
            _chartView.animate(yAxisDuration: 1.4)
            
        case .animateXY:
            _chartView.animate(xAxisDuration: 1.4, yAxisDuration: 1.4)
            
        case .spin:
            _chartView.spin(duration: 2, fromAngle: _chartView.rotationAngle, toAngle: _chartView.rotationAngle + 360, easingOption: .easeInCubic)
            
        case .togglePolarMode:
            if let polarData = data as? PolarChartData,
               let dataSets = polarData.dataSets as? [PolarChartDataSetProtocol] {
                
                for set in dataSets {
                    var option: Int = set.polarMode.rawValue
                    option = option + 1 == PolarChartDataSet.Mode.optionCount.rawValue ? 0 : option + 1
                    set.polarMode = PolarChartDataSet.Mode(rawValue: option)!
                }
                _chartView.setNeedsDisplay()
            }
        case .togglePolarCurvedInterpolationOption:
            if let polarData = data as? PolarChartData,
               let dataSets = polarData.dataSets as? [PolarChartDataSetProtocol] {
                var needsRedraw = false
                for set in dataSets {
                    if set.polarMode == .cubic {
                        var option: Int = set.polarCurvedInterpolation.rawValue
                        option = option + 1 == PolarChartDataSet.CurvedInterpolationOption.optionCount.rawValue ? 0 : option + 1
                        set.polarCurvedInterpolation = PolarChartDataSet.CurvedInterpolationOption(rawValue: option)!
                        needsRedraw = true
                    }
                }
                if needsRedraw {
                    _chartView.setNeedsDisplay()
                }
            }
        case .togglePolarHistogramOption:
            if let polarData = data as? PolarChartData,
               let dataSets = polarData.dataSets as? [PolarChartDataSetProtocol] {
                var needsRedraw = false
                for set in dataSets {
                    if set.polarMode == .histogram {
                        var option: Int = set.polarHistogram.rawValue
                        option = option + 1 == PolarChartDataSet.HistogramOption.optionCount.rawValue ? 0 : option + 1
                        set.polarHistogram = PolarChartDataSet.HistogramOption(rawValue: option)!
                        needsRedraw = true
                    }
                }
                if needsRedraw {
                    _chartView.setNeedsDisplay()
                }
            }
        default:
            super.handleOption(option, forChartView: _chartView)
        }
    }
    
    // MARK: - ChartViewDelegate
    
    override func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        super.chartValueSelected(chartView, entry: entry, highlight: highlight)
        
        chartView.marker?.refreshContent(entry: entry, highlight: highlight)
    }
}


