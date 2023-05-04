//
//  GMMSubCluster.swift
//  DiscontinuityMeshGenerator
//
//  Ported by Steve Wainwright on 16/09/2022.
//  Copyright © 2022 sakrist. All rights reserved.
//

import Foundation

class GMMSubCluster: NSObject {
    
    var S: SigSet?
    private var sig3: ClassSig?
    private var subSig3: SubSig?

    //  SigSet *S,          /* Input: structure containing input data */
    //  int class_Index,    /* Input: index corresponding to class to be processed */
    //  int desired_num,    /* Input: desired number of subclusters. */
    //                      /*      0=>ignore this input. */
    //  short option,       /* Input: type of clustering to use */
    //                      /*      option=1=CLUSTER_FULL=>full covariance matrix */
    //                      /*      option=0=CLUSTER_DIAG=>diagonal covariance matrix */
    //  double Rmin,        /* Minimum value for diagonal elements of convariance */
    //  int *Max_num        /* Output: maximum number of allowed subclusters */
    func subcluster(S: SigSet, class_Index: Int, desired_num: Int, option: GMMClusterModel, Rmin: Double, Max_num: inout Int) -> Int {

        self.S = S
        var status: Int = 0

        /* set class pointer */
        var sig = S.classSig[class_Index]

        /* set number of bands */
        let nbands = S.nbands

        /* compute number of parameters per cluster */
        var nparams_clust: Int = 1 + nbands + (nbands + 1) * nbands / 2
        if option == .diagonal {
            nparams_clust = 1 + nbands + nbands
        }
        /* compute number of data points */
        let ndata_points: Int = sig.classData.npixels * nbands

        /* compute maximum number of subclasses */
        Max_num = (ndata_points + 1) / (nparams_clust - 1)

        /* check for too many subclasses */
        if sig.nsubclasses > Max_num / 2 {
            sig.nsubclasses = Max_num / 2
            print("Too many subclasses for class index \(class_Index)\n")
            print("         number of subclasses set to \(sig.nsubclasses)\n\n")
    //        status = -2;
    //        return status;
        }

        /* initialize clustering */
        seed(sig: &sig, nbands: nbands, Rmin: Rmin, option: option)

        /* EM algorithm */
        var min_riss = refine_clusters(sig: &sig, nbands: nbands, Rmin: Rmin, option: option)

        if 2 <= clusterMessageVerboseLevel {
            print("Subclasses = \(sig.nsubclasses); Rissanen = \(min_riss); \n")
        }

        var Smin: SigSet = SigSet()
        /* Save contents of Class Signature to Smin */
        S.copy(sigSet: &Smin)
        sig.copy(sig: &(Smin.classSig[0]), nbands: nbands)
//        sig.save(S: &Smin, nbands: nbands)
        
        var rissanen: Double
        var min_i: Int = 0, min_j: Int = 0
        if desired_num == 0 {
            while sig.nsubclasses > 1 {
                reduce_order(sig: &sig, nbands: nbands, min_ii: &min_i, min_jj: &min_j)

                if 2 <= clusterMessageVerboseLevel {
                    print("Combining Subclasses (\(min_i),\(min_j))\n")
                }

                rissanen = refine_clusters(sig: &sig, nbands: nbands, Rmin: Rmin, option: option)

                if 2 <= clusterMessageVerboseLevel {
                    print("Subclasses = \(sig.nsubclasses); Rissanen = \(rissanen); \n")
                }

                if rissanen < min_riss {
                    min_riss = rissanen

                    /* Delete old Smin, and save new Smin */
                    sig.copy(sig: &(Smin.classSig[0]), nbands: nbands)
//                    sig.save(S: &Smin, nbands: nbands)
                }
            }
        }
        else {
            while sig.nsubclasses > desired_num && sig.nsubclasses > 0 {
                reduce_order(sig: &sig, nbands: nbands, min_ii: &min_i, min_jj: &min_j)
                
                if 2 <= clusterMessageVerboseLevel {
                    print("Combining Subclasses (\(min_i),\(min_j))\n", min_i, min_j)
                }
     
                rissanen = refine_clusters(sig: &sig, nbands: nbands, Rmin: Rmin, option: option)
                
                if 2 <= clusterMessageVerboseLevel {
                    print("Subclasses = \(sig.nsubclasses); Rissanen = \(rissanen); \n")
                }
                sig.copy(sig: &(Smin.classSig[0]), nbands: nbands)
//                sig.save(S: &Smin, nbands: nbands)
            }
        }

        /* Deallocate memory for class, and replace with solution */
        sig.title = "test class signature"
        Smin.classSig[0].copy(sig: &sig, nbands: nbands)
        
        if var _S = self.S {
            sig.used = true
            sig.copy(sig: &(_S.classSig[class_Index]), nbands: nbands)
            self.S = _S
        }
        else {
            status = 0
        }

        /* return warning status */
        return status
    }


