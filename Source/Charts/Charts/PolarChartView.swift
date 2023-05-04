//
//  PolarChartView.swift
//  
//
//  Created by Steve Wainwright on 01/04/2023.
//

import Foundation
import CoreGraphics


/// Implementation of the PolarChart chart. It works best
/// when displaying 5-10 entries per DataSet.
public class PolarChartView: ChartViewBase, PolarChartDataProvider, ChartViewDelegate, NSUIGestureRecognizerDelegate {
    
    private var _pinchZoomEnabled = false
    private var _doubleTapToZoomEnabled = true
    private var _dragXEnabled = true
    private var _dragYEnabled = true
    
    private var _scaleXEnabled = true
    private var _scaleYEnabled = true
    
    private var _tapGestureRecognizer: NSUITapGestureRecognizer?
    private var _doubleTapGestureRecognizer: NSUITapGestureRecognizer?
    #if !os(tvOS)
    private var _pinchGestureRecognizer: NSUIPinchGestureRecognizer?
    #endif
    private var _panGestureRecognizer: NSUIPanGestureRecognizer?
    
    /// flag that indicates if a custom viewport offset has been set
    private var _customViewPortEnabled = false
    
    /// flag indicating if the polar grid lines should be drawn or not
    @objc public var drawGridlines = true
    
    /// the object reprsenting the major/minor & radial-axes labels
    @objc public var majorAxis: MajorAxis = MajorAxis()
    @objc public var minorAxis: MinorAxis = MinorAxis()
    @objc public var radialAxis: RadialAxis = RadialAxis()

    private var _majorAxisRenderer: MajorAxisRenderer?
    private var _minorAxisRenderer: MinorAxisRenderer?
    private var _radialAxisRenderer: RadialAxisRenderer?
    
    private var _axisTransformer: Transformer?
    
    /// holds the normalized version of the current rotation angle of the chart
    private var _rotationAngle = CGFloat(270.0)
    
    /// holds the raw version of the current rotation angle of the chart
    private var _rawRotationAngle = CGFloat(270.0)
    
