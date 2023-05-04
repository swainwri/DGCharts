//
//  GMMClassify.swift
//  DiscontinuityMeshGenerator
//
//  Ported by Steve Wainwright on 16/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

class GMMClassify: NSObject {

    var S: SigSet?
    var data: [GMMPoint] = []
    
    var classifiedIndices: [[Int]]?

    private var useFilesForInput: Bool = false
    private var noDataVectors: Int = 0

    override init() {
        self.useFilesForInput = false
        self.noDataVectors = 0
    }
    
    convenience init(parametersURL: URL, dataURL: URL) {
        self.init()
        self.useFilesForInput = false
        let readParamsFile = GMMIOUtility.readFileContents(fileURL: parametersURL)
        if let pFileLines = readParamsFile.lines,
           !pFileLines.isEmpty{
            self.S = SigSet()
            self.S?.readSigSet(pFileLines)
            readData(dataURL: dataURL)
        }
        else {
            print("Can't open parameters file\n")
        }
    }
    
    convenience init(parametersURL: URL, data: [GMMPoint]) {
        self.init()
        self.useFilesForInput = false
        let readParamsFile = GMMIOUtility.readFileContents(fileURL: parametersURL)
        if let pFileLines = readParamsFile.lines,
           !pFileLines.isEmpty{
            self.S = SigSet()
            self.S?.readSigSet(pFileLines)
            self.data = data
            self.noDataVectors = self.data.count
        }
        else {
            print("Can't open parameters file\n")
        }
        
    }
    
    convenience init(S: SigSet, dataURL: URL) {
        self.init()
        self.useFilesForInput = false
        self.S = S
        readData(dataURL: dataURL)
    }
    
    convenience init(S: SigSet, data: [GMMPoint]) {
        self.init()
        self.useFilesForInput = false
        self.S = S
        self.data = data
        self.noDataVectors = self.data.count
    }
    
    private func readData(dataURL: URL) -> Void {
        let readDataFile = GMMIOUtility.readFileContents(fileURL: dataURL)
        if let dFileLines = readDataFile.lines,
           !dFileLines.isEmpty {
            var items: [String] = []
            let spaceSet = CharacterSet(charactersIn: " ")
            let tabSet = CharacterSet(charactersIn: "\t")
            var OK = true
            for i in 0..<dFileLines.count {
                var point = GMMPoint()
                items = dFileLines[i].components(separatedBy: spaceSet) as [String]
                GMMIOUtility.trimDownArray(&items)
                if items.count < 2 {
                    items = dFileLines[0].components(separatedBy: tabSet) as [String]
                }
                if items.count > 1 {
                    var valid = items[0].isContainsNumericsNegativeOrPoint
                    if valid,
                       let x = Double(items[0]) {
                        point.x = x
                    }
                    valid = items[1].isContainsNumericsNegativeOrPoint
                    if valid,
                        let y = Double(items[1]) {
                        point.y = y
                    }
                    if items.count > 2 {
                        valid = items[2].isContainsNumericsNegativeOrPoint
                        if valid,
                            let z = Double(items[2]) {
                            point.z = z
                        }
                    }
                    self.data.append(point)
                    self.noDataVectors += 1
                }
                else {
                    OK = false
                    print("Can't parse data file line \(i)")
                }
            }
            if OK {
                self.useFilesForInput = true
            }
        }
        else {
            print("Can't open data file")
        }
    }
     
    func classify() -> Void {
        
        if var _S = self.S {
            /* Initialize constants for Log likelihood calculations */
            classLogLikelihood_init(S: &_S)

            /* Compute Log likelihood for each class*/
            var ll: [Double] = Array(repeating: 0.0, count: _S.nclasses)
            var maxval: Double
            var maxindex: Int = 0
            
            var logLikeOutputString: String = ""
            
            classifiedIndices = Array(repeating: [], count: _S.nclasses)
            for k in 0..<_S.nclasses {
                classifiedIndices?[k] = []
            }
            
            for i in 0..<self.noDataVectors {
                classLogLikelihood(point: data[i], ll: &ll, S: _S)
                maxval = ll[0]
                maxindex = 0
                for j in 0..<_S.nclasses {
                    if ll[j] > maxval {
                        maxval = ll[j]
                        maxindex = j
                    }
                }
                logLikeOutputString = ""
                for j in 0..<_S.nclasses {
                    logLikeOutputString += "Loglike = \(ll[j]) "
                }
                print( "#\(i) \(logLikeOutputString) ML Class = \(maxindex)\n")
                classifiedIndices?[maxindex].append(i)
            }
        }
    }
    
