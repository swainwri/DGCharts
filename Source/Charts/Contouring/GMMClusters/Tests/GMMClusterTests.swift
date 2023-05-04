//
//  GMMClusterTests.swift
//  GMMClusterTests
//
//  Created by Steve Wainwright on 19/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import XCTest
@testable import DGCharts

final class GMMClusterTests: XCTestCase {
    
    var cluster: GMMCluster?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
    func testClusterUsingInputFile() {
        let bundle = Bundle(for: Self.self)
        if let urlInfo = bundle.url(forResource: "info_file1", withExtension: "") {
            cluster = GMMCluster(usingClassesFromFile: urlInfo)
            if let urlParams = bundle.url(forResource: "params1", withExtension: ""),
               let _cluster = cluster {
                _cluster.clusterToParametersFile(urlParams)
            }
        }
    }

    func testClusterUsingInputFileWith2Classes() {
        let bundle = Bundle(for: Self.self)
        if let urlInfo = bundle.url(forResource: "info_file2", withExtension: "") {
            cluster = GMMCluster(usingClassesFromFile: urlInfo)
            if let urlParams = bundle.url(forResource: "params2", withExtension: ""),
               let _cluster = cluster {
                _cluster.clusterToParametersFile(urlParams)
                if let urlTestData = bundle.url(forResource: "TestingData2", withExtension: "") {
//                    let classify = GMMClassify(parametersURL: urlParams, dataURL: urlTestData)
                    if let _S = _cluster.signatureSet {
                        let classify = GMMClassify(S: _S, dataURL: urlTestData)
                        classify.classify()
                    }
                }
            }
        }
    }
    
    func testClusterUsingGMMPoints() {
        let bundle = Bundle(for: Self.self)
        if let urlData = bundle.url(forResource: "data3", withExtension: "") {
            let readDataFile = GMMIOUtility.readFileContents(fileURL: urlData)
            if let dataFileLines = readDataFile.lines,
               !dataFileLines.isEmpty {
                let nbands = dataFileLines.count
                let spaceSet = CharacterSet(charactersIn: " ")
                var samples: [[GMMPoint]] = [[]]
                var items: [String]
                var valid: Bool

                for j in 0..<nbands {
                    items = dataFileLines[j].components(separatedBy: spaceSet) as [String]
                    GMMIOUtility.trimDownArray(&items)
                    if items.count == 2 {
                        var point : GMMPoint = GMMPoint()
                        for k in 0..<2 {
                            valid = items[k].isContainsNumericsNegativeOrPoint
                            if valid,
                               let value = Double(items[k]) {
                                point.v[k] = value
                            }
                        }
                        samples[0].append(point)
                    }
                }

                cluster = GMMCluster(usingGMMPointsWithNoClasses: 1, vector_dimension: 2, samples: samples, option1: .full, option2: 0)
                if let urlParams = bundle.url(forResource: "params3", withExtension: ""),
                   let _cluster = cluster {
                    _cluster.clusterToParametersFile(urlParams)
                    var classify: GMMClassify
                    if let urlParamsSplit = bundle.url(forResource: "params3split", withExtension: "") {
                        let _ = GMMSplitClasses(inputParameterURL: urlParams, outputParameterURL:urlParamsSplit)
                        classify = GMMClassify(parametersURL: urlParamsSplit, dataURL: urlData)
                        classify.classify()
                    }
                    else if let _S = _cluster.signatureSet {
                        let splitClasses = GMMSplitClasses(S: _S)
                        if let _Sout = splitClasses.Sout {
                            classify = GMMClassify(S: _Sout, dataURL: urlData)
//                            classify = GMMClassify(parametersURL: urlParams, data: samples[0])
                            classify.classify()
                            if let _classGroupsIndices = classify.classifiedIndices {
                                print(_classGroupsIndices)
                            }
                        }
                    }
                }
            }
        }
    }
}