    /// maximum angle for this polar chart
    private var _maxAngle: CGFloat = 360.0
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    internal override func initialize() {
        super.initialize()
        
        renderer = PolarChartRenderer(dataProvider: self, chart: self, animator: chartAnimator, viewPortHandler: viewPortHandler)
        
        _axisTransformer = Transformer(viewPortHandler: viewPortHandler)
        
        _majorAxisRenderer = MajorAxisRenderer(viewPortHandler: viewPortHandler, axis: majorAxis, transformer: _axisTransformer)
        _minorAxisRenderer = MinorAxisRenderer(viewPortHandler: viewPortHandler, axis: minorAxis, associatedMajorAxis: majorAxis, transformer: _axisTransformer)
        _radialAxisRenderer = RadialAxisRenderer(viewPortHandler: viewPortHandler, axis: radialAxis, chart: self, transformer: _axisTransformer)
        
        self.highlighter = PolarHighlighter(chart: self)
        
        _tapGestureRecognizer = NSUITapGestureRecognizer(target: self, action: #selector(tapGestureRecognized(_:)))
        _doubleTapGestureRecognizer = NSUITapGestureRecognizer(target: self, action: #selector(doubleTapGestureRecognized(_:)))
        _doubleTapGestureRecognizer?.nsuiNumberOfTapsRequired = 2
        _panGestureRecognizer = NSUIPanGestureRecognizer(target: self, action: #selector(panGestureRecognized(_:)))
        
        _panGestureRecognizer?.delegate = self
        
        if let __tapGestureRecognizer = _tapGestureRecognizer {
            self.addGestureRecognizer(__tapGestureRecognizer)
        }
        if let __doubleTapGestureRecognizer = _doubleTapGestureRecognizer {
            self.addGestureRecognizer(__doubleTapGestureRecognizer)
        }
        if let __panGestureRecognizer = _panGestureRecognizer {
            self.addGestureRecognizer(__panGestureRecognizer)
        }
        
        _doubleTapGestureRecognizer?.isEnabled = _doubleTapToZoomEnabled
        _panGestureRecognizer?.isEnabled = _dragXEnabled || _dragYEnabled

        #if !os(tvOS)
            _pinchGestureRecognizer = NSUIPinchGestureRecognizer(target: self, action: #selector(pinchGestureRecognized(_:)))
            _pinchGestureRecognizer?.delegate = self
            if let __pinchGestureRecognizer = _pinchGestureRecognizer {
                self.addGestureRecognizer(__pinchGestureRecognizer)
            }
            _pinchGestureRecognizer?.isEnabled = _pinchZoomEnabled || _scaleXEnabled || _scaleYEnabled
        #endif
    }
    
    /// The default IValueFormatter that has been determined by the chart considering the provided minimum and maximum values.
    internal lazy var defaultPointFormatter: PointFormatter = DefaultPointFormatter(decimals: 1)

    @objc public override var data: ChartData? {
        
        didSet {
            calculateOffsets()

            if let data = self.polarData {
                
                // calculate how many digits are needed
                setupDefaultFormatter(min: data.radialMin, max: data.radialMax)
 
                for case let set as PolarChartDataSetProtocol in (data as ChartData) where set.pointFormatter is DefaultPointFormatter {
                    set.pointFormatter = defaultPointFormatter
                }
                
                // let the chart know there is new data
                notifyDataSetChanged()
            }
        }
    }

    /// The minimum theta-value of the chart, regardless of zoom or translation.
    public var chartThetaMin: Double {
        get {
            return self.polarData?.thetaMin ?? 0
        }
    }
    
    /// The maximum theta-value of the chart, regardless of zoom or translation.
    public var chartThetaMax: Double {
        get {
            return self.polarData?.thetaMax ?? 0
        }
    }
    
    /// The minimum radial-value of the chart, regardless of zoom or translation.
    public var chartRadialMin: Double {
        get {
            return self.polarData?.radialMin ?? 0
        }
    }
    
    /// The maximum radial-value of the chart, regardless of zoom or translation.
    public var chartRadialMax: Double {
        get {
            return self.polarData?.radialMax ?? 0
        }
    }
    
    public var maxHighlightRadius: CGFloat {
        get {
            return self.polarData?.radialMax ?? 0
        }
    }
    
    public var thetaRange: Double {
        get {
            return self.polarData?.thetaRange ?? 0
        }
    }
    
    public func isInverted() -> Bool {
        return  self.radialAxis.reversed // is the radial axis ploted clockwise or anticlockwise
    }
    
    public override var maxVisibleCount: Int {
        get {
            return self.polarData?.entryCount ?? 0
        }
    }

    internal override func calcMinMax() {
        if let data = self.polarData {
            majorAxis.calculate(min: -data.radialMax, max: data.radialMax)
            minorAxis.calculate(min: -data.radialMax, max: data.radialMax)
        }
    }
    
    /// Sets the minimum offset (padding) around the chart, defaults to 10
    @objc open var minOffset = CGFloat(10.0)
    
    private var _autoScaleLastLowestVisibleX: Double?
    private var _autoScaleLastHighestVisibleX: Double?
    
    /// Performs auto scaling of the axis by recalculating the minimum and maximum y-values based on the entries currently in view.
    internal func autoScale() {
        if let data = polarData {
            
            data.calcMinMaxRadial(fromTheta: self.lowestVisibleTheta, toTheta: self.highestVisibleTheta)
            radialAxis.calculate(min: data.thetaMin, max: data.thetaMax)
            
            // calculate axis range (min / max) according to provided data
            calcMinMax()
            
            calculateOffsets()
        }
    }
    
    private func prepareValuePxMatrix() {
        _axisTransformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: majorAxis.axisRange, deltaY: minorAxis.axisRange, chartYMin: minorAxis.axisMinimum)
    }
    
    private func prepareOffsetMatrix() {
        _axisTransformer?.prepareMatrixOffset(inverted: majorAxis.isInverted)
    }
    
    public override func notifyDataSetChanged() {
        
        calcMinMax()
        
        let factor = self.factor
        if majorAxis.gridLinesToChartRectEdges {
            let radius: CGFloat = self.contentRect.width / 2 / factor
            majorAxis.axisMinimum = -radius
            majorAxis.axisMaximum = radius
            majorAxis.axisRange = 2 * radius
        }

        if minorAxis.gridLinesToChartRectEdges {
            let radius: CGFloat = self.contentRect.height / 2 / factor
            minorAxis.axisMinimum = -radius
            minorAxis.axisMaximum = radius
            minorAxis.axisRange = 2 * radius
        }
        
        prepareValuePxMatrix()
        prepareOffsetMatrix()
        
        _majorAxisRenderer?.computeAxis(min: majorAxis.axisMinimum.rounded(.awayFromZero), max: majorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
    
        _minorAxisRenderer?.computeAxis(min: minorAxis.axisMinimum.rounded(.awayFromZero), max: minorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
        
        if majorAxis.isEnabled {
            radialAxis.axisDependency = .major
            if majorAxis.gridLinesToChartRectEdges {
                radialAxis.gridLinesToChartRectEdges = true
                let radius: CGFloat = sqrt(pow(self.contentRect.width, 2) + pow(self.contentRect.height, 2)) / 2 / self.factor
                radialAxis.outerCircleRadius = radius
            }
            else {
                radialAxis.outerCircleRadius = majorAxis.axisMaximum
            }
        }
        else if minorAxis.isEnabled {
            radialAxis.axisDependency = .minor
            if minorAxis.gridLinesToChartRectEdges {
                radialAxis.gridLinesToChartRectEdges = true
                let radius: CGFloat = sqrt(pow(self.contentRect.width, 2) + pow(self.contentRect.height, 2)) / 2 / self.factor
                radialAxis.outerCircleRadius = radius
            }
            else {
                radialAxis.outerCircleRadius = minorAxis.axisMaximum
            }
        }
        else {
            radialAxis.axisDependency = .none
        }
        
        _radialAxisRenderer?.computeAxis(min: radialAxis.axisMinimum, max: radialAxis.axisMaximum, inverted: radialAxis.reversed)
        
        if let data = polarData,
            !legend.isLegendCustom  {
            legendRenderer.computeLegend(data: data)
        }
        
        calculateOffsets()
        
        setNeedsDisplay()
    }
    
    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if let _ = self.polarData,
           let renderer = renderer {
            
            let optionalContext = NSUIGraphicsGetCurrentContext()
            if let context = optionalContext {
                
                _majorAxisRenderer?.transformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: CGFloat(majorAxis.axisRange), deltaY: CGFloat(minorAxis.axisRange), chartYMin: minorAxis.axisMinimum)
                _minorAxisRenderer?.transformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: CGFloat(majorAxis.axisRange), deltaY: CGFloat(minorAxis.axisRange), chartYMin: minorAxis.axisMinimum)
                _radialAxisRenderer?.transformer?.prepareMatrixValuePx(chartXMin: majorAxis.axisMinimum, deltaX: CGFloat(majorAxis.axisRange), deltaY: CGFloat(minorAxis.axisRange), chartYMin: minorAxis.axisMinimum)
                
            
                if radialAxis.isEnabled {
                    _radialAxisRenderer?.computeAxis(min: radialAxis.axisMinimum, max: radialAxis.axisMaximum, inverted: radialAxis.reversed)
                    _radialAxisRenderer?.renderAxisLabels(context: context)
                    _radialAxisRenderer?.renderGridLines(context: context)
                }
                
                if majorAxis.isEnabled {
                    _majorAxisRenderer?.computeAxis(min: majorAxis.axisMinimum.rounded(.awayFromZero), max: majorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
                    _majorAxisRenderer?.renderAxisLabels(context: context)
                    _majorAxisRenderer?.renderGridLines(context: context)
                    if !minorAxis.isDrawLimitLinesBehindDataEnabled {
                        _minorAxisRenderer?.renderLimitLines(context: context)
                    }
                }
                
                if minorAxis.isEnabled {
                    _minorAxisRenderer?.computeAxis(min: minorAxis.axisMinimum.rounded(.awayFromZero), max: minorAxis.axisMaximum.rounded(.awayFromZero), inverted: false)
                    _minorAxisRenderer?.renderAxisLabels(context: context)
                    if minorAxis.isDrawLimitLinesBehindDataEnabled {
                        _minorAxisRenderer?.renderLimitLines(context: context)
                    }
                }
                
                renderer.drawData(context: context)
                
                if valuesToHighlight() {
                    renderer.drawHighlighted(context: context, indices: highlighted)
                }
                
                renderer.drawValues(context: context)
                
                renderer.drawExtras(context: context)
                
                legendRenderer.renderLegend(context: context)
                
                drawDescription(in: context)
                
                drawMarkers(context: context)
            }
        }
    }

    /// The factor that is needed to transform values into pixels.
    @objc public var factor: CGFloat {
        let content = viewPortHandler.contentRect
        return min(content.width / CGFloat(majorAxis.axisRange / 2.0), content.height / CGFloat(minorAxis.axisRange))
    }

    // current rotation angle of the pie chart
    ///
    /// **default**: 270 --> top (NORTH)
    /// Will always return a normalized value, which will be between 0.0 < 360.0
    @objc public var rotationAngle: CGFloat{
        get {
            return _rotationAngle
        }
        set {
            _rawRotationAngle = newValue
            _rotationAngle = newValue.normalizedAngle
            setNeedsDisplay()
        }
    }
    
    /// gets the raw version of the current rotation angle of the pie chart the returned value could be any value, negative or positive, outside of the 360 degrees.
    /// this is used when working with rotation direction, mainly by gestures and animations.
    @objc public var rawRotationAngle: CGFloat {
        return _rawRotationAngle
    }
    
    /// The max angle that is used for calculating the pie-circle.
    /// 360 means it's a full pie-chart, 180 results in a half-pie-chart.
    /// **default**: 360.0
    @objc public var maxAngle: CGFloat  {
        get  {
            return _maxAngle
        }
        set  {
            _maxAngle = newValue
            
            if _maxAngle > 360.0 {
                _maxAngle = 360.0
            }
            
            if _maxAngle < 90.0 {
                _maxAngle = 90.0
            }
        }
    }
    
    /// The angle that each slice in the radar chart occupies.
    @objc public var sliceAngle: CGFloat {
        return 360.0 / CGFloat(polarData?.maxEntryCountSet?.entryCount ?? 0)
    }

    public func indexForAngle(_ angle: CGFloat) -> Int {
        // take the current angle of the chart into consideration
        let a = (angle - self.rotationAngle).normalizedAngle
        
        let sliceAngle = self.sliceAngle
        
        let max = polarData?.maxEntryCountSet?.entryCount ?? 0
        return (0..<max).firstIndex { sliceAngle * CGFloat($0 + 1) - sliceAngle / 2.0 > a } ?? 0
    }
    
    /// if width is larger than height
    private var widthLarger: Bool {
        return viewPortHandler.contentRect.orientation == .landscape
    }

    /// adjusted radius. Use diameter when it's half pie and width is larger
    private var adjustedRadius: CGFloat {
        return maxAngle <= 180 && widthLarger ? majorAxis.axisRange  : majorAxis.axisRange / 2.0
    }

    /// true centerOffsets considering half pie & width is larger
    private func adjustedCenterOffsets() -> CGPoint {
        var c = self.centerOffsets
        c.y = maxAngle <= 180 && widthLarger ? c.y + adjustedRadius / 2 : c.y
        return c
    }
    
    /// - Returns: The distance of a certain point on the chart to the center of the chart.
    @objc public func distanceToCenter(x: CGFloat, y: CGFloat) -> CGFloat {
        let c = adjustedCenterOffsets()
        var dist = CGFloat(0.0)

        let xDist = x > c.x ? x - c.x : c.x - x
        let yDist = y > c.y ? y - c.y : c.y - y

        // pythagoras
        dist = sqrt(pow(xDist, 2.0) + pow(yDist, 2.0))

        return dist
    }

    private var requiredLegendOffset: CGFloat  {
        return legend.font.pointSize * 4.0
    }

    private var requiredBaseOffset: CGFloat {
        return majorAxis.isEnabled && majorAxis.isDrawLabelsEnabled ? majorAxis.labelRotatedWidth : 10.0
    }

    public var radius: CGFloat {
        let content = viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0)
    }
    
    /// The lowest theta-index (value on the radial-axis) that is still visible on he chart.
    public var lowestVisibleTheta: Double {
//        var pt = CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentBottom)
//
//        getTransformer(forAxis: .major).pixelToValues(&pt)
//
//        return max(radialAxis.axisMinimum, Double(pt.x))
        return radialAxis.axisMinimum
    }
    
    /// The highest theta-index (value on the radial-axis) that is still visible on the chart.
    public var highestVisibleTheta: Double {
//        var pt = CGPoint(x: viewPortHandler.contentRight, y: viewPortHandler.contentBottom)
//
//        getTransformer(forAxis: .major).pixelToValues(&pt)
//
//        return min(radialAxis.axisMaximum, Double(pt.x))
        return radialAxis.axisMaximum
    }
    
    internal func calculateLegendOffsets(offsetLeft: inout CGFloat, offsetTop: inout CGFloat, offsetRight: inout CGFloat, offsetBottom: inout CGFloat) {
        // setup offsets for legend
        if legend.isEnabled, !legend.drawInside {
            switch legend.orientation {
            case .vertical:
                
                switch legend.horizontalAlignment {
                case .left:
                    offsetLeft += min(legend.neededWidth, viewPortHandler.chartWidth * legend.maxSizePercent) + legend.xOffset
                    
                case .right:
                    offsetRight += min(legend.neededWidth, viewPortHandler.chartWidth * legend.maxSizePercent) + legend.xOffset
                    
                case .center:
                    
                    switch legend.verticalAlignment
                    {
                    case .top:
                        offsetTop += min(legend.neededHeight, viewPortHandler.chartHeight * legend.maxSizePercent) + legend.yOffset
                        
                    case .bottom:
                        offsetBottom += min(legend.neededHeight, viewPortHandler.chartHeight * legend.maxSizePercent) + legend.yOffset
                        
                    default:
                        break
                    }
                }
                
            case .horizontal:
                
                switch legend.verticalAlignment {
                case .top:
                    offsetTop += min(legend.neededHeight, viewPortHandler.chartHeight * legend.maxSizePercent) + legend.yOffset
                    
                case .bottom:
                    offsetBottom += min(legend.neededHeight, viewPortHandler.chartHeight * legend.maxSizePercent) + legend.yOffset
                    
                default:
                    break
                }
            }
        }
    }
    
    internal override func calculateOffsets() {
        if !_customViewPortEnabled {
            var offsetLeft = CGFloat(0.0)
            var offsetRight = CGFloat(0.0)
            var offsetTop = CGFloat(0.0)
            var offsetBottom = CGFloat(0.0)
            
            calculateLegendOffsets(offsetLeft: &offsetLeft, offsetTop: &offsetTop, offsetRight: &offsetRight, offsetBottom: &offsetBottom)

            if majorAxis.isEnabled && majorAxis.isDrawLabelsEnabled {
                let xlabelheight = majorAxis.labelRotatedHeight + majorAxis.yOffset
                
                // offsets for x-labels
                if majorAxis.labelPosition == .bottom {
                    offsetBottom += xlabelheight
                }
                else if majorAxis.labelPosition == .top {
                    offsetTop += xlabelheight
                }
            }
            
            offsetTop += self.extraTopOffset
            offsetRight += self.extraRightOffset
            offsetBottom += self.extraBottomOffset
            offsetLeft += self.extraLeftOffset

            viewPortHandler.restrainViewPort(offsetLeft: max(self.minOffset, offsetLeft), offsetTop: max(self.minOffset, offsetTop), offsetRight: max(self.minOffset, offsetRight), offsetBottom: max(self.minOffset, offsetBottom))
        }
        
        prepareOffsetMatrix()
        prepareValuePxMatrix()
    }
    
    // MARK: Transformer
    
    public func getTransformer(forAxis: RadialAxis.AxisDependency) -> Transformer {
        return _axisTransformer ?? Transformer(viewPortHandler: self.viewPortHandler)
    }
    
    // MARK: - Gestures
    
    private enum GestureScaleAxis {
        case both
        case x
        case y
    }
    
    private var _isDragging = false
    private var _isScaling = false
    private var _gestureScaleAxis = GestureScaleAxis.both
    private var _closestDataSetToTouch: ChartDataSetProtocol!
    private var _panGestureReachedEdge: Bool = false
    private weak var _outerScrollView: NSUIScrollView?
    
    private var _lastPanPoint = CGPoint() /// This is to prevent using setTranslation which resets velocity
    
    private var _decelerationLastTime: TimeInterval = 0.0
    private var _decelerationDisplayLink: NSUIDisplayLink!
    private var _decelerationVelocity = CGPoint()
    
    @objc private func tapGestureRecognized(_ recognizer: NSUITapGestureRecognizer) {
        if data === nil {
            return
        }
        
        if recognizer.state == NSUIGestureRecognizerState.ended {
            if !isHighLightPerTapEnabled {
                return
            }
            
            let h = getHighlightByTouchPoint(recognizer.location(in: self))
            
            if h === nil || h == self.lastHighlighted {
                lastHighlighted = nil
                highlightValue(nil, callDelegate: true)
            }
            else {
                lastHighlighted = h
                highlightValue(h, callDelegate: true)
            }
        }
    }
    
    @objc private func doubleTapGestureRecognized(_ recognizer: NSUITapGestureRecognizer) {
        if data === nil {
            return
        }
        
        if recognizer.state == NSUIGestureRecognizerState.ended {
            if data !== nil && _doubleTapToZoomEnabled && (data?.entryCount ?? 0) > 0 {
                var location = recognizer.location(in: self)
                location.x = location.x - viewPortHandler.offsetLeft
                
//                if isTouchInverted() {
//                    location.y = -(location.y - viewPortHandler.offsetTop)
//                }
//                else {
                    location.y = -(self.bounds.size.height - location.y - viewPortHandler.offsetBottom)
//                }
                
                self.zoom(scaleX: isScaleXEnabled ? 1.4 : 1.0, scaleY: isScaleYEnabled ? 1.4 : 1.0, x: location.x, y: location.y)
                delegate?.chartScaled?(self, scaleX: scaleX, scaleY: scaleY)
            }
        }
    }
    
    #if !os(tvOS)
    @objc private func pinchGestureRecognized(_ recognizer: NSUIPinchGestureRecognizer) {
        if recognizer.state == NSUIGestureRecognizerState.began {
            stopDeceleration()
            
            if data !== nil && (_pinchZoomEnabled || _scaleXEnabled || _scaleYEnabled) {
                _isScaling = true
                
                if _pinchZoomEnabled {
                    _gestureScaleAxis = .both
                }
                else {
                    let x = abs(recognizer.location(in: self).x - recognizer.nsuiLocationOfTouch(1, inView: self).x)
                    let y = abs(recognizer.location(in: self).y - recognizer.nsuiLocationOfTouch(1, inView: self).y)
                    
                    if _scaleXEnabled != _scaleYEnabled {
                        _gestureScaleAxis = _scaleXEnabled ? .x : .y
                    }
                    else {
                        _gestureScaleAxis = x > y ? .x : .y
                    }
                }
            }
        }
        else if recognizer.state == NSUIGestureRecognizerState.ended || recognizer.state == NSUIGestureRecognizerState.cancelled {
            if _isScaling {
                _isScaling = false
                
                // Range might have changed, which means that Y-axis labels could have changed in size, affecting Y-axis size. So we need to recalculate offsets.
                calculateOffsets()
                setNeedsDisplay()
            }
        }
        else if recognizer.state == NSUIGestureRecognizerState.changed {
            let isZoomingOut = (recognizer.nsuiScale < 1)
            var canZoomMoreX = isZoomingOut ? viewPortHandler.canZoomOutMoreX : viewPortHandler.canZoomInMoreX
            var canZoomMoreY = isZoomingOut ? viewPortHandler.canZoomOutMoreY : viewPortHandler.canZoomInMoreY
            
            if _isScaling {
                canZoomMoreX = canZoomMoreX && _scaleXEnabled && (_gestureScaleAxis == .both || _gestureScaleAxis == .x)
                canZoomMoreY = canZoomMoreY && _scaleYEnabled && (_gestureScaleAxis == .both || _gestureScaleAxis == .y)
                if canZoomMoreX || canZoomMoreY {
                    var location = recognizer.location(in: self)
                    location.x = location.x - viewPortHandler.offsetLeft
                    
//                    if isTouchInverted() {
//                        location.y = -(location.y - viewPortHandler.offsetTop)
//                    }
//                    else {
                        location.y = -(viewPortHandler.chartHeight - location.y - viewPortHandler.offsetBottom)
//                    }
                    
                    let scaleX = canZoomMoreX ? recognizer.nsuiScale : 1.0
                    let scaleY = canZoomMoreY ? recognizer.nsuiScale : 1.0
                    
                    var matrix = CGAffineTransform(translationX: location.x, y: location.y)
                    matrix = matrix.scaledBy(x: scaleX, y: scaleY)
                    matrix = matrix.translatedBy(x: -location.x, y: -location.y)
                    
                    matrix = viewPortHandler.touchMatrix.concatenating(matrix)
                    
                    viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: true)

                    if delegate !== nil {
                        delegate?.chartScaled?(self, scaleX: scaleX, scaleY: scaleY)
                    }
                }
                
                recognizer.nsuiScale = 1.0
            }
        }
    }
    #endif
    
    @objc private func panGestureRecognized(_ recognizer: NSUIPanGestureRecognizer) {
        if recognizer.state == NSUIGestureRecognizerState.began && recognizer.nsuiNumberOfTouches() > 0 {
            stopDeceleration()
            
            if data === nil || !self.isDragEnabled { // If we have no data, we have nothing to pan and no data to highlight
                return
            }
            
            // If drag is enabled and we are in a position where there's something to drag:
            //  * If we're zoomed in, then obviously we have something to drag.
            //  * If we have a drag offset - we always have something to drag
            if !self.hasNoDragOffset || !self.isFullyZoomedOut {
                _isDragging = true
                
                _closestDataSetToTouch = getDataSetByTouchPoint(point: recognizer.nsuiLocationOfTouch(0, inView: self))
                
                var translation = recognizer.translation(in: self)
                if !self.dragXEnabled {
                    translation.x = 0.0
                }
                else if !self.dragYEnabled {
                    translation.y = 0.0
                }
                
                let didUserDrag = translation.x != 0.0 || translation.y != 0.0
                
                // Check to see if user dragged at all and if so, can the chart be dragged by the given amount
                if didUserDrag && !performPanChange(translation: translation) {
                    if _outerScrollView !== nil {
                        // We can stop dragging right now, and let the scroll view take control
                        _outerScrollView = nil
                        _isDragging = false
                    }
                }
                else {
                    if _outerScrollView !== nil {
                        // Prevent the parent scroll view from scrolling
                        _outerScrollView?.nsuiIsScrollEnabled = false
                    }
                }
                
                _lastPanPoint = recognizer.translation(in: self)
            }
            else if self.isHighlightPerDragEnabled {
                // We will only handle highlights on NSUIGestureRecognizerState.Changed
                
                _isDragging = false
                
                // Prevent the parent scroll view from scrolling
                _outerScrollView?.nsuiIsScrollEnabled = false
            }
        }
        else if recognizer.state == NSUIGestureRecognizerState.changed {
            if _isDragging {
                let originalTranslation = recognizer.translation(in: self)
                var translation = CGPoint(x: originalTranslation.x - _lastPanPoint.x, y: originalTranslation.y - _lastPanPoint.y)
                
                if !self.dragXEnabled {
                    translation.x = 0.0
                }
                else if !self.dragYEnabled {
                    translation.y = 0.0
                }
                
                let _ = performPanChange(translation: translation)
                
                _lastPanPoint = originalTranslation
            }
            else if isHighlightPerDragEnabled {
                let h = getHighlightByTouchPoint(recognizer.location(in: self))
                
                let lastHighlighted = self.lastHighlighted
                
                if h != lastHighlighted {
                    self.lastHighlighted = h
                    self.highlightValue(h, callDelegate: true)
                }
            }
        }
        else if recognizer.state == NSUIGestureRecognizerState.ended || recognizer.state == NSUIGestureRecognizerState.cancelled {
            if _isDragging {
                if recognizer.state == NSUIGestureRecognizerState.ended && isDragDecelerationEnabled {
                    stopDeceleration()
                    
                    _decelerationLastTime = CACurrentMediaTime()
                    _decelerationVelocity = recognizer.velocity(in: self)
                    
                    _decelerationDisplayLink = NSUIDisplayLink(target: self, selector: #selector(decelerationLoop))
                    _decelerationDisplayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
                }
                _isDragging = false
            }
            
            if _outerScrollView !== nil {
                _outerScrollView?.nsuiIsScrollEnabled = true
                _outerScrollView = nil
            }

            delegate?.chartViewDidEndPanning?(self)
        }
    }
    
    private func performPanChange(translation: CGPoint) -> Bool {
        let translation = translation
        
//        if isTouchInverted() {
//            if self is HorizontalBarChartView {
//                translation.x = -translation.x
//            }
//            else {
//                translation.y = -translation.y
//            }
//        }
        
        let originalMatrix = viewPortHandler.touchMatrix
        
        var matrix = CGAffineTransform(translationX: translation.x, y: translation.y)
        matrix = originalMatrix.concatenating(matrix)
        
        matrix = viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: true)
        
        if matrix != originalMatrix {
            delegate?.chartTranslated?(self, dX: translation.x, dY: translation.y)
        }
        
        // Did we managed to actually drag or did we reach the edge?
        return matrix.tx != originalMatrix.tx || matrix.ty != originalMatrix.ty
    }
    
    
    @objc public func stopDeceleration() {
        if _decelerationDisplayLink !== nil
        {
            _decelerationDisplayLink.remove(from: RunLoop.main, forMode: RunLoop.Mode.common)
            _decelerationDisplayLink = nil
        }
    }
    
    @objc private func decelerationLoop() {
        let currentTime = CACurrentMediaTime()
        
        _decelerationVelocity.x *= self.dragDecelerationFrictionCoef
        _decelerationVelocity.y *= self.dragDecelerationFrictionCoef
        
        let timeInterval = CGFloat(currentTime - _decelerationLastTime)
        
        let distance = CGPoint(x: _decelerationVelocity.x * timeInterval, y: _decelerationVelocity.y * timeInterval)
        
        if !performPanChange(translation: distance) {
            // We reached the edge, stop
            _decelerationVelocity.x = 0.0
            _decelerationVelocity.y = 0.0
        }
        
        _decelerationLastTime = currentTime
        
        if abs(_decelerationVelocity.x) < 0.001 && abs(_decelerationVelocity.y) < 0.001 {
            stopDeceleration()
            
            // Range might have changed, which means that Y-axis labels could have changed in size, affecting Y-axis size. So we need to recalculate offsets.
            calculateOffsets()
            setNeedsDisplay()
        }
    }
    
    private func nsuiGestureRecognizerShouldBegin(_ gestureRecognizer: NSUIGestureRecognizer) -> Bool {
        if gestureRecognizer == _panGestureRecognizer,
        let __panGestureRecognizer = _panGestureRecognizer {
            let velocity = __panGestureRecognizer.velocity(in: self)
            if data === nil || !isDragEnabled || (self.hasNoDragOffset && self.isFullyZoomedOut && !self.isHighlightPerDragEnabled) || (!_dragYEnabled && abs(velocity.y) > abs(velocity.x)) || (!_dragXEnabled && abs(velocity.y) < abs(velocity.x)) {
                return false
            }
        }
        else {
            #if !os(tvOS)
                if gestureRecognizer == _pinchGestureRecognizer {
                    if data === nil || (!_pinchZoomEnabled && !_scaleXEnabled && !_scaleYEnabled) {
                        return false
                    }
                }
            #endif
        }
        
        return true
    }
    
#if os(OSX)
    public func gestureRecognizerShouldBegin(gestureRecognizer: NSUIGestureRecognizer) -> Bool {
        return nsuiGestureRecognizerShouldBegin(gestureRecognizer)
    }
#else
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: NSUIGestureRecognizer) -> Bool {
        if !super.gestureRecognizerShouldBegin(gestureRecognizer) {
            return false
        }
        return nsuiGestureRecognizerShouldBegin(gestureRecognizer)
    }
#endif
    
