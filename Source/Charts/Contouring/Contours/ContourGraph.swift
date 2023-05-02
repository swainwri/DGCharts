//
//  ContourGraph.swift
//  Charts
//
//  Created by Steve Wainwright on 18/04/2023.
//

import Foundation

class ContourGraph: NSObject {
    
    typealias Queue = [Int]
    
    var noNodes: Int
    
    private var adjacency: [[Int]]?
    
    init(noNodes: Int) {
        self.noNodes = noNodes
        adjacency = []
        adjacency?.reserveCapacity(noNodes)
        for _ in 0..<noNodes {
            adjacency?.append([])
        }
    }
    
    func addEdge(from src: Int, to dest: Int) -> Void {
        // Add edge from src to dest
        adjacency?[src].append(dest)
        // Add edge from dest to src
        adjacency?[dest].append(src)
    }
    
    func formPath(from s_parent: [Int], to t_parent: [Int], source: Int, target: Int, intersectNode:Int) -> LineStrip {
        var path: LineStrip = []
        path.reserveCapacity(8)
        path.append(intersectNode)
        var i = intersectNode
        
        while i != source {
            path.append(s_parent[i])
            i = s_parent[i]
            if i == NSNotFound {
                break
            }
        }
        path = path.reversed()
        i = intersectNode
        while i != target {
            path.append(t_parent[i])
            i = t_parent[i]
            if i == NSNotFound {
                break
            }
            
        }
        print("*****Path*****\n")
        for i in 0..<path.count {
            print(" %ld", path[i])
        }
        print("\n")
        
        return path
    }
    
    // check for intersecting vertex
    private func isIntersecting(source_visited s_visited: [Bool], target_visited t_visited: [Bool]) -> Int {
        var intersectNode: Int = NSNotFound
        for i in 0..<self.noNodes {
            // if a vertex is visited by both front
            // and back BFS search return that node
            // else return -1
            if s_visited[i] && t_visited[i]  {
                intersectNode = i
                break
            }
        }
        return intersectNode
    }
    
    // Method for Breadth First Search BFS algorithm
    private func BFS(queue: inout Queue, visited: inout [Bool], parent: inout [Int]) -> Void {
        if let _adjacency = adjacency {
            let current = queue[0]
            let _ = queue.remove(at: 0)
            
            var node: Int
            for i in 0..<_adjacency[current].count {
                node = _adjacency[current][i]
                if !visited[node]  {
                    parent[node] = current
                    visited[node] = true
                    queue.append(node)
                }
            }
        }
    }

    func biDirSearch(fromSource source: Int, toTarget target: Int, paths: inout LineStripList) -> Int {
        
        // first make a copy of the whole adjacency matrix
        // then remove the nodes that are connected if exists between source and target
        let posFoundSource = adjacency?[source].firstIndex(where: { $0 == target } )
        let posFoundTarget = adjacency?[target].firstIndex(where: { $0 == source } )
        
        if let _posFoundSource = posFoundSource,
           let _posFoundTarget = posFoundTarget {
            adjacency?[source].remove(at: _posFoundSource)
            adjacency?[target].remove(at: _posFoundTarget)
        }
        
        // boolean array for BFS started from
        // source and target(front and backward BFS)
        // for keeping track on visited nodes
        var source_visited: [Bool] = Array(repeating: false, count: self.noNodes) // necessary initialization
        var target_visited: [Bool] = Array(repeating: false, count: self.noNodes)

        // Keep track on parents of nodes
        // for front and backward search
        var source_parent: [Int] = Array(repeating: NSNotFound, count: self.noNodes)
        var target_parent: [Int] = Array(repeating: NSNotFound, count: self.noNodes)
        // queue for front and backward search
        var source_queue: Queue = []
        source_queue.reserveCapacity(8)
        var target_queue: Queue = []
        target_queue.reserveCapacity(8)
        
        var intersectNode: Int = NSNotFound
        
        source_queue.append(source)
        source_visited[source] = true
        
        // parent of source is set to NSNotFound
        source_parent[source] = NSNotFound

        target_queue.append(target)
        target_visited[target] = true

        // parent of target is set to NSNotFound
        target_parent[target] = NSNotFound
        
        while source_queue.count != 0 && target_queue.count != 0 {
            // Do BFS from source and target vertices
            BFS(queue: &source_queue, visited: &source_visited, parent: &source_parent)
            BFS(queue: &target_queue, visited: &target_visited, parent: &target_parent)
            
            // check for intersecting vertex
            intersectNode = isIntersecting(source_visited: source_visited, target_visited: target_visited)

            // If intersecting vertex is found
            // that means there exist a path
            if intersectNode != NSNotFound {
                print("Path exist between %ld and %ld, Intersection at: %ld\n", source, target, intersectNode)
                // print the path and exit the program
                let path: LineStrip = formPath(from: source_parent, to: target_parent, source: source, target: target, intersectNode: intersectNode)
                
                if path.count > 2 {  // check it's at least a triangle
                    if paths.count == 0 {
                        paths.append(path)
                    }
                    else {
                        var canAdd: [Bool] = Array(repeating: false, count: paths.count)
                        for i in stride(from: paths.count - 1, to: -1, by: -1) {
                            canAdd[i] = paths[i].checkLineStripToAnotherForSameDifferentOrder(path)
                        }
                        var ableToAdd = true
                        for i in stride(from: paths.count - 1, to: -1, by: -1) {
                            ableToAdd = ableToAdd && canAdd[i]
                        }
                        if ableToAdd {
                            paths.append(path)
                        }
                    }
                }
                break
            }
        }
        
        
        // if the source and target Edge were taken out of the adjacency matrix replace it
        if let _ = posFoundSource,
           let _ = posFoundTarget {
            addEdge(from: source, to: target)
        }
        
        return intersectNode
    }
    
}

