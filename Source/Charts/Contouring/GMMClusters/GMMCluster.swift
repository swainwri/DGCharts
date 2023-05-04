//
//  GMMCluster.swift
//  DiscontinuityMeshGenerator
//
//  Ported by Steve Wainwright on 15/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

let SIGNATURE_TYPE_MIXED = 1

class GMMCluster: NSObject {
    var init_num_of_subclasses: Int     // #_subclasses - initial number of clusters for each class
    var nclasses: Int                   // <# of classes>
    var vector_dimension: Int           // <data vector length>
    var option1: GMMClusterModel        // option1 - (optional) controls clustering model\n");
                                                                //      full - (default) use full convariance matrices\n");
                                                                //      diag - use diagonal convariance matrices\n\n");
    var option2: Int                       //    option2 - (optional) controls number of clusters\n");
                                            //      0 - (default) estimate number of clusters\n");
                                            //      n - use n clusters in mixture model with n<#_subclasses");

    private var samples: [[GMMPoint]] = [[]] // dimension nclasses by _vector_dimension
    private var S: SigSet?, Sout: SigSet?
    private var trainedSamples:[[GMMPoint]]?
    
    private var useFilesForInput: Bool
    private var usedExternalSamples: Bool
    private var usedExternalTrainedSamples: Bool
    
    var errorString: String?
    
    // Initialise
    
    override init() {
        self.init_num_of_subclasses = 20
        self.nclasses = 1
        self.vector_dimension = 2
        self.option1 = .full
        self.option2 = 0
        useFilesForInput = false
        usedExternalSamples = false
        usedExternalTrainedSamples = false
    }
    
    convenience init(usingGMMPointsWithInitialSubclasses _init_num_of_subclasses: Int, noClasses: Int,
                     vector_dimension: Int, samples:[[GMMPoint]], option1: GMMClusterModel = .full, option2: Int = 0) {
        self.init()
        
        self.init_num_of_subclasses = _init_num_of_subclasses
        self.nclasses = noClasses
        self.vector_dimension = vector_dimension
        self.samples = samples
        self.option1 = option1
        self.option2 = option2
        useFilesForInput = false
        usedExternalSamples = true
        usedExternalTrainedSamples = false
    }
    
    convenience init(usingGMMPointsWithNoClasses noClasses: Int, vector_dimension: Int, samples:[[GMMPoint]], option1: GMMClusterModel = .full, option2: Int = 0) {
        self.init()
        
        self.nclasses = noClasses
        self.vector_dimension = vector_dimension
        self.samples = samples
        self.option1 = option1
        self.option2 = option2
        self.useFilesForInput = false
        self.usedExternalSamples = true
    }
    
