import UIKit
import WalletKit
import RealmSwift
import RxSwift

class TransactionsController: UITableViewController {
    let disposeBag = DisposeBag()

    var transactions = [TransactionInfo]()
    var lastBlockHeight = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Transactions"

        tableView.register(UINib(nibName: String(describing: TransactionCell.self), bundle: Bundle(for: TransactionCell.self)), forCellReuseIdentifier: String(describing: TransactionCell.self))

        update()
        lastBlockHeight = Manager.shared.walletKit.lastBlockHeight

        Manager.shared.transactionsSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] in
            self?.update()
        }).disposed(by: disposeBag)

        Manager.shared.lastBlockHeightSubject.observeOn(MainScheduler.instance).subscribe(onNext: { [weak self] height in
            self?.lastBlockHeight = height
            self?.update()
        }).disposed(by: disposeBag)
    }

    private func update() {
        transactions = Manager.shared.walletKit.transactions
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transactions.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: String(describing: TransactionCell.self), for: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? TransactionCell {
            cell.bind(transaction: transactions[indexPath.row], lastBlockHeight: lastBlockHeight)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < transactions.count else {
            return
        }
        print("hash: \(transactions[indexPath.row].transactionHash)")
    }

}