    /******************************************************************/
    /* Computes initial values for parameters of Gaussian Mixture     */
    /* model. The subroutine returns the minimum allowed value for    */
    /* the diagonal entries of the convariance matrix of each class.  */
    /*****************************************************************/
    private func seed(sig: inout ClassSig, nbands: Int, Rmin: Double, option: GMMClusterModel) -> Void {
         
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
            for b2 in 0..<nbands {
                R[b1][b2] = 0.0
                for i in 0..<sig.classData.npixels {
                    R[b1][b2] += sig.classData.x[i][b1] * sig.classData.x[i][b2] * sig.classData.w[i]
                }
                R[b1][b2] /= sig.classData.SummedWeights
                R[b1][b2] -= mean[b1] * mean[b2]
            }
         }

         /* If diagonal clustering is desired, then diagonalize matrix */
        if option == .diagonal {
            diagonalizeMatrix(R: &R, nbands: nbands)
        }
         /* Compute the sampling period for seeding */
        var period: Double
        if sig.nsubclasses > 1 {
            period = Double(sig.classData.npixels - 1) / Double(sig.nsubclasses - 1)
        }
        else {
            period = 0
        }

        /* Seed the means and set the covarience components */
        for i in 0..<sig.nsubclasses {
            for b1 in 0..<nbands {
                sig.subSig[i].means[b1] = sig.classData.x[Int(Double(i) * period)][b1]
            }

            for b1 in 0..<nbands {
                for b2 in 0..<nbands {
                    sig.subSig[i].R[b1][b2] = R[b1][b2]
                }
            }
            for b1 in 0..<nbands {
                sig.subSig[i].R[b1][b1] += Rmin
            }
            sig.subSig[i].pi = 1.0 / Double(sig.nsubclasses)
        }

