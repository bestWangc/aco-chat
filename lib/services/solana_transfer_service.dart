import 'dart:convert';

import 'package:aco_chat/services/bip39_service.dart';
import 'package:aco_chat/services/wallet_portfolio_models.dart';
import 'package:aco_chat/services/wallet_rpc_client.dart';
import 'package:on_chain/on_chain.dart';
import 'package:blockchain_utils/blockchain_utils.dart';

class SolanaTransferResult {
  const SolanaTransferResult({required this.hash});
  final String hash;
}

class SolanaTransferService {
  const SolanaTransferService();

  Future<SolanaTransferResult> transfer({
    required String mnemonic,
    required String from,
    required String to,
    required BigInt amount,
    String? mint,
    int decimals = 9,
    required String accessToken,
    required WalletRpcClient rpc,
  }) async {
    final endpoints = await rpc.loadEndpoints(
      network: WalletNetwork.solana.name,
      accessToken: accessToken,
    );
    Future<Map<String, dynamic>> call(String method, List<Object> params) =>
        rpc.postJson(endpoints, {
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          'params': params,
        });
    final payer = SolAddress(from);
    final recipient = SolAddress(to);
    final key = SolanaPrivateKey.fromSeed(
      Bip44.fromSeed(
        Bip39Service.mnemonicToSeed(mnemonic),
        Bip44Coins.solana,
      ).deriveDefaultPath.privateKey.raw,
    );
    final blockhash = await _blockhash(call);
    final instructions = <TransactionInstruction>[];
    if (mint == null || mint.isEmpty) {
      instructions.add(
        SystemProgram.transfer(
          from: payer,
          to: recipient,
          layout: SystemTransferLayout(lamports: amount),
        ),
      );
    } else {
      final mintAddress = SolAddress(mint);
      final source = await _tokenAccount(call, payer, mintAddress);
      if (source == null) throw const FormatException('发送方没有该 SPL 代币账户');
      final destination = await _tokenAccount(call, recipient, mintAddress);
      final destinationAddress =
          destination ?? _associatedToken(payer, recipient, mintAddress);
      if (destination == null) {
        instructions.add(
          AssociatedTokenAccountProgram.associatedTokenAccountIdempotent(
            payer: payer,
            associatedToken: destinationAddress,
            owner: recipient,
            mint: mintAddress,
          ),
        );
      }
      instructions.add(
        SPLTokenProgram.transferChecked(
          layout: SPLTokenTransferCheckedLayout(
            amount: amount,
            decimals: decimals,
          ),
          source: source,
          mint: mintAddress,
          destination: destinationAddress,
          owner: payer,
        ),
      );
    }
    final transaction = SolanaTransaction(
      payerKey: payer,
      instructions: instructions,
      recentBlockhash: SolAddress(blockhash),
    )..sign([key]);
    final encoded = base64Encode(transaction.serialize());
    final response = await call('sendTransaction', [
      encoded,
      {'encoding': 'base64', 'skipPreflight': false},
    ]);
    final hash = response['result'];
    if (hash is! String || hash.isEmpty) {
      throw FormatException('${response['error'] ?? 'Solana 广播失败'}');
    }
    return SolanaTransferResult(hash: hash);
  }

  Future<String> _blockhash(
    Future<Map<String, dynamic>> Function(String, List<Object>) call,
  ) async {
    final response = await call('getLatestBlockhash', [
      {'commitment': 'confirmed'},
    ]);
    final result = response['result'];
    final value = result is Map ? result['value'] : null;
    final blockhash = value is Map ? value['blockhash'] : null;
    if (blockhash is! String || blockhash.isEmpty) {
      throw const FormatException('Solana 未返回最新区块哈希');
    }
    return blockhash;
  }

  Future<SolAddress?> _tokenAccount(
    Future<Map<String, dynamic>> Function(String, List<Object>) call,
    SolAddress owner,
    SolAddress mint,
  ) async {
    final response = await call('getTokenAccountsByOwner', [
      owner.address,
      {'mint': mint.address},
      {'encoding': 'jsonParsed'},
    ]);
    final result = response['result'];
    final values = result is Map ? result['value'] : null;
    if (values is List && values.isNotEmpty && values.first is Map) {
      final pubkey = values.first['pubkey'];
      if (pubkey is String) return SolAddress(pubkey);
    }
    return null;
  }

  SolAddress _associatedToken(
    SolAddress payer,
    SolAddress owner,
    SolAddress mint,
  ) {
    final derived = SolanaUtils.findProgramAddress(
      seeds: [
        owner.toBytes(),
        SPLTokenProgramConst.tokenProgramId.toBytes(),
        mint.toBytes(),
      ],
      programId: AssociatedTokenAccountProgramConst.associatedTokenProgramId,
    );
    return derived.$1;
  }
}
