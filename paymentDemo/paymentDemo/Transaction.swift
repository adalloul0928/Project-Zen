let transactionTemplate = """
[
    $transaction: {transaction}
    $date: "{date}"
    $time: "{time}"
    $merchant: "{merchant}"
    $amount: "{amount}"
](
    $type: /bali/examples/Transaction/v1
    $tag: {tag}
    $version: {version}
    $permissions: /bali/permissions/public/v1
    $previous: none
)
"""

class Transaction : Content {
    let transaction = formatter.generateTag()
    let date = formatter.currentDate()
    let time = formatter.currentTime()
    let merchant: String
    let amount: String
    let tag = formatter.generateTag()
    let version = "v1"

    init(merchant: String, amount: String) {
        self.merchant = merchant
        self.amount = amount
    }

    func format(level: Int) -> String {
        var transaction = transactionTemplate.replacingOccurrences(of: "{transaction}", with: self.transaction)
        transaction = transaction.replacingOccurrences(of: "{date}", with: date)
        transaction = transaction.replacingOccurrences(of: "{time}", with: time)
        transaction = transaction.replacingOccurrences(of: "{merchant}", with: merchant)
        transaction = transaction.replacingOccurrences(of: "{amount}", with: amount)
        transaction = transaction.replacingOccurrences(of: "{tag}", with: tag)
        transaction = transaction.replacingOccurrences(of: "{version}", with: version)
        return formatter.indentLines(string: transaction, level: level)
    }

}

