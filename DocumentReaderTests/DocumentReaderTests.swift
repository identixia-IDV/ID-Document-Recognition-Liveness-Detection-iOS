import XCTest
@testable import DocumentReader

final class DocumentReaderTests: XCTestCase {
    let golden = """
    {"identity":{"class":"Passport","country":"UTO","score":0.91},"readings":[{"name":"familyName","value":"DOE","origin":"visual","score":0.97},{"name":"firstNames","value":"JOHN","origin":"visual","score":0.96},{"name":"docNumber","value":"123456789","origin":"zone","score":0.99}],"tests":[{"name":"expiry","group":"validity","outcome":"pass"},{"name":"focus","group":"capture","outcome":"pass","score":0.9},{"name":"foilCheck","group":"authenticity","page":0,"outcome":"pass","score":0.88}],"images":[{"name":"face","page":0,"data":"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="}],"session":{"jobId":"identixia_0123456789abcdef0123456789abcdef","code":0,"detail":"ready"}}
    """

    func testResultParserEmpty() {
        XCTAssertTrue(ResultParser.rows("").isEmpty)
    }

    func testCustomerJsonContract() {
        let data = golden.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let keys = Set(obj.keys)
        XCTAssertTrue(keys.isSubset(of: ["identity", "readings", "tests", "images", "session"]))
        XCTAssertNil(obj["documentName"])
        XCTAssertNil(obj["ocr"])
        XCTAssertNil(obj["security"])
        XCTAssertNil(obj["api"])
        let readings = obj["readings"] as! [[String: Any]]
        XCTAssertEqual(readings[0]["name"] as? String, "familyName")
        XCTAssertEqual(readings[0]["value"] as? String, "DOE")
        XCTAssertEqual(readings[0]["origin"] as? String, "visual")
    }

    func testResultRowsFromCustomerJson() {
        let parsed = ResultParser.rows(golden)
        XCTAssertEqual(parsed.first { $0.key == "class" }?.value, "Passport")
        XCTAssertEqual(parsed.first { $0.key == "familyName" }?.source, "visual")
        XCTAssertTrue(parsed.first { $0.key == "familyName" }?.value.contains("DOE") == true)
        XCTAssertEqual(parsed.first { $0.key == "docNumber" }?.source, "zone")
        XCTAssertEqual(parsed.first { $0.key == "expiry" }?.source, "validity")
        XCTAssertEqual(parsed.first { $0.key == "focus" }?.source, "capture")
        XCTAssertNil(parsed.first { $0.key == "foilCheck" })
        XCTAssertTrue(ResultParser.summary(golden).contains("Passport"))
    }

    func testSecurityFromCustomerJson() {
        XCTAssertTrue(ResultParser.securitySummary(golden).contains("Passport"))
        let rows = ResultParser.securityRows(golden)
        XCTAssertEqual(rows.first?.page, "Front")
        XCTAssertEqual(rows.first?.check, "foilCheck")
        XCTAssertTrue(rows.first?.status.contains("pass") == true)
    }

    func testImagesFromCustomerJson() {
        let imgs = ResultParser.images(golden)
        XCTAssertEqual(imgs.count, 1)
        XCTAssertTrue(imgs[0].category.contains("face"))
    }

    func testOverallResultsGoldenAllPass() {
        let rows = ResultParser.overallResults(golden)
        XCTAssertEqual(rows.map { "\($0.kind):\($0.result)" }, [
            "validity:pass", "capture:pass", "authenticity:pass",
        ])
    }

    func testOverallResultsFailWins() {
        var obj = try! JSONSerialization.jsonObject(with: golden.data(using: .utf8)!) as! [String: Any]
        var tests = obj["tests"] as! [[String: Any]]
        tests.append(["name": "expiry2", "group": "validity", "outcome": "fail"])
        tests.append(["name": "glare", "group": "capture", "outcome": "hold"])
        obj["tests"] = tests
        let data = try! JSONSerialization.data(withJSONObject: obj)
        let raw = String(data: data, encoding: .utf8)!
        let rows = ResultParser.overallResults(raw)
        XCTAssertEqual(rows.map { "\($0.kind):\($0.result)" }, [
            "validity:fail", "capture:pass", "authenticity:pass",
        ])
    }

    func testFieldGroupsOrdersVisualThenZone() {
        let groups = ResultParser.fieldGroups(golden)
        XCTAssertEqual(groups.map { $0.source }, ["visual", "zone"])
        XCTAssertEqual(groups[0].items.map { $0.id }, ["familyName", "firstNames"])
        XCTAssertEqual(groups[1].items.first?.id, "docNumber")
        XCTAssertEqual(groups[0].items.first?.value, "DOE")
        XCTAssertFalse(groups[0].items.first?.score.isEmpty ?? true)
    }

    func testCheckGroupsOrdersKindsAndFailsFirst() {
        var obj = try! JSONSerialization.jsonObject(with: golden.data(using: .utf8)!) as! [String: Any]
        var tests = obj["tests"] as! [[String: Any]]
        tests.append(["name": "expiry2", "group": "validity", "outcome": "fail", "note": "expired"])
        tests.append(["name": "glare", "group": "capture", "outcome": "hold"])
        obj["tests"] = tests
        let data = try! JSONSerialization.data(withJSONObject: obj)
        let raw = String(data: data, encoding: .utf8)!
        let groups = ResultParser.checkGroups(raw)
        XCTAssertEqual(groups.map { $0.kind }, ["validity", "capture", "authenticity"])
        XCTAssertEqual(groups[0].items.map { $0.id }, ["expiry2", "expiry"])
        XCTAssertEqual(groups[0].items.first?.result, "fail")
        XCTAssertEqual(groups[0].items.first?.extra, "expired")
        XCTAssertEqual(groups[1].items.map { $0.id }, ["focus", "glare"])
    }
}