    convenience init(usingClassesFromFile infoFileURL: URL) {
        self.init()
        let readInfoFile = GMMIOUtility.readFileContents(fileURL: infoFileURL)
        if let infoFileLines = readInfoFile.lines,
           !infoFileLines.isEmpty {
            let dataURL = infoFileURL.deletingLastPathComponent()
            let spaceSet = CharacterSet(charactersIn: " ")
//            let tabSet = CharacterSet(charactersIn: "\t")
            var items: [String] = []
            items = infoFileLines[0].components(separatedBy: spaceSet) as [String]
            GMMIOUtility.trimDownArray(&items)
            var valid = items[0].isContainsNumerics
            if valid,
               let nclasses = Int(items[0]) {
                self.nclasses = nclasses
                items = infoFileLines[1].components(separatedBy: spaceSet) as [String]
                GMMIOUtility.trimDownArray(&items)
                valid = items[0].isContainsNumerics
                if valid,
                   let vector_dimension = Int(items[0]) {
                    self.vector_dimension = vector_dimension
                }
                else {
                    errorString = "Parser Exception: the vector dimension value is not a number on Data Line 2!"
                }
                S = SigSet()
                S?.nclasses = self.nclasses
                S?.nbands = self.vector_dimension
                S?.title = "test signature set"
                
                if var _S = self.S {
                    for i in 0..<self.nclasses {
                        items = infoFileLines[2+i].components(separatedBy: spaceSet) as [String]
                        GMMIOUtility.trimDownArray(&items)
                        if items.count > 1 {
                            var completedDataURL: URL
                            if #available(iOS 16.0, *) {
                                completedDataURL = dataURL.appending(path: items[0])
                            } else {
                                completedDataURL = URL(fileURLWithPath: dataURL.absoluteString + "/" + items[0])
                            }
                            valid = items[1].isContainsNumerics
                            if valid,
                               let num_of_samples = Int(items[1]) {
                                let readDataFile = GMMIOUtility.readFileContents(fileURL: completedDataURL)
                                if let dataFileLines = readDataFile.lines,
                                   !dataFileLines.isEmpty {
                                    _S.classSig.append(ClassSig())
                                    var sig = _S.classSig[i]
                                    sig.classData.x.removeAll()
                                    for j in 0..<num_of_samples {
                                        items = dataFileLines[j].components(separatedBy: spaceSet) as [String]
                                        GMMIOUtility.trimDownArray(&items)
                                        if items.count == self.vector_dimension {
                                            sig.classData.x.append([0, 0])
                                            sig.classData.npixels += 1
                                            for k in 0..<self.vector_dimension {
                                                valid = items[k].isContainsNumericsNegativeOrPoint
                                                if valid,
                                                   let value = Double(items[k]) {
                                                    sig.classData.x[j][k] = value
                                                }
                                            }
                                        }
                                    }
                                    sig.classData.SummedWeights = 0.0
                                    sig.classData.w = Array(repeating: 1, count: sig.classData.npixels)
                                    for i in 0..<sig.classData.npixels {
                                        sig.classData.SummedWeights += sig.classData.w[i]
                                    }
                                    sig.copy(sig: &(_S.classSig[i]), nbands: self.vector_dimension, copyClassData: true)
                                }
                                else {
                                    errorString = "Parser Exception: the Data filename is not a valid on Data Line \(i + 2)!"
                                }
                            }
                        }
                    }
                    self.S?.classSig = _S.classSig
                }
            }
            else {
                errorString = "Parser Exception: the noClasses value is not a number on Data Line 1!"
            }
        }
        else {
            errorString = "Error:can't open info file!"
        }
        if errorString != "" {
            self.useFilesForInput = true
            self.usedExternalSamples = false
        }
        
    }
    
//    -(nonnull instancetype)initUsingNSArrayWithInitialSubclasses:(NSInteger)_init_num_of_subclasses noClasses:(NSInteger)_nclasses  vector_dimension:(NSInteger)_vector_dimension samples:(NSMutableArray<NSMutableArray<NSMutableArray<NSNumber*>*>*>*)objcSamples option1:(GMMClusterModel)_option1 option2:(NSInteger)_option2;

