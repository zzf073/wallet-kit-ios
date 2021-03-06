import XCTest
import Cuckoo
import BigInt
@testable import WalletKit

class LegacyDifficultyAdjustmentValidatorTests: XCTestCase {

    private var validator: LegacyDifficultyAdjustmentValidator!
    private var mockNetwork: MockNetworkProtocol!
    private var mockEncoder: MockDifficultyEncoder!
    private var mockBlockHelper: MockBlockHelper!

    private var checkPointBlock: Block!
    private var block: Block!
    private var candidate: Block!

    override func setUp() {
        super.setUp()
        let mockWalletKit = MockWalletKit()
        mockNetwork = mockWalletKit.mockNetwork
        stub(mockNetwork) { mock in
            when(mock.heightInterval.get).thenReturn(2016)
            when(mock.targetTimeSpan.get).thenReturn(1_209_600)
            when(mock.maxTargetBits.get).thenReturn(0x1d00ffff)
        }
        mockEncoder = mockWalletKit.mockDifficultyEncoder
        stub(mockEncoder) { mock in
            when(mock.decodeCompact(bits: 476399191)).thenReturn(BigInt("10665477591887247494381404907447500979192021944764506987270680608768"))
            when(mock.decodeCompact(bits: 474199013)).thenReturn(BigInt("7129927859545590787920041835044506526699926406309469412482969763840"))
            when(mock.encodeCompact(from: equal(to: BigInt("7129928201274994723790235748908587989251132236328748923672922318604")!))).thenReturn(474199013)
        }
        mockBlockHelper = mockWalletKit.mockBlockHelper

        validator = LegacyDifficultyAdjustmentValidator(encoder: mockWalletKit.mockDifficultyEncoder, blockHelper: mockWalletKit.mockBlockHelper)

        checkPointBlock = TestData.checkpointBlock
        checkPointBlock.height = 40320
        checkPointBlock.header?.bits = 476399191
        checkPointBlock.header?.timestamp = 1266169979

        block = TestData.firstBlock
        block.height = 40320 + 2015
        block.header?.bits = 476399191
        block.header?.timestamp = 1266978603

        candidate = TestData.secondBlock
        candidate.height = 40320 + 2016
        candidate.header?.bits = 474199013
        candidate.header?.timestamp = 1266979264

        stub(mockBlockHelper) { mock in
            when(mock.previous(for: any(), index: any())).thenReturn(checkPointBlock)
        }
    }

    override func tearDown() {
        validator = nil
        mockNetwork = nil

        checkPointBlock = nil
        block = nil
        candidate = nil

        super.tearDown()
    }

    func testValidate() {
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
        } catch let error {
            XCTFail("\(error) Exception Thrown")
        }
    }

    func testNoCandidateHeader() {
        candidate.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNoBlockHeader() {
        block.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testCheckPointNoBlockHeader() {
        checkPointBlock.header = nil
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as Block.BlockError {
            XCTAssertEqual(error, Block.BlockError.noHeader)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNoPreviousBlock() {
        stub(mockBlockHelper) { mock in
            when(mock.previous(for: any(), index: any())).thenReturn(nil)
        }
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.noPreviousBlock)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

    func testNotDifficultyTransitionEqualBits() {
        stub(mockEncoder) { mock in
            when(mock.encodeCompact(from: equal(to: BigInt("7129928201274994723790235748908587989251132236328748923672922318604")!))).thenReturn(0)
        }
        do {
            try validator.validate(candidate: candidate, block: block, network: mockNetwork)
            XCTFail("noHeader exception not thrown")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.notDifficultyTransitionEqualBits)
        } catch {
            XCTFail("Unknown exception thrown")
        }
    }

}
