import XCTest
import Cuckoo
import RealmSwift
import RxSwift
@testable import WalletKit

class ValidatedBlockFactoryTests: XCTestCase {

    private var mockFactory: MockFactory!
    private var mockNetwork: MockNetworkProtocol!
    private var factory: ValidatedBlockFactory!

    private var realm: Realm!
    private var checkpointBlock: Block!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockFactory = mockWalletKit.mockFactory
        mockNetwork = mockWalletKit.mockNetwork

        realm = mockWalletKit.realm
        checkpointBlock = TestData.checkpointBlock

        stub(mockNetwork) { mock in
            when(mock.checkpointBlock.get).thenReturn(checkpointBlock)
            when(mock.validate(block: any(), previousBlock: any())).thenDoNothing()
        }


        factory = ValidatedBlockFactory(realmFactory: mockWalletKit.mockRealmFactory, factory: mockFactory, network: mockNetwork)
    }

    override func tearDown() {
        mockFactory = nil
        mockNetwork = nil
        factory = nil

        realm = nil
        checkpointBlock = nil

        super.tearDown()
    }

    func testBlock_WithPreviousBlock() {
        let testBlock = TestData.firstBlock

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: testBlock.header!), previousBlock: equal(to: testBlock.previousBlock!))).thenReturn(testBlock)
        }

        let block = try! factory.block(fromHeader: testBlock.header!, previousBlock: testBlock.previousBlock)

        XCTAssertEqual(block, testBlock)
    }

    func testBlock_WithoutPreviousBlock_NoBlocksInRealm() {
        let testBlock = TestData.firstBlock

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: testBlock.header!), previousBlock: equal(to: checkpointBlock))).thenReturn(testBlock)
        }

        let block = try! factory.block(fromHeader: testBlock.header!)

        XCTAssertEqual(block, testBlock)
    }

    func testBlock_WithoutPreviousBlock_WithBlocksInRealm() {
        let testBlock = TestData.secondBlock
        let firstBlock = TestData.firstBlock

        try! realm.write {
            realm.add(firstBlock)
        }

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: testBlock.header!), previousBlock: equal(to: firstBlock))).thenReturn(testBlock)
        }

        let block = try! factory.block(fromHeader: testBlock.header!)

        XCTAssertEqual(block, testBlock)
    }

    func testBlock_InvalidHeader() {
        let testBlock = TestData.firstBlock

        stub(mockFactory) { mock in
            when(mock.block(withHeader: equal(to: testBlock.header!), previousBlock: equal(to: testBlock.previousBlock!))).thenReturn(testBlock)
        }
        stub(mockNetwork) { mock in
            when(mock.validate(block: equal(to: testBlock), previousBlock: any())).thenThrow(BlockValidatorError.notEqualBits)
        }

        var caught = false

        do {
            _ = try factory.block(fromHeader: testBlock.header!, previousBlock: testBlock.previousBlock)
        } catch let error as BlockValidatorError {
            caught = true
            XCTAssertEqual(error, BlockValidatorError.notEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }

        XCTAssertTrue(caught, "notEqualBits exception not thrown")
    }

}