//    -(void)initialiseUsingNSArrayWithNoClasses:(NSInteger)_nclasses vector_dimension:(NSInteger)_vector_dimension samples:(NSMutableArray<NSMutableArray<NSMutableArray<NSNumber*>*>*>*)objcSamples;

 
    func cluster() -> Void {
        
        if !self.useFilesForInput {
            /* Initialize SigSet data structure */
            self.S = SigSet()
            self.S?.nbands = self.vector_dimension
            self.S?.title = "test signature set"

            if var _S = self.S {
                /* Allocate memory for cluster signatures */
                /* then Read data for each class */
                for i in 0..<self.nclasses {
                    var sig = ClassSig()
                    sig.initialise(S: &_S)
                    sig.title = "test class signature"
                    for _ in 0..<self.init_num_of_subclasses {
                        var subSig = SubSig()
                        subSig.initialise(S: _S)
                        if sig.nsubclasses == 0 {
                            sig.subSig = [subSig]
                        }
                        else {
                            sig.subSig.append(subSig)
                        }
                        sig.nsubclasses += 1
                    }
                    sig.classData = ClassData()
                    sig.classData.npixels = samples[i].count
                    sig.classData.x = Array(repeating: Array(repeating: 0, count: self.vector_dimension), count: sig.classData.npixels)
                    for j in 0..<sig.classData.npixels {
                        for k in 0..<self.vector_dimension {
                            sig.classData.x[j][k] = samples[i][j].v[k]
                        }
                    }
                    sig.classData.p = Array(repeating: Array(repeating: 0, count: self.init_num_of_subclasses), count: sig.classData.npixels)
                    
                    /* Set unity weights and compute SummedWeights */
                    sig.classData.SummedWeights = 0.0
                    sig.classData.w = Array(repeating: 0, count: sig.classData.npixels)
                    for j in 0..<sig.classData.npixels {
                        sig.classData.w[j] = 1.0;
                        sig.classData.SummedWeights += sig.classData.w[j]
                    }
                    sig.copy(sig: &(_S.classSig[i]), nbands: self.vector_dimension, copyClassData: true)
                }
                self.S?.nclasses = _S.nclasses
                self.S?.classSig = _S.classSig
            }
        }
        else {
            if var _S = self.S {
                for i in 0..<self.nclasses {
                    _S.classSig[i].classData.p.removeAll()
                    _S.classSig[i].classData.p = Array(repeating: Array(repeating: 0, count: self.init_num_of_subclasses), count: _S.classSig[i].classData.npixels)
                    for _ in 0..<self.init_num_of_subclasses {
                        var subSig = SubSig()
                        subSig.initialise(S: _S)
                        if _S.classSig[i].nsubclasses == 0 {
                            _S.classSig[i].subSig = [subSig]
                        }
                        else {
                            _S.classSig[i].subSig.append(subSig)
                        }
                        _S.classSig[i].nsubclasses += 1
                    }
                }
                self.S?.nclasses = _S.nclasses
                self.S?.classSig = _S.classSig
            }
        }
        if var _S = S {
            /* Compute the average variance over all classes */
            var Rmin: Double = 0
            for k in 0..<self.nclasses {
                Rmin += averageVariance(sig: _S.classSig[k], nbands: self.vector_dimension)
            }
            Rmin = Rmin / (COVAR_DYNAMIC_RANGE * Double(self.nclasses))
            
            var max_num = self.nclasses * 2
            let subcluster = GMMSubCluster()
            /* Perform clustering for each class */
            for k in 0..<self.nclasses {
                if 1 <= clusterMessageVerboseLevel {
                    print("Start clustering class \(k)\n\n")
                }
                /* assume covariance matrices to be diagonal */
                /* no assumption for covariance matrices */
                let _ = subcluster.subcluster(S: _S, class_Index: k, desired_num: self.option2, option: self.option1, Rmin: Rmin, Max_num: &max_num)
                subcluster.S?.classSig[k].copy(sig: &(_S.classSig[k]), nbands:self.vector_dimension)
                
                _S.classSig[k].classnum = k + 1
                _S.classSig[k].title = "test class \(k + 1) signature"
                if 2 <= clusterMessageVerboseLevel  {
                    print("Maximum number of subclasses = \(max_num)\n")
                }
            }
            self.S = _S
        }
    }
    
    func clusterToParametersFile(_ paramsURL: URL) -> Void {
        
        cluster()
        
        if let _S = S {
            let outputString = _S.writeSigSet()
            let writeFile = GMMIOUtility.writeFile(outputString, fileURL: paramsURL)
            if !writeFile.status {
                print(writeFile.error)
            }
        }
    }
    
    func averageVariance(sig: ClassSig, nbands: Int) -> Double {
        /* Compute the mean of variance for each band */
        var mean: [Double] = Array(repeating: 0, count: nbands)
        var R: [[Double]] = Array(repeating: Array(repeating: 0, count: nbands), count: nbands)
        
        for b1 in 0..<nbands {
            mean[b1] = 0.0
            for i in 0..<sig.classData.npixels {
                mean[b1] += sig.classData.x[i][b1] * sig.classData.w[i]
            }
            mean[b1] /= sig.classData.SummedWeights
        }

        for b1 in 0..<nbands {
            R[b1][b1] = 0.0
            for i in 0..<sig.classData.npixels {
                R[b1][b1] += sig.classData.x[i][b1] * sig.classData.x[i][b1] * sig.classData.w[i]
            }
            R[b1][b1] /= sig.classData.SummedWeights
            R[b1][b1] -= mean[b1] * mean[b1]
        }

        /* Compute average of diagonal entries */
        var Rmin: Double = 0.0
        for b1 in 0..<nbands {
            Rmin += R[b1][b1]
        }
        Rmin = Rmin / Double(nbands)

        return Rmin
    }
    