        compute_constants(sig: &sig, nbands: nbands)
        sig.normalize_pi()
    }


    /*****************************************************************/
    /* Computes ML clustering of data using Gaussian Mixture model.  */
    /* Returns the values of the Rissen constant for the clustering. */
    /*****************************************************************/
    private func refine_clusters(sig: inout ClassSig, nbands: Int, Rmin: Double, option: GMMClusterModel) -> Double {
        var nparams_clust: Int = 1 + nbands + (nbands + 1) * nbands / 2
        if option == .diagonal {
            nparams_clust = 1 + nbands + nbands
        }
         /* compute number of data points */
        let ndata_points = sig.classData.npixels * nbands

         /* compute epsilon */
        let epsilon = Double(nparams_clust) * log(Double(ndata_points)) * 0.01

         /* Perform initial regrouping */
        var ll_new: Double = regroup(sig: &sig, nbands: nbands)
        var ll_old: Double
         /* Perform EM algorithm */
        var change: Double // = 2 * epsilon;
        repeat {
            ll_old = ll_new
            reestimate(sig: &sig, nbands: nbands, Rmin: Rmin, option: option)
            ll_new = regroup(sig: &sig, nbands: nbands)
            change = ll_new - ll_old
        } while change > epsilon

         /* compute Rissanens expression */
        if sig.nsubclasses > 0 {
            let num_params = sig.nsubclasses * nparams_clust - 1
            let rissanen_const = -ll_new + 0.5 * Double(num_params) * log(Double(ndata_points))
            return rissanen_const
        }
        else {
            return 0.0
        }
    }


    private func reestimate(sig: inout ClassSig, nbands: Int, Rmin: Double, option: GMMClusterModel) -> Void {
        /* Compute N */
        for i in 0..<sig.nsubclasses {
            sig.subSig[i].N = 0
            for s in 0..<sig.classData.npixels {
                sig.subSig[i].N += (sig.classData.p[s][i] * sig.classData.w[s])
             }
            sig.subSig[i].pi = sig.subSig[i].N
         }

         /* Compute means and variances for each subcluster */
        for i in 0..<sig.nsubclasses {
             /* Compute mean */
            for b1 in 0..<nbands {
                sig.subSig[i].means[b1] = 0
                for s in 0..<sig.classData.npixels {
                    sig.subSig[i].means[b1] += sig.classData.p[s][i] * sig.classData.x[s][b1] * sig.classData.w[s]
                 }
                sig.subSig[i].means[b1] /= sig.subSig[i].N
             }
        
           /* Compute R */
            var diff1: Double, diff2: Double
            for b1 in 0..<nbands {
                for b2 in b1..<nbands {
                    sig.subSig[i].R[b1][b2] = 0
                    for s in 0..<sig.classData.npixels {
                        diff1 = sig.classData.x[s][b1] - sig.subSig[i].means[b1]
                        diff2 = sig.classData.x[s][b2] - sig.subSig[i].means[b2]
                        sig.subSig[i].R[b1][b2] += sig.classData.p[s][i] * diff1 * diff2 * sig.classData.w[s]
                    }
                    sig.subSig[i].R[b1][b2] /= sig.subSig[i].N
                    sig.subSig[i].R[b2][b1] = sig.subSig[i].R[b1][b2]
                }
            }
             /* Regularize matrix */
            for b1 in 0..<nbands {
                sig.subSig[i].R[b1][b1] += Rmin
            }

            if option == .diagonal {
                diagonalizeMatrix(R: &(sig.subSig[i].R), nbands: nbands)
            }
        }

         /* Normalize probabilities for subclusters */
        sig.normalize_pi()

        /* Compute constants */
        compute_constants(sig: &sig, nbands: nbands)
        sig.normalize_pi()
    }


    private func regroup(sig: inout ClassSig, nbands: Int) -> Double {
        
        /* compute likelihoods */
        var likelihood: Double = 0, tmp: Double, maxlike: Double = 0, subsum: Double
        
        for s in 0..<sig.classData.npixels {
            sig.classData.p[s][0] = loglike(x: sig.classData.x[s], subSig: sig.subSig[0], nbands: nbands)
            maxlike = sig.classData.p[s][0]
            for i in 1..<sig.nsubclasses {
                tmp = loglike(x: sig.classData.x[s], subSig: sig.subSig[i], nbands: nbands)
                sig.classData.p[s][i] = tmp
//                if i == 0 {
//                    maxlike = tmp
//                }
                if tmp > maxlike {
                    maxlike = tmp
                }
            }

            subsum = 0
            for i in 0..<sig.nsubclasses {
                tmp = exp(sig.classData.p[s][i] - maxlike) * sig.subSig[i].pi
                subsum += tmp
                sig.classData.p[s][i] = tmp
            }
            likelihood += log(subsum) + maxlike

            for i in 0..<sig.nsubclasses {
                sig.classData.p[s][i] /= subsum
            }
        }

        return likelihood
    }

    private func reduce_order(sig: inout ClassSig, nbands: Int, min_ii: inout Int, min_jj: inout Int) -> Void {

        var min_i = Int.max, min_j = Int.max
        var min_dist = Double.greatestFiniteMagnitude
        
        /* allocate scratch space first time subroutine is called */
        if self.S == nil {
            self.S = SigSet()
        }
        if var _S = S,
           self.sig3 == nil {
            _S.nbands = nbands
            self.sig3 = ClassSig()
            self.sig3?.initialise(S: &_S)
            if var _sig3 = sig3,
               self.subSig3 == nil {
                var subSig3 = SubSig()
                subSig3.initialise(S: _S)
                _sig3.subSig = [subSig3]
                _sig3.nsubclasses = 1
                self.subSig3 = _sig3.subSig[0]
                self.sig3 = _sig3
            }
        }

        if sig.nsubclasses > 1,
           var _subSig3 = self.subSig3 {
            var dist: Double
            /* find the closest subclasses */
            for i in 0..<sig.nsubclasses-1  {
                for j in i+1..<sig.nsubclasses {
                    dist = distance(subSig1: sig.subSig[i], subSig2: sig.subSig[j], nbands: nbands)
                    if (i == 0 && j == 1) || dist < min_dist {
                        min_dist = dist
                        min_i = i
                        min_j = j
                    }
                }
            }
            /* Save result for output */
            min_ii = min_i
            min_jj = min_j

            /* Combine Subclasses */
            add_SubSigs(subSig1: sig.subSig[min_i], subSig2: sig.subSig[min_j], subSig3: &_subSig3, nbands: nbands)
            _subSig3.copy(subSig: &(sig.subSig[min_i]), nbands: nbands)
            
            /* remove extra subclass */
            sig.subSig.remove(at: min_j)
//
//            for i in min_j..<sig.nsubclasses-1 {
//                sig.subSig[i].copy(subSig: &(sig.subSig[i + 1]), nbands: nbands)
//            }
            sig.nsubclasses -= 1
            
            /* Rerun compute_constants */
            compute_constants(sig: &sig, nbands: nbands)
            sig.normalize_pi()
        }
    }


    private func loglike(x: [Double], subSig: SubSig, nbands: Int) -> Double {
        var diff1: Double, diff2: Double
        var sum: Double = 0
        for b1 in 0..<nbands {
            for b2 in 0..<nbands{
                diff1 = x[b1] - subSig.means[b1]
                diff2 = x[b2] - subSig.means[b2]
                sum += (diff1 * diff2 * subSig.Rinv[b1][b2])
            }
        }
        sum = -0.5 * sum + subSig.cnst
        return sum
    }


    private func distance(subSig1: SubSig, subSig2: SubSig, nbands: Int) -> Double {
        /* allocate scratch space first time subroutine is called */
        if self.S == nil {
            self.S = SigSet()
        }
        if var _S = self.S,
           self.sig3 == nil {
            _S.nbands = nbands
            self.sig3 = ClassSig()
            self.sig3?.initialise(S: &_S)
            if var _sig3 = self.sig3,
               self.subSig3 == nil {
                _sig3.subSig = []
                var subSig3 = SubSig()
                subSig3.initialise(S: _S)
                _sig3.subSig = [subSig3]
                _sig3.nsubclasses = 1
                self.subSig3 = _sig3.subSig[0]
                self.sig3 = _sig3
            }
        }
        var dist: Double = 0
        if var _sig3 = self.sig3,
           var _subSig3 = self.subSig3 {
            /* form subSig3 by adding subSig1 and subSig2 */
            add_SubSigs(subSig1: subSig1, subSig2: subSig2, subSig3: &_subSig3, nbands: nbands)
            _subSig3.copy(subSig: &(_sig3.subSig[0]), nbands: nbands)
            
            /* compute constant for subSig3 */
            compute_constants(sig: &_sig3, nbands: nbands)
            _sig3.subSig[0].copy(subSig: &_subSig3, nbands: nbands)
            /* compute distance */
            dist = subSig1.N * subSig1.cnst + subSig2.N * subSig2.cnst - _subSig3.N * _subSig3.cnst
        }
        return dist
    }


    /**********************************************************/
    /* invert matrix and compute Sig->subSig[i].cnst          */
    /**********************************************************/
