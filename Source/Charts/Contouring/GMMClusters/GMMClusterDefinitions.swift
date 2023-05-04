//
//  GMMClusterDefinitions.swift
//  DiscontinuityMeshGenerator
//
//  Created by Steve Wainwright on 15/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

/**
 *  @brief Enumeration ofclustering model options
 **/

enum GMMClusterModel : Int16 {
    case full = 0 ///< full
    case diagonal ///< diagonal
}

/*****************************************************/
/* This constant determines the ratio of the average */
/* covariance to the minimum allowed covariance.     */
/* It is used to insure that the measured covariance */
/* is not singular. It may need to be adjusted for   */
/* different applications.                           */
/*****************************************************/
let COVAR_DYNAMIC_RANGE: Double = 1E5

/* set level of diagnostic printing */
var clusterMessageVerboseLevel: Int = 2

/// A structure that contains a point in a two-dimensional coordinate system.
struct GMMPoint: Hashable {
    var v: [Double] = [0, 0, 0]
    var x: Double {
        get {
            return v[0]
        }
        set (newValue) {
            v[0] = newValue
        }
    }
    var y: Double {
        get {
            return v[1]
        }
        set (newValue) {
            v[1] = newValue
        }
    }
    var z: Double {
        get {
            return v[2]
        }
        set (newValue) {
            v[2] = newValue
        }
    }
    
    init() {
        self.v = [0, 0, 0]
    }
    
    init(v: [Double]) {
        self.v = v
    }
    
    init(x: Double, y: Double, z: Double = 0) {
        self.v[0] = x
        self.v[1] = y
        self.v[2] = z
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(UInt(bitPattern: x.hashValue))
        hasher.combine(UInt(bitPattern: y.hashValue))
        hasher.combine(UInt(bitPattern: z.hashValue))
    }
}

/* SigSet (Signature Set) data stucture used throughout package.         */
/*   ClassSig (Class Signature) data stucture holds the parameters       */
/*       of a single Gaussian mixture model. SigSet.nclasses is the      */
/*       number of ClassSig's in a SigSet.                               */
/*     SubSig (Subsignature) data stucture holds each component of a     */
/*         Gaussian mixture model. SigSet.ClassSig[k].nsubclasses is the */
/*         number of SubSig's in a ClassSig.                             */

struct ClassData {
    var SummedWeights: Double
    var x: [[Double]] /* list of pixel vectors:     x[npixels][nbands] */
    var p: [[Double]] /* prob pixel is in subclass: p[npixels][subclasses] */
    var w: [Double] /* weight of pixel:           w[npixels] */
    var npixels: Int
    
    init() {
        self.SummedWeights = 0
        self.x = [[]]
        self.p = [[]]
        self.w = []
        npixels = 0
    }
    
    init(S: SigSet, C: ClassSig, npixels: Int) {
        self.SummedWeights = 0
        self.x = Array(repeating: Array(repeating: 0, count: S.nbands), count: npixels)
        self.p = Array(repeating: Array(repeating: 0, count: C.nsubclasses), count: npixels)
        self.w = Array(repeating: 0, count: npixels)
        self.npixels = npixels
    }
    
    func copy(classData: inout ClassData) -> Void {
        classData.SummedWeights = self.SummedWeights
        classData.x.removeAll()
        classData.x =  Array(repeating: Array(repeating: 0, count: self.x[0].count), count: self.npixels)
        for i in 0..<self.x.count {
            for j in 0..<self.x[0].count {
                classData.x[i][j] = self.x[i][j]
            }
        }
        classData.p.removeAll()
        classData.p =  Array(repeating: Array(repeating: 0, count: self.p[0].count), count: self.npixels)
        for i in 0..<self.p.count {
            for j in 0..<self.p[0].count {
                classData.p[i][j] = self.p[i][j]
            }
        }
        classData.w.removeAll()
        classData.w =  Array(repeating: 0, count: self.npixels)
        for i in 0..<self.w.count {
            classData.w[i] = self.w[i]
        }
        classData.npixels = self.npixels
    }
}

struct SubSig {
    var N: Double         /* expected number of pixels in subcluster */
    var pi: Double        /* probability of component in GMM */
    var means: [Double]   /* mean of component in GMM */
    var R: [[Double]]     /* convarance of component in GMM */
    var Rinv: [[Double]]  /* inverse of R */
    var cnst: Double      /* normalizing constant for multivariate Gaussian */
    var used: Bool
    
    init() {
        self.N = 0
        self.pi = 0
        self.means = []
        self.R = []
        self.Rinv = []
        self.cnst = 0
        self.used = false
    }
    
    mutating func initialise(S: SigSet) {
        self.used = true
        self.R = Array(repeating: Array(repeating: 0, count: S.nbands), count: S.nbands)
        self.Rinv = Array(repeating: Array(repeating: 0, count: S.nbands), count: S.nbands)
        self.means = Array(repeating: 0, count: S.nbands)
        self.N = 0
        self.pi = 0
        self.cnst = 0
    }
    