//    func classify() -> Void {
//        /* Initialize constants for Log likelihood calculations */
//        if var _S = S {
//            let classify = GMMClassify()
//            classify.classLogLikelihood_init(S: &_S)
//            
//            /* Compute Log likelihood for each class*/
//            var ll: [Double] = Array(repeating: 0, count: _S.nclasses)
//            
//            var maxval: Double
//            var maxindex: Int
//            for i in 0..<samples[0].count {
//                classify.classLogLikelihood(point: samples[0][i], ll: &ll, S: _S)
//                maxval = ll[0]
//                maxindex = 0
//                for j in 0..<_S.nclasses {
//                    if ll[j] > maxval {
//                        maxval = ll[j]
//                        maxindex = j
//                    }
//                }
//                for j in 0..<_S.nclasses {
//                   print("Loglike = \(ll[j]) ")
//                }
//                print("ML Class = \(maxindex)\n")
//            }
//        }
//    }
    
//    func classify(usingGMMPoints samplePoints: [[GMMPoint]]) -> Void {
//        trainedSamples = samplePoints
//        self.usedExternalTrainedSamples = true
//    }
//
//    func classify(withDataURL dataURL: URL) -> Void {
//
//        let readDataFile = GMMIOUtility.readFileContents(fileURL: dataURL)
//        if let dataFileLines = readDataFile.lines,
//           !dataFileLines.isEmpty,
//           let _S = S {
//            let noDataVectors = dataFileLines.count / _S.nbands
//            let spaceSet = CharacterSet(charactersIn: " ")
//            self.trainedSamples = [[]]
//            var items: [String]
//            var valid: Bool
//            for i in 0..<noDataVectors {
//                self.trainedSamples?.append([])
//                if var _trainedSamples = self.trainedSamples?[i] {
//                    for j in 0..<_S.nbands {
//                        items = dataFileLines[j].components(separatedBy: spaceSet) as [String]
//                        if items.count == self.vector_dimension {
//                            var point : GMMPoint = GMMPoint()
//                            for k in 0..<self.vector_dimension {
//                                valid = items[k].isContainsNumericsNegativeOrPoint
//                                if valid,
//                                   let value = Double(items[k]) {
//                                    point.v[k] = value
//                                }
//                            }
//                            _trainedSamples.append(point)
//                        }
//                    }
//                }
//            }
//            self.usedExternalTrainedSamples = false
//         }
//    }

//    -(void)classifyUsingNSArray:(NSMutableArray<NSMutableArray<NSNumber*>*>*)objcSamples;

//    func splitClasses() -> Void {
//        /* Initialize SigSet data structure */
//        if let _S = S {
//            Sout = SigSet()
//            Sout?.nbands = _S.nbands
//            Sout?.title = "signature set for unsupervised clustering"
//            if var _Sout = Sout {
//                /* Copy each subcluster (subsignature) from input to cluster (class signature) of output */
//                for k in 0..<_S.nclasses {
//                    for l in 0..<_S.classSig[k].nsubclasses {
//                        var sig = ClassSig()
//                        sig.initialise(S: &_Sout)
//                        sig.title = "Single Model Class"
//                        sig.subSig = [SubSig()]
//                        sig.subSig[0].pi = 1.0
//                        for i in 0..<_S.nbands {
//                            sig.subSig[0].means[i] = _S.classSig[k].subSig[l].means[i]
//                        }
//                        for i in 0..<_S.nbands {
//                            for j in 0..<_S.nbands {
//                                sig.subSig[0].R[i][j] = _S.classSig[k].subSig[l].R[i][j]
//                            }
//                        }
//                    }
//                }
//            }
//        }
//    }
    
//    func splitClasses(withParametersOutputFile paramsURL: URL) -> Void {
//
//        splitClasses()
//        if let _Sout = Sout {
//            let output = _Sout.writeSigSet()
//            let _ = GMMIOUtility.writeFile(output, fileURL: paramsURL)
//        }
//
//    }

    var signatureSet: SigSet? {
        get {
            return S
        }
    }
    
    var outSignatureSet: SigSet? {
        get {
            return Sout
        }
    }
    
    private func eigenValuesAndEigenVectorsOfCoVariance(subSig: SubSig, eigenValues: inout [Double], eigenVectors: inout [[Double]], dimension: Int) -> Void {
        for i in 0..<dimension {
            for j in 0..<dimension {
                eigenVectors[i][j] = subSig.R[i][j]
            }
        }
        GMMEigen.eigen(M: &eigenVectors, lambda: &eigenValues, n: dimension)
    }
    
}

extension String {
    var isContainsNumerics : Bool {
        let allowed = CharacterSet.decimalDigits
        return self.rangeOfCharacter(from: allowed) != nil
    }
    
}