//    private var first_compute_constants = true
//    private var indx: [Int]?
//    private var y: [[Double]]?
//    private var col: [Double]?
    
    private func compute_constants(sig: inout ClassSig, nbands: Int) -> Void {
        var det_man: Double = 0, det_exp: Int = 0
        /* invert matrix and compute constant for each subclass */
        for i in 0..<sig.nsubclasses {
            for b1 in 0..<nbands {
                for b2 in 0..<nbands {
                    sig.subSig[i].Rinv[b1][b2] = sig.subSig[i].R[b1][b2]
                }
            }
            let _ = GMMInvert.invert(a: &sig.subSig[i].Rinv, n: nbands, det_man: &det_man, det_exp: &det_exp)
            sig.subSig[i].cnst = (-Double(nbands) / 2.0) * log(2 * .pi)
            sig.subSig[i].cnst -= 0.5 * log(det_man)
            sig.subSig[i].cnst -= 0.5 * Double(det_exp) * log(10.0)
        }
    }


    /*******************************************/
    /* add subSig1 and subSig2 to form subSig3 */
    /*******************************************/
    private func add_SubSigs(subSig1: SubSig, subSig2: SubSig, subSig3: inout SubSig, nbands: Int) -> Void {
        
        let wt1: Double = subSig1.N / (subSig1.N + subSig2.N)
        let wt2: Double = 1 - wt1

        /* compute means */
        for b1 in 0..<nbands {
            subSig3.means[b1] = wt1 * subSig1.means[b1] + wt2 * subSig2.means[b1]
        }
        /* compute covariance */
        var tmp: Double
        for b1 in 0..<nbands {
            for b2 in b1..<nbands {
                tmp = (subSig3.means[b1] - subSig1.means[b1]) * (subSig3.means[b2] - subSig1.means[b2])
                subSig3.R[b1][b2] = wt1 * (subSig1.R[b1][b2] + tmp)
                tmp = (subSig3.means[b1] - subSig2.means[b1]) * (subSig3.means[b2] - subSig2.means[b2])
                subSig3.R[b1][b2] += wt2 * (subSig2.R[b1][b2] + tmp)
                subSig3.R[b2][b1] = subSig3.R[b1][b2]
            }
        }
        /* compute pi and N */
        subSig3.pi = subSig1.pi + subSig2.pi
        subSig3.N = subSig1.N + subSig2.N
    }

    private func diagonalizeMatrix(R: inout [[Double]], nbands: Int) -> Void {
        for b1 in 0..<nbands {
            for b2 in 0..<nbands {
                if  b1 != b2  {
                    R[b1][b2] = 0
                }
            }
        }
    }

    //#if 0
    private func list_Sig(sig: ClassSig, nbands: Int) -> Void{
        
        for i in 0..<sig.nsubclasses  {
            print("Subclass \(i): pi = \(sig.subSig[i].pi), ")
            print("cnst = \(sig.subSig[i].cnst)\n")
            for j in 0..<nbands {
                print("\(sig.subSig[i].means[j]);    ")
                for k in 0..<nbands {
                    print("\(sig.subSig[i].R[j][k]) ")
                }
                print("\n")
            }
            print("\n")
        }
    }

    private func print_class(sig: ClassSig, fileNamePath: String)  -> (Bool, String) {
        var OK: Bool = false
        var errorMessage: String
        if let filenameURL = URL(string: fileNamePath) {
            var outputString: String = ""
            for s in 0..<sig.classData.npixels {
                outputString += String(format: "Pixel number \(s):  ")
                for i in 0..<sig.nsubclasses {
                    outputString += String(format: "\(sig.classData.p[s][i])  ")
                }
                outputString += "\n"
            }
            do {
                // Write to the file
                try outputString.write(to: filenameURL, atomically: true, encoding: String.Encoding.utf8)
                errorMessage = NSLocalizedString("\(fileNamePath)\n has been successfully exported to apps Documents/Export folder.", comment: "")
                OK = true
            }
            catch let error as NSError {
                print("Failed writing to URL: \(String(describing: filenameURL)), Error: " + error.localizedDescription)
                errorMessage = NSLocalizedString("\(fileNamePath)\n could not be exported to apps Documents/Export folder.", comment: "")
            }
        }
        else {
            errorMessage = NSLocalizedString("\(fileNamePath)\n could not be exported to apps Documents/Export folder.", comment: "")
        }
        return (OK, errorMessage)
    }
    //#endif
}
