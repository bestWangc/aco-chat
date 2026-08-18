import 'package:blockchain_utils/blockchain_utils.dart';

/// BIP-39 operations shared by wallet generation, validation, and derivation.
/// Keeping this wrapper makes the wallet independent of a package-specific API.
class Bip39Service {
  static final _generator = Bip39MnemonicGenerator();
  static final _validator = Bip39MnemonicValidator();

  static String generateMnemonic({required int words}) {
    final wordCount = Bip39WordsNum.fromValue(words);
    if (wordCount == null) {
      throw ArgumentError.value(
        words,
        'words',
        'must be a supported BIP-39 length',
      );
    }
    return _generator.fromWordsNumber(wordCount).toStr();
  }

  static bool validateMnemonic(String mnemonic) =>
      _validator.validateWords(mnemonic);

  static List<int> mnemonicToSeed(String mnemonic) =>
      Bip39SeedGenerator(Bip39Mnemonic.fromString(mnemonic)).generate();
}
