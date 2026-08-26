import '../models/account.dart';
import '../models/transaction.dart';
import '../models/asset.dart';
import '../models/liability.dart';
import '../models/net_worth_snapshot.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';
import '../repositories/asset_repository.dart';
import '../repositories/liability_repository.dart';
import '../repositories/net_worth_snapshot_repository.dart';

/// Business logic for the MONEY SYSTEM: accounts, transactions, assets,
/// liabilities, net worth, and the numbers derived from them.
///
/// Screens call this, never the repositories directly:
///   MoneyScreen -> MoneyService -> *Repository -> SQLite
class MoneyService {
  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;
  final AssetRepository _assetRepo;
  final LiabilityRepository _liabilityRepo;
  final NetWorthSnapshotRepository _netWorthRepo;

  MoneyService({
    AccountRepository? accountRepo,
    TransactionRepository? transactionRepo,
    AssetRepository? assetRepo,
    LiabilityRepository? liabilityRepo,
    NetWorthSnapshotRepository? netWorthRepo,
  })  : _accountRepo = accountRepo ?? AccountRepository(),
        _transactionRepo = transactionRepo ?? TransactionRepository(),
        _assetRepo = assetRepo ?? AssetRepository(),
        _liabilityRepo = liabilityRepo ?? LiabilityRepository(),
        _netWorthRepo = netWorthRepo ?? NetWorthSnapshotRepository();

  // --- Accounts --------------------------------------------------------------

  Future<List<Account>> getAccounts() => _accountRepo.getAll();

  Future<int> createAccount(Account account) => _accountRepo.create(account);

  Future<void> updateAccount(Account account) => _accountRepo.update(account);

  Future<void> deleteAccount(int id) => _accountRepo.delete(id);

  Future<double> getTotalBalance() async {
    final accounts = await _accountRepo.getAll();
    return accounts.fold<double>(0, (sum, a) => sum + a.balance);
  }

  // --- Transactions ------------------------------------------------------------

  Future<List<Transaction>> getRecentTransactions({int limit = 10}) async {
    final all = await _transactionRepo.getAll();
    return all.take(limit).toList();
  }

  Future<void> recordTransaction(Transaction transaction) async {
    await _transactionRepo.create(transaction);

    final account = await _accountRepo.getById(transaction.accountId);
    if (account == null) return;

    await _accountRepo.update(
      account.copyWith(balance: account.balance + _signedAmount(transaction)),
    );
  }

  Future<void> editTransaction({
    required Transaction oldTransaction,
    required Transaction newTransaction,
  }) async {
    if (oldTransaction.accountId == newTransaction.accountId) {
      final account = await _accountRepo.getById(newTransaction.accountId);
      if (account != null) {
        final balanceWithoutOld = account.balance - _signedAmount(oldTransaction);
        final balanceWithNew = balanceWithoutOld + _signedAmount(newTransaction);
        await _accountRepo.update(account.copyWith(balance: balanceWithNew));
      }
    } else {
      final oldAccount = await _accountRepo.getById(oldTransaction.accountId);
      if (oldAccount != null) {
        await _accountRepo.update(
          oldAccount.copyWith(balance: oldAccount.balance - _signedAmount(oldTransaction)),
        );
      }

      final newAccount = await _accountRepo.getById(newTransaction.accountId);
      if (newAccount != null) {
        await _accountRepo.update(
          newAccount.copyWith(balance: newAccount.balance + _signedAmount(newTransaction)),
        );
      }
    }

    await _transactionRepo.update(newTransaction);
  }

  Future<void> deleteTransaction(Transaction transaction) async {
    final account = await _accountRepo.getById(transaction.accountId);
    if (account != null) {
      await _accountRepo.update(
        account.copyWith(balance: account.balance - _signedAmount(transaction)),
      );
    }
    if (transaction.id != null) {
      await _transactionRepo.delete(transaction.id!);
    }
  }

  double _signedAmount(Transaction t) =>
      t.type == TransactionType.income ? t.amount : -t.amount;

  double calculateNet(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }
    return income - expenses;
  }

  // --- Monthly filtering -----------------------------------------------------

  Future<List<Transaction>> getTransactionsForMonth(int year, int month) async {
    final all = await _transactionRepo.getAll();
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    return all.where((t) => t.date.startsWith(prefix)).toList();
  }

  Future<Map<String, double>> getMonthlySummary(int year, int month) async {
    final transactions = await getTransactionsForMonth(year, month);

    double income = 0;
    double expenses = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }

    return {'income': income, 'expenses': expenses, 'saved': income - expenses};
  }

  // --- Assets ------------------------------------------------------------------

  Future<List<Asset>> getAssets() => _assetRepo.getAll();

  Future<int> createAsset(Asset asset) => _assetRepo.create(asset);

  Future<void> updateAsset(Asset asset) => _assetRepo.update(asset);

  Future<void> deleteAsset(int id) => _assetRepo.delete(id);

  Future<double> getTotalAssets() async {
    final assets = await _assetRepo.getAll();
    return assets.fold<double>(0, (sum, a) => sum + a.value);
  }

  // --- Liabilities ----------------------------------------------------------

  Future<List<Liability>> getLiabilities() => _liabilityRepo.getAll();

  Future<int> createLiability(Liability liability) => _liabilityRepo.create(liability);

  Future<void> updateLiability(Liability liability) => _liabilityRepo.update(liability);

  Future<void> deleteLiability(int id) => _liabilityRepo.delete(id);

  Future<double> getTotalLiabilities() async {
    final liabilities = await _liabilityRepo.getAll();
    return liabilities.fold<double>(0, (sum, l) => sum + l.amount);
  }

  // --- Net Worth -----------------------------------------------------------------

  Future<double> getNetWorth() async {
    final assets = await getTotalAssets();
    final liabilities = await getTotalLiabilities();
    return assets - liabilities;
  }

  Future<void> recordNetWorthSnapshot(String date) async {
    final totalAssets = await getTotalAssets();
    final totalLiabilities = await getTotalLiabilities();

    await _netWorthRepo.upsertForDate(NetWorthSnapshot(
      date: date,
      totalAssets: totalAssets,
      totalLiabilities: totalLiabilities,
      netWorth: totalAssets - totalLiabilities,
    ));
  }

  Future<List<NetWorthSnapshot>> getNetWorthHistory() => _netWorthRepo.getAll();

  /// The last recorded net worth snapshot within a given month, or null
  /// if none was recorded that month. Used for Dashboard §6's
  /// "Previous month: ₱29,000 → Current month: ₱35,500" comparison.
  Future<double?> getNetWorthAtEndOfMonth(int year, int month) async {
    final all = await _netWorthRepo.getAll(); // ascending by date
    final prefix = '$year-${month.toString().padLeft(2, '0')}';
    final inMonth = all.where((s) => s.date.startsWith(prefix)).toList();
    if (inMonth.isEmpty) return null;
    return inMonth.last.netWorth;
  }
}