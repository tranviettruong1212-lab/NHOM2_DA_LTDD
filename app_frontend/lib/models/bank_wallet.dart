enum WalletType { bank, eWallet }

class BankWallet {
  final String id;
  final String name;
  final WalletType type;
  final double demoBalance;
  final bool isDemoConnected;

  const BankWallet({
    required this.id,
    required this.name,
    required this.type,
    required this.demoBalance,
    this.isDemoConnected = true,
  });
}