    public func gestureRecognizer(_ gestureRecognizer: NSUIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSUIGestureRecognizer) -> Bool {
        #if !os(tvOS)
            if ((gestureRecognizer is NSUIPinchGestureRecognizer && otherGestureRecognizer is NSUIPanGestureRecognizer) || (gestureRecognizer is NSUIPanGestureRecognizer && otherGestureRecognizer is NSUIPinchGestureRecognizer)) {
                return true
            }
        #endif
        
        if gestureRecognizer is NSUIPanGestureRecognizer,
            otherGestureRecognizer is NSUIPanGestureRecognizer,
            gestureRecognizer == _panGestureRecognizer {
            var scrollView = self.superview
            while scrollView != nil && !(scrollView is NSUIScrollView) {
                scrollView = scrollView?.superview
            }
            
            // If there is two scrollview together, we pick the superview of the inner scrollview.
            // In the case of UITableViewWrepperView, the superview will be UITableView
            if let superViewOfScrollView = scrollView?.superview,
                superViewOfScrollView is NSUIScrollView {
                scrollView = superViewOfScrollView
            }

            var foundScrollView = scrollView as? NSUIScrollView
            
            if !(foundScrollView?.nsuiIsScrollEnabled ?? true) {
                foundScrollView = nil
            }
            
            let scrollViewPanGestureRecognizer = foundScrollView?.nsuiGestureRecognizers?.first {
                $0 is NSUIPanGestureRecognizer
            }
            
            if otherGestureRecognizer === scrollViewPanGestureRecognizer {
                _outerScrollView = foundScrollView
                
                return true
            }
        }
        
        return false
    }
    