    //double *ll,        /* log likelihood, ll[class] */
    //struct SigSet *S   /* class signatures */
    private func classLogLikelihood(point: GMMPoint, ll: inout [Double], S: SigSet) -> Void {
        
        var maxlike = -Double.greatestFiniteMagnitude
        var subsum: Double = 0
            
        let nbands = S.nbands; /* number of spectral bands */

        /* determine the maximum number of subclasses */
        var max_nsubclasses: Int = 0;  /* maximum number of subclasses */
        for m in 0..<S.nclasses {
            if S.classSig[m].nsubclasses > max_nsubclasses {
                max_nsubclasses = S.classSig[m].nsubclasses;
            }
        }
        /* allocate memory */
        var diff: [Double] = Array(repeating: 0.0, count: nbands)
        var subll: [Double] = Array(repeating: 0.0, count: max_nsubclasses)/* log likelihood of subclasses */
            
        /* Compute log likelihood for each class */
        /* for each class */
        for m in 0..<S.nclasses {
            let C = S.classSig[m]
            /* compute log likelihood for each subclass */
            for k in 0..<C.nsubclasses {
                let subS = C.subSig[k]
                subll[k] = subS.cnst
                for b1 in 0..<nbands {
                    diff[b1] = point.v[b1] - subS.means[b1]
                    subll[k] -= 0.5 * diff[b1] * diff[b1] * subS.Rinv[b1][b1];
                }
                for b1 in 0..<nbands {
                    for b2 in b1 + 1..<nbands {
                        subll[k] -= diff[b1] * diff[b2] * subS.Rinv[b1][b2];
                    }
                }
            }
                
            /* shortcut for one subclass */
            if C.nsubclasses == 1 {
                ll[m] = subll[0]
            }
            /* compute mixture likelihood */
            else {
                /* find the most likely subclass */
                for k in 0..<C.nsubclasses {
                    if k == 0 {
                        maxlike = subll[k]
                    }
                    if subll[k] > maxlike {
                        maxlike = subll[k]
                    }
                }
                
                /* Sum weighted subclass likelihoods */
                subsum = 0
                for k in 0..<C.nsubclasses {
                    subsum += exp(subll[k] - maxlike) * C.subSig[k].pi
                }
                ll[m] = log(subsum) + maxlike
            }
        }
    }

    private func classLogLikelihood_init(S: inout SigSet) -> Void {
        
        let nbands = S.nbands
        /* allocate scratch memory */
        var lambda: [Double] = Array(repeating: 0.0, count: nbands)
        var det_man: Double = 0
        var det_exp: Int = 0
        /* invert matrix and compute constant for each subclass */
        /* for each class */
        for m in 0..<S.nclasses {
            var C = S.classSig[m]
            print("Class \(m)")
            /* for each subclass */
            for i in 0..<C.nsubclasses {
                var subS = C.subSig[i]
                /* Test for symetric  matrix */
                for b1 in 0..<nbands {
                    for b2 in 0..<nbands {
                        if subS.R[b1][b2] != subS.R[b2][b1] {
                            print("Warning: nonsymetric covariance for class \(m) ")
                        }
                        print("Subclass \(i)")
                        subS.Rinv[b1][b2] = subS.R[b1][b2]
                    }
                }

                /* Test for positive definite matrix */
                
                GMMEigen.eigen(M: &(subS.Rinv), lambda: &lambda, n: nbands)
                for b1 in 0..<nbands {
                    if lambda[b1] <= 0.0  {
                        print("Warning: nonpositive eigenvalues for class \(m)")
                        print("Subclass \(i)")
                    }
                }

                /* Precomputes the cnst */
                subS.cnst = (-Double(nbands) / 2.0) * log(2 * .pi);
                for b1 in 0..<nbands {
                    subS.cnst += -0.5 * log(lambda[b1])
                }

                /* Precomputes the inverse of tex->R */
                let _ = GMMInvert.invert(a: &(subS.Rinv), n: nbands, det_man: &det_man, det_exp: &det_exp)
                subS.copy(subSig: &(C.subSig[i]), nbands: nbands)
            }
            C.copy(sig: &(S.classSig[m]), nbands: nbands)
        }
    }
}