    /***************************/
    /* copy to subSig2 */
    /***************************/
    func copy(subSig: inout SubSig, nbands: Int) -> Void {
        
        subSig.N = self.N
        subSig.pi = self.pi
        subSig.cnst = self.cnst
        subSig.used = self.used
        
        if subSig.means.isEmpty {
            subSig.means = Array(repeating: 0, count: nbands)
        }
        if subSig.R.isEmpty {
            subSig.R = Array(repeating: Array(repeating: 0, count: nbands), count: nbands)
        }
        if subSig.Rinv.isEmpty {
            subSig.Rinv = Array(repeating: Array(repeating: 0, count: nbands), count: nbands)
        }

        for b1 in 0..<nbands {
            subSig.means[b1] = self.means[b1]
            for b2 in 0..<nbands {
                subSig.R[b1][b2] = self.R[b1][b2]
                subSig.Rinv[b1][b2] = self.Rinv[b1][b2]
            }
        }
    }
}

struct ClassSig {
    var classnum: Int
    var title: String
    var used: Bool
    var type: Int
    var nsubclasses: Int
    var subSig: [SubSig]
    var classData: ClassData
    
    init() {
        self.classnum = 0
        self.title = ""
        self.used = false
        self.type = 0
        self.nsubclasses = 0
        self.subSig = []
        self.classData = ClassData()
    }
    
    init(classnum: Int, title: String, used: Bool, type: Int, nsubclasses: Int, subSig: [SubSig], classData: ClassData) {
        self.classnum = classnum
        self.title = title
        self.used = used
        self.type = type
        self.nsubclasses = nsubclasses
        self.subSig = subSig
        self.classData = classData
    }
    
    mutating func initialise(S: inout SigSet) {
        
        self.nsubclasses = 0
        self.used = true
        self.type = SIGNATURE_TYPE_MIXED
        self.title = ""
        if S.nclasses == 0 {
            S.classSig = [self]
        }
        else {
            S.classSig.append(self)
        }
        self.classnum = S.nclasses
        S.nclasses += 1
    }

    /*********************/
    /* copy to sig2 */
    /*********************/
    func copy(sig: inout ClassSig, nbands: Int, copyClassData: Bool = false) -> Void {
        sig.classnum = self.classnum
        sig.title = self.title
        sig.used = self.used
        sig.type = self.type
        sig.nsubclasses = self.nsubclasses
        if sig.subSig.count < self.subSig.count {
            sig.subSig.append(contentsOf: Array(repeating: SubSig(), count: self.subSig.count - sig.subSig.count))
        }
        if sig.subSig.count > self.subSig.count {
            for _ in self.subSig.count..<sig.subSig.count {
                sig.subSig.remove(at: self.subSig.count)
            }
        }
        for i in 0..<self.nsubclasses {
            self.subSig[i].copy(subSig: &(sig.subSig[i]), nbands: nbands)
        }
        if copyClassData {
            self.classData.copy(classData: &(sig.classData))
        }
    }
    

    /**********************/
    /* saves Sig1 to Sig2 */
    /**********************/
    mutating func save(S: inout SigSet, nbands: Int) -> Void {
        
        S.nbands = nbands
        var sig = ClassSig()
        sig.initialise(S: &S)
        
        while sig.nsubclasses < self.nsubclasses {
            var subsig = SubSig()
            subsig.initialise(S: S)
            if sig.nsubclasses == 0 {
                sig.subSig = [subsig]
            }
            else {
                sig.subSig.append(subsig)
            }
            sig.nsubclasses += 1
        }
        self.copy(sig: &sig, nbands: nbands, copyClassData: true)
    }

    
    mutating func normalize_pi() -> Void {
        var sum: Double = 0.0
        for i in 0..<self.nsubclasses {
            sum += self.subSig[i].pi
        }
        if sum > 0 {
            for i in 0..<self.nsubclasses {
                self.subSig[i].pi /= sum
            }
        }
        else {
            for i in 0..<self.nsubclasses {
                self.subSig[i].pi = 0.0
            }
        }
    }
}

struct SigSet {
    var nbands: Int
    var nclasses: Int
    var title: String
    var classSig: [ClassSig]
    
    init() {
        self.nbands = 0
        self.nclasses = 0
        self.classSig = []
        self.title = ""
    }

    init(nbands: Int, nclasses: Int, title: String, classSig: [ClassSig]) {
        self.nbands = nbands
        self.nclasses = nclasses
        self.classSig = classSig
        self.title = title
    }
    
    func setNClasses() -> Int {
        var count: Int = 0
        for i in 0..<self.nclasses {
            if self.classSig[i].used {
                count += 1
            }
        }
        return count
    }
    
    func copy(sigSet: inout SigSet) {
        sigSet.nbands = self.nbands
        sigSet.nclasses = self.nclasses
        if sigSet.classSig.count < self.classSig.count {
            sigSet.classSig.append(contentsOf: Array(repeating: ClassSig(), count: self.classSig.count - sigSet.classSig.count))
        }
        if sigSet.classSig.count > self.classSig.count {
            for _ in self.classSig.count..<sigSet.classSig.count {
                sigSet.classSig.remove(at: self.classSig.count)
            }
        }
        for i in 0..<self.nclasses {
            self.classSig[i].copy(sig: &(sigSet.classSig[i]), nbands: self.nbands, copyClassData: true)
        }
        sigSet.title = self.title
    }

