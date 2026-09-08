//
//  QueueBuddyTests.swift
//  QueueBuddyTests
//
//  Created by Robby Dzielinski on 7/13/25.
//

import Foundation
import Testing
@testable import QueueBuddy___Park_Waits

struct QueueBuddyTests {

    @Test func attractionWaitDisplayHandlesClosedWalkOnAndUnknown() {
        let closed = Attraction(
            id: 1,
            name: "Closed Ride",
            wait_time: 10,
            status: "CLOSED",
            is_open: false
        )
        #expect(closed.waitTimeDisplay == "Closed")
        #expect(closed.comparableWaitTime == Int.max)

        let walkOn = Attraction(
            id: 2,
            name: "Walk On",
            wait_time: 0,
            status: "OPERATING",
            is_open: true
        )
        #expect(walkOn.waitTimeDisplay == "Walk-on")
        #expect(walkOn.comparableWaitTime == 0)

        let unknown = Attraction(
            id: 3,
            name: "Unknown",
            wait_time: nil,
            status: "OPERATING",
            is_open: true
        )
        #expect(unknown.waitTimeDisplay == "N/A")
        #expect(unknown.comparableWaitTime == Int.max - 1)
    }

    @Test func routeDecisionDecodesExpectedSnakeCasePayload() throws {
        let json = """
        {
          "reroute_triggered": true,
          "next_destination": {
            "attraction_id": "123",
            "attraction_name": "Space Mountain",
            "action_type": "Ride",
            "expected_wait_minutes": 15
          },
          "lock_screen_message": "Space Mountain is your best next move."
        }
        """

        let decision = try JSONDecoder().decode(RouteDecision.self, from: Data(json.utf8))
        #expect(decision.rerouteTriggered)
        #expect(decision.nextDestination.attractionName == "Space Mountain")
        #expect(decision.nextDestination.actionType == .ride)
        #expect(decision.id == "123|Space Mountain is your best next move.")
    }
}