    /// MARK: Viewport modifiers
    
    /// Zooms in by 1.4, into the charts center.
    @objc public func zoomIn() {
        let center = viewPortHandler.contentCenter
        
        let matrix = viewPortHandler.zoomIn(x: center.x, y: -center.y)
        viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: false)
        
        // Range might have changed, which means that Y-axis labels could have changed in size, affecting Y-axis size. So we need to recalculate offsets.
        calculateOffsets()
        setNeedsDisplay()
    }

    /// Zooms out by 0.7, from the charts center.
    @objc public func zoomOut() {
        let center = viewPortHandler.contentCenter
        
        let matrix = viewPortHandler.zoomOut(x: center.x, y: -center.y)
        viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: false)

        // Range might have changed, which means that Y-axis labels could have changed in size, affecting Y-axis size. So we need to recalculate offsets.
        calculateOffsets()
        setNeedsDisplay()
    }
    
    /// Zooms out to original size.
    @objc public func resetZoom() {
        let matrix = viewPortHandler.resetZoom()
        viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: false)

        // Range might have changed, which means that Y-axis labels could have changed in size, affecting Y-axis size. So we need to recalculate offsets.
        calculateOffsets()
        setNeedsDisplay()
    }

    /// Zooms in or out by the given scale factor. x and y are the coordinates
    /// (in pixels) of the zoom center.
    ///
    /// - Parameters:
    ///   - scaleX: if < 1 --> zoom out, if > 1 --> zoom in
    ///   - scaleY: if < 1 --> zoom out, if > 1 --> zoom in
    ///   - x:
    ///   - y:
    @objc public func zoom(scaleX: CGFloat, scaleY: CGFloat, x: CGFloat, y: CGFloat) {
        let matrix = viewPortHandler.zoom(scaleX: scaleX, scaleY: scaleY, x: x, y: -y)
        viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: false)

        // Range might have changed, which means that Y-axis labels could have changed in size, affecting Y-axis size. So we need to recalculate offsets.
        calculateOffsets()
        setNeedsDisplay()
    }
    
    /// Zooms in or out by the given scale factor.
    /// x and y are the values (**not pixels**) of the zoom center.
    ///
    /// - Parameters:
    ///   - scaleX: if < 1 --> zoom out, if > 1 --> zoom in
    ///   - scaleY: if < 1 --> zoom out, if > 1 --> zoom in
    ///   - xValue:
    ///   - yValue:
    ///   - axis:
    @objc public func zoom(scaleX: CGFloat, scaleY: CGFloat, xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency) {
        
        let yAxis = YAxis()
        yAxis.axisMinimum = minorAxis.axisMinimum
        yAxis.axisMaximum = minorAxis.axisMaximum
        yAxis.axisRange = minorAxis.axisRange
        
        let job = ZoomViewJob(viewPortHandler: viewPortHandler, scaleX: scaleX, scaleY: scaleY, xValue: xValue, yValue: yValue, transformer: getTransformer(forAxis: axis), axis: yAxis.axisDependency, view: self)
        addViewportJob(job)
    }
    
    /// Zooms to the center of the chart with the given scale factor.
    ///
    /// - Parameters:
    ///   - scaleX: if < 1 --> zoom out, if > 1 --> zoom in
    ///   - scaleY: if < 1 --> zoom out, if > 1 --> zoom in
    ///   - xValue:
    ///   - yValue:
    ///   - axis:
    @objc public func zoomToCenter(scaleX: CGFloat, scaleY: CGFloat) {
        let center = centerOffsets
        let matrix = viewPortHandler.zoom(scaleX: scaleX, scaleY: scaleY, x: center.x, y: -center.y)
        viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: false)
    }
    
    /// Zooms by the specified scale factor to the specified values on the specified axis.
    ///
    /// - Parameters:
    ///   - scaleX:
    ///   - scaleY:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func zoomAndCenterViewAnimated(scaleX: CGFloat, scaleY: CGFloat, xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval, easing: ChartEasingFunctionBlock?) {
        let origin = valueForTouchPoint(point: CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentTop), axis: axis)
        
        let yAxis = YAxis()
        yAxis.axisMinimum = minorAxis.axisMinimum
        yAxis.axisMaximum = minorAxis.axisMaximum
        yAxis.axisRange = minorAxis.axisRange
        
        let job = AnimatedZoomViewJob(viewPortHandler: viewPortHandler, transformer: getTransformer(forAxis: axis), view: self, yAxis: yAxis, xAxisRange: majorAxis.axisRange, scaleX: scaleX, scaleY: scaleY, xOrigin: viewPortHandler.scaleX, yOrigin: viewPortHandler.scaleY, zoomCenterX: CGFloat(xValue), zoomCenterY: CGFloat(yValue), zoomOriginX: origin.x, zoomOriginY: origin.y, duration: duration, easing: easing)
            
        addViewportJob(job)
    }
    
    /// Zooms by the specified scale factor to the specified values on the specified axis.
    ///
    /// - Parameters:
    ///   - scaleX:
    ///   - scaleY:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func zoomAndCenterViewAnimated(scaleX: CGFloat, scaleY: CGFloat, xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval, easingOption: ChartEasingOption) {
        zoomAndCenterViewAnimated(scaleX: scaleX, scaleY: scaleY, xValue: xValue, yValue: yValue, axis: axis, duration: duration, easing: easingFunctionFromOption(easingOption))
    }
    
    /// Zooms by the specified scale factor to the specified values on the specified axis.
    ///
    /// - Parameters:
    ///   - scaleX:
    ///   - scaleY:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func zoomAndCenterViewAnimated(scaleX: CGFloat, scaleY: CGFloat, xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval) {
        zoomAndCenterViewAnimated(scaleX: scaleX, scaleY: scaleY, xValue: xValue, yValue: yValue, axis: axis, duration: duration, easingOption: .easeInOutSine)
    }
    
    /// Resets all zooming and dragging and makes the chart fit exactly it's bounds.
    @objc public func fitScreen() {
        let matrix = viewPortHandler.fitScreen()
        viewPortHandler.refresh(newMatrix: matrix, chart: self, invalidate: false)
        
        calculateOffsets()
        setNeedsDisplay()
    }
    
    /// Sets the minimum scale value to which can be zoomed out. 1 = fitScreen
    @objc public func setScaleMinima(_ scaleX: CGFloat, scaleY: CGFloat) {
        viewPortHandler.setMinimumScaleX(scaleX)
        viewPortHandler.setMinimumScaleY(scaleY)
    }
    
    @objc public var visibleXRange: Double{
        return majorAxis.axisRange
    }
    
    /// Sets the size of the area (range on the radial-axis) that should be maximum visible at once (no further zooming out allowed).
    ///
    /// If this is e.g. set to 10, no more than a range of 10 values on the radial-axis can be viewed at once without scrolling.
    ///
    /// If you call this method, chart must have data or it has no effect.
    @objc public func setVisibleXRangeMaximum(_ maxXRange: Double){
        let xScale = majorAxis.axisRange / maxXRange
        viewPortHandler.setMinimumScaleX(CGFloat(xScale))
    }
    
    /// Sets the size of the area (range on the x-axis) that should be minimum visible at once (no further zooming in allowed).
    ///
    /// If this is e.g. set to 10, no less than a range of 10 values on the x-axis can be viewed at once without scrolling.
    ///
    /// If you call this method, chart must have data or it has no effect.
    @objc public func setVisibleXRangeMinimum(_ minXRange: Double)
    {
        let xScale = majorAxis.axisRange / minXRange
        viewPortHandler.setMaximumScaleX(CGFloat(xScale))
    }

    /// Limits the maximum and minimum value count that can be visible by pinching and zooming.
    ///
    /// e.g. minRange=10, maxRange=100 no less than 10 values and no more that 100 values can be viewed
    /// at once without scrolling.
    ///
    /// If you call this method, chart must have data or it has no effect.
    @objc public func setVisibleXRange(minXRange: Double, maxXRange: Double)
    {
        let minScale = majorAxis.axisRange / maxXRange
        let maxScale = majorAxis.axisRange / minXRange
        viewPortHandler.setMinMaxScaleX(minScaleX: CGFloat(minScale), maxScaleX: CGFloat(maxScale))
    }
    
    /// Sets the size of the area (range on the y-axis) that should be maximum visible at once.
    ///
    /// - Parameters:
    ///   - yRange:
    ///   - axis: - the axis for which this limit should apply
    @objc public func setVisibleYRangeMaximum(_ maxYRange: Double) {
        let yScale = minorAxis.axisRange / maxYRange
        viewPortHandler.setMinimumScaleY(CGFloat(yScale))
    }
    
    /// Sets the size of the area (range on the y-axis) that should be minimum visible at once, no further zooming in possible.
    ///
    /// - Parameters:
    ///   - yRange:
    ///   - axis: - the axis for which this limit should apply
    @objc public func setVisibleYRangeMinimum(_ minYRange: Double)
    {
        let yScale = minorAxis.axisRange / minYRange
        viewPortHandler.setMaximumScaleY(CGFloat(yScale))
    }

    /// Limits the maximum and minimum y range that can be visible by pinching and zooming.
    ///
    /// - Parameters:
    ///   - minYRange:
    ///   - maxYRange:
    ///   - axis:
    @objc public func setVisibleYRange(minYRange: Double, maxYRange: Double) {
        let minScale = minorAxis.axisRange / minYRange
        let maxScale = minorAxis.axisRange / maxYRange
        viewPortHandler.setMinMaxScaleY(minScaleY: CGFloat(minScale), maxScaleY: CGFloat(maxScale))
    }
    
    /// Moves the left side of the current viewport to the specified x-value.
    /// This also refreshes the chart by calling setNeedsDisplay().
    @objc public func moveViewToX(_ xValue: Double) {
        let job = MoveViewJob(viewPortHandler: viewPortHandler, xValue: xValue, yValue: 0.0, transformer: getTransformer(forAxis: .major), view: self)
        
        addViewportJob(job)
    }

    /// Centers the viewport to the specified y-value on the y-axis.
    /// This also refreshes the chart by calling setNeedsDisplay().
    ///
    /// - Parameters:
    ///   - yValue:
    ///   - axis: - which axis should be used as a reference for the major-axis
    @objc public func moveViewToY(_ yValue: Double, axis: RadialAxis.AxisDependency) {
        let yInView = minorAxis.axisRange / Double(viewPortHandler.scaleY)
        
        let job = MoveViewJob(viewPortHandler: viewPortHandler, xValue: 0.0, yValue: yValue + yInView / 2.0, transformer: getTransformer(forAxis: axis), view: self)
        
        addViewportJob(job)
    }

    /// This will move the left side of the current viewport to the specified x-value on the x-axis, and center the viewport to the specified y-value on the y-axis.
    /// This also refreshes the chart by calling setNeedsDisplay().
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: - which axis should be used as a reference for the y-axis
    @objc public func moveViewTo(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency) {
        let yInView = minorAxis.axisRange / Double(viewPortHandler.scaleY)
        
        let job = MoveViewJob(viewPortHandler: viewPortHandler, xValue: xValue, yValue: yValue + yInView / 2.0, transformer: getTransformer(forAxis: axis), view: self)
        
        addViewportJob(job)
    }
    
    /// This will move the left side of the current viewport to the specified x-position and center the viewport to the specified y-position animated.
    /// This also refreshes the chart by calling setNeedsDisplay().
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func moveViewToAnimated(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval, easing: ChartEasingFunctionBlock?) {
        let bounds = valueForTouchPoint(point: CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentTop), axis: axis)
        
        let yInView = minorAxis.axisRange / Double(viewPortHandler.scaleY)
        
        let job = AnimatedMoveViewJob(viewPortHandler: viewPortHandler, xValue: xValue, yValue: yValue + yInView / 2.0, transformer: getTransformer(forAxis: axis), view: self, xOrigin: bounds.x, yOrigin: bounds.y, duration: duration, easing: easing)
        
        addViewportJob(job)
    }
    
    /// This will move the left side of the current viewport to the specified x-position and center the viewport to the specified y-position animated.
    /// This also refreshes the chart by calling setNeedsDisplay().
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func moveViewToAnimated(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval, easingOption: ChartEasingOption) {
        moveViewToAnimated(xValue: xValue, yValue: yValue, axis: axis, duration: duration, easing: easingFunctionFromOption(easingOption))
    }
    
    /// This will move the left side of the current viewport to the specified x-position and center the viewport to the specified y-position animated.
    /// This also refreshes the chart by calling setNeedsDisplay().
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func moveViewToAnimated(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval) {
        moveViewToAnimated(xValue: xValue, yValue: yValue, axis: axis, duration: duration, easingOption: .easeInOutSine)
    }
    
    /// This will move the center of the current viewport to the specified x-value and y-value.
    /// This also refreshes the chart by calling setNeedsDisplay().
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: - which axis should be used as a reference for the y-axis
    @objc public func centerViewTo(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency) {
        let yInView = minorAxis.axisRange / Double(viewPortHandler.scaleY)
        let xInView = majorAxis.axisRange / Double(viewPortHandler.scaleX)
        
        let job = MoveViewJob(viewPortHandler: viewPortHandler, xValue: xValue - xInView / 2.0, yValue: yValue + yInView / 2.0, transformer: getTransformer(forAxis: axis), view: self)
        
        addViewportJob(job)
    }
    
    /// This will move the center of the current viewport to the specified x-value and y-value animated.
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func centerViewToAnimated(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval, easing: ChartEasingFunctionBlock?) {
        let bounds = valueForTouchPoint(point: CGPoint(x: viewPortHandler.contentLeft, y: viewPortHandler.contentTop), axis: axis)
        
        let yInView = minorAxis.axisRange / Double(viewPortHandler.scaleY)
        let xInView = majorAxis.axisRange / Double(viewPortHandler.scaleX)
        
        let job = AnimatedMoveViewJob(viewPortHandler: viewPortHandler, xValue: xValue - xInView / 2.0, yValue: yValue + yInView / 2.0, transformer: getTransformer(forAxis: axis), view: self, xOrigin: bounds.x, yOrigin: bounds.y, duration: duration, easing: easing)
        
        addViewportJob(job)
    }
    
    /// This will move the center of the current viewport to the specified x-value and y-value animated.
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func centerViewToAnimated(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval, easingOption: ChartEasingOption) {
        centerViewToAnimated(xValue: xValue, yValue: yValue, axis: axis, duration: duration, easing: easingFunctionFromOption(easingOption))
    }
    
    /// This will move the center of the current viewport to the specified x-value and y-value animated.
    ///
    /// - Parameters:
    ///   - xValue:
    ///   - yValue:
    ///   - axis: which axis should be used as a reference for the y-axis
    ///   - duration: the duration of the animation in seconds
    ///   - easing:
    @objc public func centerViewToAnimated(xValue: Double, yValue: Double, axis: RadialAxis.AxisDependency, duration: TimeInterval)  {
        centerViewToAnimated(xValue: xValue, yValue: yValue, axis: axis, duration: duration, easingOption: .easeInOutSine)
    }

    /// Sets custom offsets for the current `ChartViewPort` (the offsets on the sides of the actual chart window). Setting this will prevent the chart from automatically calculating it's offsets. Use `resetViewPortOffsets()` to undo this.
    /// ONLY USE THIS WHEN YOU KNOW WHAT YOU ARE DOING, else use `setExtraOffsets(...)`.
    @objc public func setViewPortOffsets(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) {
        _customViewPortEnabled = true
        
        if Thread.isMainThread {
            self.viewPortHandler.restrainViewPort(offsetLeft: left, offsetTop: top, offsetRight: right, offsetBottom: bottom)
            prepareOffsetMatrix()
            prepareValuePxMatrix()
        }
        else {
            DispatchQueue.main.async(execute: {
                self.setViewPortOffsets(left: left, top: top, right: right, bottom: bottom)
            })
        }
    }

    /// Resets all custom offsets set via `setViewPortOffsets(...)` method. Allows the chart to again calculate all offsets automatically.
    @objc public func resetViewPortOffsets() {
        _customViewPortEnabled = false
        calculateOffsets()
    }

    // MARK: - Accessors
    
    /// - Returns: The position (in pixels) the provided Entry has inside the chart view
    @objc public func getPosition(entry e: PolarChartDataEntry, axis: RadialAxis.AxisDependency) -> CGPoint {
        
        let centre: CGPoint = .zero
        var vals = centre.moving(distance: e.radial, atAngle: e.theta, radians: self.radialAxis.radialAngleMode ?? .radians == .radians)

        getTransformer(forAxis: axis).pointValueToPixel(&vals)

        return vals
    }
    
    /// is dragging enabled? (moving the chart with the finger) for the chart (this does not affect scaling).
    @objc public var dragEnabled: Bool {
        get {
            return _dragXEnabled || _dragYEnabled
        }
        set {
            _dragYEnabled = newValue
            _dragXEnabled = newValue
        }
    }
    
    /// is dragging enabled? (moving the chart with the finger) for the chart (this does not affect scaling).
    @objc public var isDragEnabled: Bool {
        return dragEnabled
    }
    
    /// is dragging on the X axis enabled?
    @objc public var dragXEnabled: Bool {
        get {
            return _dragXEnabled
        }
        set {
            _dragXEnabled = newValue
        }
    }
    
    /// is dragging on the Y axis enabled?
    @objc public var dragYEnabled: Bool {
        get {
            return _dragYEnabled
        }
        set {
            _dragYEnabled = newValue
        }
    }
    
    /// flag that indicates if pinch-zoom is enabled. if true, both x and y axis can be scaled simultaneously with 2 fingers, if false, x and y axis can be scaled separately
    @objc public var pinchZoomEnabled: Bool {
        get {
            return _pinchZoomEnabled
        }
        set {
            if _pinchZoomEnabled != newValue {
                _pinchZoomEnabled = newValue
                #if !os(tvOS)
                    _pinchGestureRecognizer?.isEnabled = _pinchZoomEnabled || _scaleXEnabled || _scaleYEnabled
                #endif
            }
        }
    }

    /// **default**: false
    /// `true` if pinch-zoom is enabled, `false` ifnot
    @objc public var isPinchZoomEnabled: Bool { return pinchZoomEnabled }

    /// Set an offset in dp that allows the user to drag the chart over it's
    /// bounds on the x-axis.
    @objc public func setDragOffsetX(_ offset: CGFloat)
    {
        viewPortHandler.setDragOffsetX(offset)
    }

    /// Set an offset in dp that allows the user to drag the chart over it's
    /// bounds on the y-axis.
    @objc public func setDragOffsetY(_ offset: CGFloat)
    {
        viewPortHandler.setDragOffsetY(offset)
    }

    /// `true` if both drag offsets (x and y) are zero or smaller.
    @objc public var hasNoDragOffset: Bool { return viewPortHandler.hasNoDragOffset }

    
    /// is scaling enabled? (zooming in and out by gesture) for the chart (this does not affect dragging).
    @objc public func setScaleEnabled(_ enabled: Bool) {
        if _scaleXEnabled != enabled || _scaleYEnabled != enabled {
            _scaleXEnabled = enabled
            _scaleYEnabled = enabled
            #if !os(tvOS)
                _pinchGestureRecognizer?.isEnabled = _pinchZoomEnabled || _scaleXEnabled || _scaleYEnabled
            #endif
        }
    }
    
    @objc public var scaleXEnabled: Bool {
        get {
            return _scaleXEnabled
        }
        set {
            if _scaleXEnabled != newValue {
                _scaleXEnabled = newValue
                #if !os(tvOS)
                    _pinchGestureRecognizer?.isEnabled = _pinchZoomEnabled || _scaleXEnabled || _scaleYEnabled
                #endif
            }
        }
    }
    
    @objc public var scaleYEnabled: Bool {
        get {
            return _scaleYEnabled
        }
        set {
            if _scaleYEnabled != newValue {
                _scaleYEnabled = newValue
                #if !os(tvOS)
                    _pinchGestureRecognizer?.isEnabled = _pinchZoomEnabled || _scaleXEnabled || _scaleYEnabled
                #endif
            }
        }
    }
    
    @objc public var isScaleXEnabled: Bool { return scaleXEnabled }
    
    @objc public var isScaleYEnabled: Bool { return scaleYEnabled }
    
    /// The current x-scale factor
    @objc public var scaleX: CGFloat {
        return viewPortHandler.scaleX
    }

    /// The current y-scale factor
    @objc public var scaleY: CGFloat {
        return viewPortHandler.scaleY
    }
    
    /// if the chart is fully zoomed out, return true
    @objc public var isFullyZoomedOut: Bool { return viewPortHandler.isFullyZoomedOut }
    
    /// flag that indicates if double tap zoom is enabled or not
    @objc public  var doubleTapToZoomEnabled: Bool {
        get {
            return _doubleTapToZoomEnabled
        }
        set {
            if _doubleTapToZoomEnabled != newValue {
                _doubleTapToZoomEnabled = newValue
                _doubleTapGestureRecognizer?.isEnabled = _doubleTapToZoomEnabled
            }
        }
    }
    
    /// **default**: true
    /// `true` if zooming via double-tap is enabled `false` ifnot.
    @objc public  var isDoubleTapToZoomEnabled: Bool {
        return doubleTapToZoomEnabled
    }
    
    /// flag that indicates if highlighting per dragging over a fully zoomed out chart is enabled
    @objc public  var highlightPerDragEnabled = true
    
    /// If set to true, highlighting per dragging over a fully zoomed out chart is enabled
    /// You might want to disable this when using inside a `NSUIScrollView`
    ///
    /// **default**: true
    @objc public  var isHighlightPerDragEnabled: Bool {
        return highlightPerDragEnabled
    }
    
    /// - Returns: The x and y values in the chart at the given touch point
    /// (encapsulated in a `CGPoint`). This method transforms pixel coordinates to
    /// coordinates / values in the chart. This is the opposite method to
    /// `getPixelsForValues(...)`.
    @objc public func valueForTouchPoint(point pt: CGPoint, axis: RadialAxis.AxisDependency) -> CGPoint
    {
        return getTransformer(forAxis: axis).valueForTouchPoint(pt)
    }

    /// Transforms the given chart values into pixels. This is the opposite
    /// method to `valueForTouchPoint(...)`.
    @objc public func pixelForValues(x: Double, y: Double, axis: RadialAxis.AxisDependency) -> CGPoint
    {
        return getTransformer(forAxis: axis).pixelForValues(x: x, y: y)
    }
    
    /// - Returns: The Entry object displayed at the touched position of the chart
    @objc public func getEntryByTouchPoint(point pt: CGPoint) -> ChartDataEntry!
    {
        if let h = getHighlightByTouchPoint(pt)
        {
            return data!.entry(for: h)
        }
        return nil
    }
    
    /// - Returns: The DataSet object displayed at the touched position of the chart
    @objc public func getDataSetByTouchPoint(point pt: CGPoint) -> BarLineScatterCandleBubbleChartDataSetProtocol?
    {
        guard let h = getHighlightByTouchPoint(pt) else {
            return nil
        }

        return data?[h.dataSetIndex] as? BarLineScatterCandleBubbleChartDataSetProtocol
    }
    
    
    // MARK: - LineChartDataProvider
    
    public var polarData: PolarChartData? { return data as? PolarChartData }
}