    func writeSigSet() -> String {
        
        var outputString: String = String(format: "title: %@\n", self.title)
        outputString += String(format: "nbands: %d\n", self.nbands)
        for i in 0..<self.nclasses {
            let Cp = self.classSig[i]
            if !Cp.used  {
                continue
            }
            outputString += "class:\n"
            outputString += String(format: " classnum: %ld\n", Cp.classnum)
            outputString += String(format: " classtitle: %@\n", Cp.title)
            outputString += String(format: " classtype: %d\n", Cp.type)
            for j in 0..<Cp.nsubclasses {
                let Sp = Cp.subSig[j]
                outputString += " subclass:\n"
                outputString += String(format: "  pi: %g\n", Sp.pi)
                outputString += "  means:"
                for b1 in 0..<self.nbands {
                    outputString += String(format: " %g", Sp.means[b1])
                }
                outputString += "\n"
                outputString += "  covar:\n"
                for b1 in 0..<self.nbands {
                    outputString += "      "
                    for b2 in 0..<self.nbands {
                        outputString += String(format: " %g", Sp.R[b1][b2])
                    }
                    outputString += "\n"
                }
                outputString += " endsubclass:\n"
            }
            outputString += "endclass:\n"
        }
        return outputString
    }
        
    mutating func readSigSet(_ fileLines: [String]) -> Void {
        
        var count = 0
        var items: [String]
        let spaceSet = CharacterSet(charactersIn: " ")
        while count < fileLines.count {
            items = fileLines[count].components(separatedBy: ":")
            GMMIOUtility.trimDownArray(&items)
            if items.count == 2 && items[0].contains("title") {
                self.title = items[1].trimmingCharacters(in: spaceSet)
            }
            else if items.count == 2 && items[0].contains("nbands") && items[1].trimmingCharacters(in: spaceSet).isContainsNumerics,
                let nbands = Int(items[1].trimmingCharacters(in: spaceSet)) {
                self.nbands = nbands
            }
            else if items.count == 1 && items[0].contains("class") {
                var C = ClassSig()
                count += 1
                while count < fileLines.count {
                    items = fileLines[count].components(separatedBy: ":")
                    GMMIOUtility.trimDownArray(&items)
                    if items.count == 1 && items[0] == "endclass" {
                        C.used = true
                        self.classSig.append(C)
                        self.nclasses += 1
                        break
                    }
                    else if items.count == 2 && items[0].contains("classnum") && items[1].trimmingCharacters(in: spaceSet).isContainsNumerics,
                        let classnum = Int(items[1].trimmingCharacters(in: spaceSet)) {
                        C.classnum = classnum
                    }
                    else if items.count == 2 && items[0].contains("classtype") && items[1].trimmingCharacters(in: spaceSet).isContainsNumerics,
                        let type = Int(items[1].trimmingCharacters(in: spaceSet)) {
                        C.type = type
                    }
                    else if items.count == 2 && items[0].contains("classtitle") {
                        C.title = items[1].trimmingCharacters(in: spaceSet)
                    }
                    else if items.count == 1 && items[0].contains("subclass") {
                        var Sp = SubSig()
                        Sp.initialise(S: self)
                        if C.nsubclasses == 0 {
                            C.subSig = [Sp]
                        }
                        else {
                            C.subSig.append(Sp)
                        }
                        C.nsubclasses += 1
                        count += 1
                        while count < fileLines.count {
                            items = fileLines[count].components(separatedBy: ":")
                            GMMIOUtility.trimDownArray(&items)
                            if items.count == 1 && items[0].contains("endsubclass") {
                                Sp.copy(subSig: &(C.subSig[C.nsubclasses - 1]), nbands: self.nbands)
                                break
                            }
                            else if items.count == 2 && items[0].contains("pi") && items[1].trimmingCharacters(in: spaceSet).isContainsNumerics, let pi = Double(items[1].trimmingCharacters(in: spaceSet)) {
                                Sp.pi = pi
                            }
                            else if items.count == 2 && items[0].contains("means") {
                                var subItems = items[1].components(separatedBy: " ")
                                GMMIOUtility.trimDownArray(&subItems)
                                for i in 0..<self.nbands {
                                    if subItems[i].isContainsNumerics,
                                        let mean = Double(subItems[i]) {
                                        Sp.means[i] = mean
                                    }
                                }
                            }
                            else if items.count == 1 && items[0].contains("covar") {
                                for i in 0..<self.nbands {
                                    count += 1
                                    items = fileLines[count].components(separatedBy: " ")
                                    GMMIOUtility.trimDownArray(&items)
                                    if items.count == self.nbands {
                                        for j in 0..<self.nbands {
                                            if items[j].isContainsNumerics,
                                                let r = Double(items[j]) {
                                                Sp.R[i][j] = r
                                            }
                                        }
                                    }
                                }
                            }
                            count += 1
                        }
                    }
                    count += 1
                }
            }
            count += 1
        }
    }
}

