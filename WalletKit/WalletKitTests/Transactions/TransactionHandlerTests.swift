import XCTest
import Cuckoo
import RealmSwift
@testable import WalletKit

class TransactionHandlerTests: XCTestCase {

    private var mockProcessor: MockTransactionProcessor!
    private var mockValidatedBlockFactory: MockValidatedBlockFactory!
    private var mockProgressSyncer: MockProgressSyncer!
    private var transactionHandler: TransactionHandler!

    private var realm: Realm!

    override func setUp() {
        super.setUp()

        let mockWalletKit = MockWalletKit()

        mockProcessor = mockWalletKit.mockTransactionProcessor
        mockValidatedBlockFactory = mockWalletKit.mockValidatedBlockFactory
        mockProgressSyncer = mockWalletKit.mockProgressSyncer
        realm = mockWalletKit.realm

        stub(mockProcessor) { mock in
            when(mock.enqueueRun()).thenDoNothing()
        }
        stub(mockProgressSyncer) { mock in
            when(mock.enqueueRun()).thenDoNothing()
        }

        transactionHandler = TransactionHandler(realmFactory: mockWalletKit.mockRealmFactory, processor: mockProcessor, progressSyncer: mockProgressSyncer, validateBlockFactory: mockValidatedBlockFactory)
    }

    override func tearDown() {
        mockProcessor = nil
        mockValidatedBlockFactory = nil
        mockProgressSyncer = nil
        transactionHandler = nil
        realm = nil

        super.tearDown()
    }

