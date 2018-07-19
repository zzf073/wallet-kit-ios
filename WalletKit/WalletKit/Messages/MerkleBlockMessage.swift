//
//  MerkleBlockMessage.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/02/11.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

struct MerkleBlockMessage {
    let blockHeaderItem: BlockHeaderItem

    /// Number of transactions in the block (including unmatched ones)
    let totalTransactions: UInt32
    /// hashes in depth-first order (including standard varint size prefix)
    let numberOfHashes: VarInt
    let hashes: [Data]
    /// flag bits, packed per 8 in a byte, least significant bit first (including standard varint size prefix)
    let numberOfFlags: VarInt
    let flags: [UInt8]

    func serialized() -> Data {
        var data = Data()
        data += blockHeaderItem.serialized()
        data += totalTransactions
        data += numberOfHashes.serialized()
        data += hashes.flatMap { $0 }
        data += numberOfFlags.serialized()
        data += flags
        return data
    }

    static func deserialize(_ data: Data) -> MerkleBlockMessage {
        let byteStream = ByteStream(data)
        let blockHeaderItem = BlockHeaderItem.deserialize(byteStream: byteStream)
        let totalTransactions = byteStream.read(UInt32.self)
        let numberOfHashes = byteStream.read(VarInt.self)
        var hashes = [Data]()
        for _ in 0..<numberOfHashes.underlyingValue {
            hashes.append(byteStream.read(Data.self, count: 32))
        }
        let numberOfFlags = byteStream.read(VarInt.self)
        var flags = [UInt8]()
        for _ in 0..<numberOfFlags.underlyingValue {
            flags.append(byteStream.read(UInt8.self))
        }
        return MerkleBlockMessage(blockHeaderItem: blockHeaderItem, totalTransactions: totalTransactions, numberOfHashes: numberOfHashes, hashes: hashes, numberOfFlags: numberOfFlags, flags: flags)
    }

}