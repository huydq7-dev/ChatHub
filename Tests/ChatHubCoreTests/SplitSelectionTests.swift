import Foundation
import Testing

@testable import ChatHubCore

@Suite("Split view selection and link browser")
struct SplitSelectionTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()

    @Test func selectingReplacesTheMainAccountAndKeepsTheSecond() {
        let selection = SplitSelection(primary: a, secondary: b).selecting(c)
        #expect(selection == SplitSelection(primary: c, secondary: b))
    }

    @Test func selectingTheSecondAccountSwapsPanes() {
        #expect(SplitSelection(primary: a, secondary: b).selecting(b) == SplitSelection(primary: b, secondary: a))
    }

    @Test func overviewClosesTheSplit() {
        #expect(SplitSelection(primary: a, secondary: b).selecting(nil) == SplitSelection())
    }

    @Test func sideBySideNeedsADifferentMainAccount() {
        #expect(SplitSelection(primary: a).openingSideBySide(b) == SplitSelection(primary: a, secondary: b))
        #expect(SplitSelection(primary: a).openingSideBySide(a) == SplitSelection(primary: a))
        #expect(SplitSelection().openingSideBySide(b) == SplitSelection(primary: b))
        #expect(
            SplitSelection(primary: a, secondary: b).openingSideBySide(c) == SplitSelection(primary: a, secondary: c))
    }

    @Test func swappingAndClosing() {
        let split = SplitSelection(primary: a, secondary: b)
        #expect(split.swapped() == SplitSelection(primary: b, secondary: a))
        #expect(SplitSelection(primary: a).swapped() == SplitSelection(primary: a))
        #expect(split.closingSecondary() == SplitSelection(primary: a))
    }

    @Test func removingAnAccountKeepsAValidLayout() {
        let split = SplitSelection(primary: a, secondary: b)
        #expect(split.removing(a) == SplitSelection(primary: b))
        #expect(split.removing(b) == SplitSelection(primary: a))
        #expect(split.removing(c) == split)
    }

    @Test func visibleIDsListBothPanes() {
        #expect(SplitSelection(primary: a, secondary: b).visibleIDs == [a, b])
        #expect(SplitSelection().visibleIDs.isEmpty)
    }

    @Test func linkBrowserSurvivesEncodingAndOldWorkspacesHaveNone() throws {
        let account = ChatAccount(service: .telegram, name: "Work", linkBrowserID: "com.google.Chrome")
        let decoded = try JSONDecoder().decode(ChatAccount.self, from: JSONEncoder().encode(account))
        #expect(decoded.linkBrowserID == "com.google.Chrome")
        let legacy = Data(
            #"{"id":"4B1F1D2C-0000-4000-8000-000000000004","service":"zalo","name":"Old","subtitle":"","createdAt":0}"#
                .utf8)
        #expect(try JSONDecoder().decode(ChatAccount.self, from: legacy).linkBrowserID == nil)
    }

    @Test func anEmptyOrOversizedBrowserIdentifierIsDropped() throws {
        let empty = try ChatAccount(service: .zalo, name: "A", linkBrowserID: "").validated()
        let long = try ChatAccount(service: .zalo, name: "A", linkBrowserID: String(repeating: "x", count: 201))
            .validated()
        #expect(empty.linkBrowserID == nil)
        #expect(long.linkBrowserID == nil)
    }
}