    func testHandleBlockTransactions() {
        let transaction = TestData.p2pkhTransaction
        let checkpointBlock = TestData.checkpointBlock
        let block = TestData.firstBlock
        block.previousBlock = checkpointBlock

        try! realm.write {
            realm.add(block, update: true)
        }

        try! transactionHandler.handle(blockTransactions: [transaction], blockHeader: block.header!)

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", block.reversedHeaderHashHex).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmBlock.headerHash, block.headerHash)
        XCTAssertEqual(realmBlock.status, .synced)
        XCTAssertEqual(realmTransaction.block?.reversedHeaderHashHex, block.reversedHeaderHashHex)

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandleBlockTransactions_EmptyTransactions() {
        let block = TestData.checkpointBlock

        try! realm.write {
            realm.add(block, update: true)
        }

        try! transactionHandler.handle(blockTransactions: [], blockHeader: block.header!)

        verify(mockProcessor, never()).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandleBlockTransactions_ExistingTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new
        let block = TestData.firstBlock

        try! realm.write {
            realm.add(transaction, update: true)
        }
        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: any(), previousBlock: any())).thenReturn(block)
        }

        try! transactionHandler.handle(blockTransactions: [transaction], blockHeader: block.header!)

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", block.reversedHeaderHashHex).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        XCTAssertEqual(realmBlock.reversedHeaderHashHex, block.reversedHeaderHashHex)
        XCTAssertEqual(realmTransaction.block?.reversedHeaderHashHex, block.reversedHeaderHashHex)
        XCTAssertEqual(realmTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(realmTransaction.status, TransactionStatus.relayed)

        verify(mockProcessor, never()).enqueueRun()
    }

    func testHandleBlockTransactions_ExistingBlockAndTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new
        let block = TestData.firstBlock

        try! realm.write {
            realm.add(block, update: true)
            realm.add(transaction, update: true)
        }

        try! transactionHandler.handle(blockTransactions: [transaction], blockHeader: block.header!)

        let realmTransaction = realm.objects(Transaction.self).last!

        XCTAssertEqual(realmTransaction.block?.reversedHeaderHashHex, block.reversedHeaderHashHex)
        XCTAssertEqual(realmTransaction.reversedHashHex, transaction.reversedHashHex)
        XCTAssertEqual(realmTransaction.status, TransactionStatus.relayed)

        verify(mockProcessor, never()).enqueueRun()
    }

    func testHandleBlockTransactions_NewBlockHeader() {
        let transaction = TestData.p2pkhTransaction
        let block = TestData.firstBlock

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: any(), previousBlock: any())).thenReturn(block)
        }

        try! transactionHandler.handle(blockTransactions: [transaction], blockHeader: block.header!)

        let realmBlock = realm.objects(Block.self).filter("reversedHeaderHashHex = %@", block.headerHash.reversedHex).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmBlock.headerHash, block.headerHash)
        XCTAssertEqual(realmBlock.status, .synced)
        XCTAssertEqual(realmTransaction.block, realmBlock)

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandleBlockTransactions_ExistingBlockHeader() {
        let transaction = TestData.p2pkhTransaction
        let block = TestData.checkpointBlock
        let savedBlock = Factory().block(withHeaderHash: block.headerHash, height: 0)

        try! realm.write {
            realm.add(savedBlock, update: true)
        }

        try! transactionHandler.handle(blockTransactions: [transaction], blockHeader: block.header!)

        let realmBlock = realm.objects(Block.self).last!
        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmBlock.headerHash, block.headerHash)
        XCTAssertEqual(Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: realmBlock.header!)), Crypto.sha256sha256(BlockHeaderSerializer.serialize(header: block.header!)))
        XCTAssertEqual(realmBlock.status, .synced)
        XCTAssertEqual(realmTransaction.block, realmBlock)

        verify(mockProcessor).enqueueRun()
        verify(mockProgressSyncer).enqueueRun()
    }

    func testHandleBlockTransactions_InvalidBlockHeader() {
        let transaction = TestData.p2pkhTransaction
        let block = TestData.firstBlock

        stub(mockValidatedBlockFactory) { mock in
            when(mock.block(fromHeader: any(), previousBlock: any())).thenThrow(BlockValidatorError.noCheckpointBlock)
        }

        do {
            try transactionHandler.handle(blockTransactions: [transaction], blockHeader: block.header!)
            XCTFail("Expected exception not thrown!")
        } catch let error as BlockValidatorError {
            XCTAssertEqual(error, BlockValidatorError.noCheckpointBlock)
        } catch {
            XCTFail("Unexpected exception!")
        }

        verify(mockProcessor, never()).enqueueRun()
        verify(mockProgressSyncer, never()).enqueueRun()
    }

    func testHandleMemPoolTransactions() {
        let transaction = TestData.p2pkhTransaction

        try! transactionHandler.handle(memPoolTransactions: [transaction])

        let realmTransaction = realm.objects(Transaction.self).last!
        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmTransaction.block, nil)

        verify(mockProcessor).enqueueRun()
    }

    func testHandleMemPoolTransactions_EmptyTransactions() {
        try! transactionHandler.handle(memPoolTransactions: [])
        verify(mockProcessor, never()).enqueueRun()
    }

    func testHandleMemPoolTransactions_ExistingTransaction() {
        let transaction = TestData.p2pkhTransaction
        transaction.status = .new

        try! realm.write {
            realm.add(transaction, update: true)
        }

        try! transactionHandler.handle(memPoolTransactions: [transaction])

        let realmTransaction = realm.objects(Transaction.self).last!

        assertTransactionEqual(tx1: transaction, tx2: realmTransaction)
        XCTAssertEqual(realmTransaction.status, TransactionStatus.relayed)

        verify(mockProcessor, never()).enqueueRun()
    }

    private func assertTransactionEqual(tx1: Transaction, tx2: Transaction) {
        XCTAssertEqual(tx1, tx2)
        XCTAssertEqual(tx1.reversedHashHex, tx2.reversedHashHex)
        XCTAssertEqual(tx1.version, tx2.version)
        XCTAssertEqual(tx1.lockTime, tx2.lockTime)
        XCTAssertEqual(tx1.inputs.count, tx2.inputs.count)
        XCTAssertEqual(tx1.outputs.count, tx2.outputs.count)

        for i in 0..<tx1.inputs.count {
            XCTAssertEqual(tx1.inputs[i].previousOutputTxReversedHex, tx2.inputs[i].previousOutputTxReversedHex)
            XCTAssertEqual(tx1.inputs[i].previousOutputIndex, tx2.inputs[i].previousOutputIndex)
            XCTAssertEqual(tx1.inputs[i].signatureScript, tx2.inputs[i].signatureScript)
            XCTAssertEqual(tx1.inputs[i].sequence, tx2.inputs[i].sequence)
        }

        for i in 0..<tx2.outputs.count {
            assertOutputEqual(out1: tx1.outputs[i], out2: tx2.outputs[i])
        }
    }

    private func assertOutputEqual(out1: TransactionOutput, out2: TransactionOutput) {
        XCTAssertEqual(out1.value, out2.value)
        XCTAssertEqual(out1.lockingScript, out2.lockingScript)
        XCTAssertEqual(out1.index, out2.index)
    }

}
