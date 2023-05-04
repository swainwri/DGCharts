//
//  GMMSplitClasses.swift
//  DiscontinuityMeshGenerator
//
//  Created by Steve Wainwright on 26/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation


// Usage: InputParameters OutputParameters
// InputParameters separates GMM components into individual classes.
// This can be useful for unsupervised segmentation applications

class GMMSplitClasses: NSObject {
    
    var errorString: String?
    
    private var Sin: SigSet?
    public var Sout: SigSet?
    
    convenience init(inputParameterURL: URL, outputParameterURL: URL) {
        self.init()
        
        let readParameterFile = GMMIOUtility.readFileContents(fileURL: inputParameterURL)
        if let parameterFileLines = readParameterFile.lines,
           !parameterFileLines.isEmpty {
            self.Sin = SigSet()
            self.Sin?.readSigSet(parameterFileLines)
            
            createSplitSigsetClasses(outputParameterURL: outputParameterURL)
        }
        else {
            errorString = "Error: Can't open input parameter file!"
        }
    }
    
    convenience init(S: SigSet) {
        self.init()
        self.Sin = S
        
        createSplitSigsetClasses(outputParameterURL: nil)
    }
    
    private func createSplitSigsetClasses(outputParameterURL: URL?) -> Void {
        if let _Sin = self.Sin {
            self.Sout = SigSet()
            self.Sout?.nbands = _Sin.nbands
            self.Sout?.title = "signature set for unsupervised clustering"
            
            if var _Sout = self.Sout {
                /* Copy each subcluster (subsignature) from input to cluster (class signature) of output */
                for i in 0..<_Sin.nclasses {
                    for j in 0..<_Sin.classSig[i].nsubclasses {
                        let m = i * (_Sin.nclasses + 1) + j
                        _Sout.classSig.append(ClassSig())
                        _Sout.nclasses += 1
                        _Sout.classSig[m].title = "Single Model Class"
                        _Sout.classSig[m].classnum = m
                        var subSig = SubSig()
                        subSig.initialise(S: _Sout)
                        _Sout.classSig[m].subSig.append(subSig)
                        _Sout.classSig[m].nsubclasses = 1
                        _Sout.classSig[m].subSig[0].pi = 1.0
                        for k in 0..<_Sin.nbands {
                            _Sout.classSig[m].subSig[0].means[k] = _Sin.classSig[i].subSig[j].means[k]
                        }
                        for k in 0..<_Sin.nbands {
                            for l in 0..<_Sin.nbands {
                                _Sout.classSig[m].subSig[0].R[k][l] = _Sin.classSig[i].subSig[j].R[k][l]
                            }
                        }
                        _Sout.classSig[m].used = true
                    }
                }
                self.Sout = _Sout
                if let _outputParameterURL = outputParameterURL {
                    let outputString = _Sout.writeSigSet()
                    let writeFile = GMMIOUtility.writeFile(outputString, fileURL: _outputParameterURL)
                    if !writeFile.status {
                        errorString = writeFile.error.description
                        print(writeFile.error)
                    }
                }
            }
            else {
                errorString = "System Error: Unable to initialise the output SigSet!"
            }
        }
        else {
            errorString = "System Error: Unable to initialise the input SigSet!"
        }
    }
}
