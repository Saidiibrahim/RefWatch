//
//  ScheduleMetadataPersisting.swift
//  RefZoneiOS
//
//  Internal helper so repositories can trigger publisher updates when they
//  mutate SwiftData records directly during Supabase merges.
//

import Foundation

@MainActor
protocol ScheduleMetadataPersisting {
    func publishSnapshot()
}
