import Foundation

@discardableResult
func parseMMSS(_ s: String) -> Int {
    let comps = s.split(separator: ":")
    guard comps.count == 2,
          let mm = Int(comps[0]),
          let ss = Int(comps[1]) else { return 0 }
    return mm * 60 + ss
}

