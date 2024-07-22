import 'dart:math';

import 'package:convert/convert.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_flutter_v2/apis/core/pairing/utils/pairing_models.dart';
import 'package:walletconnect_flutter_v2/apis/sign_api/models/json_rpc_models.dart';
import 'package:walletconnect_flutter_v2/apis/sign_api/models/proposal_models.dart';
import 'package:walletconnect_flutter_v2/apis/sign_api/models/session_models.dart';
import 'package:walletconnect_flutter_v2/apis/sign_api/models/sign_client_models.dart';
import 'package:walletconnect_flutter_v2/apis/sign_api/sign_client.dart';
import 'package:walletconnect_flutter_v2/apis/utils/namespace_utils.dart';
import 'package:walletconnect_flutter_v2/apis/web3app/web3app.dart';
import 'package:web3dart/web3dart.dart';

import 'EthereumTransaction.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static Web3App? _walletConnect;
  var myData = BigInt.zero;
  late Client client;
  late Web3Client web3client;
  late DeployedContract contract;
  String? name;
  String? symbol;
  String contractAddress = "0xB4F284Df7D40f40327db4A27C855BB1f909891c2";
  final rpc_url = "https://goerli.infura.io/v3/4009a1b4ddf34fc6ad587c4b10dabe52";

  Future<void> _initWalletConnect() async {
    _walletConnect = await Web3App.createInstance(
      projectId: 'b8ff9c52a3433ab288836f7402d5d323',
      metadata: const PairingMetadata(
        name: 'Flutter WalletConnect',
        description: 'Flutter WalletConnect Dapp Example',
        url: 'https://walletconnect.com/',
        icons: [
          'https://walletconnect.com/walletconnect-logo.png',
        ],
      ),
    );
  }

  static const String launchError = 'Metamask wallet not installed';
  static const String kShortChainId = 'eip155';
  static const String kFullChainId = 'eip155:5';

  static String? _url;
  static SessionData? _sessionData;

  String? account;

  String get deepLinkUrl => 'metamask://wc?uri=$_url';

  Future<String?> createSession() async {
    // final bool isInstalled = await metamaskIsInstalled();
    //
    // if (!isInstalled) {
    //   return Future.error(launchError);
    // }

    if (_walletConnect == null) {
      await _initWalletConnect();
    }

    final ConnectResponse connectResponse = await _walletConnect!.connect(
      requiredNamespaces: {
        kShortChainId: const RequiredNamespace(
          chains: [kFullChainId],
          methods: [
            'eth_sign',
            'eth_signTransaction',
            'eth_sendTransaction',
          ],
          events: [
            'chainChanged',
            'accountsChanged',
          ],
        ),
      },
    );

    final Uri? uri = connectResponse.uri;

    if (uri != null) {
      final String encodedUrl = Uri.encodeComponent('$uri');

      _url = encodedUrl;

      await launchUrlString(
        deepLinkUrl,
        mode: LaunchMode.externalApplication,
      );

      _sessionData = await connectResponse.session.future;
      contract = await loadContract();

      final String _account = NamespaceUtils.getAccount(
        _sessionData!.namespaces.values.first.accounts.first,
      );
      setState(() {
        account = _account;
      });
      return _account;
    }

    return null;
  }

  Future<bool> metamaskIsInstalled() async {
    return await LaunchApp.isAppInstalled(
      iosUrlScheme: 'metamask://',
      androidPackageName: 'io.metamask',
    );
  }

  Future<dynamic> submit(String name, List<dynamic> args, BuildContext context) async {
    var data = contract.function(name).encodeCall(args);
    // var p = await web3client.estimateGas(
    //           to: EthereumAddress.fromHex(contractAddress),
    //           sender: EthereumAddress.fromHex(account!),
    //           data: data,
    //         );

    Transaction transaction = Transaction.callContract(
      from: EthereumAddress.fromHex(account!),
      contract: contract,
      function: contract.function(name),
      parameters: args,
    );

    EthereumTransaction ethereumTransaction = EthereumTransaction(
      from: account!,
      to: contractAddress,
      value: "0x0",
      data: hex.encode(List<int>.from(transaction.data!)),
      /// ENCODE TRANSACTION USING convert LIB
    );
    await launchUrlString(
      deepLinkUrl,
      mode: LaunchMode.externalApplication,
    );

    final signResponse = await _walletConnect!.request(
      topic: _sessionData!.topic,
      chainId: "eip155:5",
      request: SessionRequestParams(method: 'eth_sendTransaction', params: [ethereumTransaction.toJson()]),
    );
    return signResponse;
  }

  Future<DeployedContract> loadContract() async {
    String abi = await rootBundle.loadString("assets/abi.json");
    final contract = DeployedContract(ContractAbi.fromJson(abi, "AsadToken"), EthereumAddress.fromHex(contractAddress));
    return contract;
  }

  Future<List<dynamic>> query(String name, List<dynamic> args) async {
    final contract = await loadContract();
    final ethFunction = contract.function(name);
    final result = await web3client.call(contract: contract, function: ethFunction, params: args);
    return result;
  }

  Future getTokenName() async {
    var response = await query("name", []);
    name = response[0];
    setState(() {});
  }

  Future getTokenSymbol() async {
    var response = await query("symbol", []);
    symbol = response[0];
    setState(() {});
  }

  Future getBalanceToken(String targetAddress) async {
    EthereumAddress toAddress = EthereumAddress.fromHex(targetAddress);
    var response = await query("balanceOf", [toAddress]);
    myData = response[0];
    setState(() {});
  }

  Future mintToken(BuildContext context) async {
    BigInt bigAmount = BigInt.from(100e18);
    EthereumAddress toAddress = EthereumAddress.fromHex(account!);
    var response = await submit("mint", [toAddress, bigAmount], context);
    return response;
  }

  Future transferToken(BuildContext context) async {
    BigInt bigAmount = BigInt.from(10e18);
    EthereumAddress toAddress = EthereumAddress.fromHex("0x95d214e60C1881FAcfca90D8909F0DdEE63F004f");
    var response = await submit("transfer", [toAddress, bigAmount], context);
    return response;
  }
  void loadDialog(BuildContext context, TransactionReceipt value, var hash) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Receipt"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("Status"), Text("${value.status}")],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("Comluative Gas Price"), Text("${value.cumulativeGasUsed}")],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("BlockNumber"), Text("${value.blockNumber}")],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [const Text("Gas Used"), Text("${value.gasUsed}")],
              ),
              Divider(),
              const Text("Hash"),
              Divider(),
              Flexible(
                  child: Text(
                "$hash",
                style: TextStyle(fontSize: 10),
              ))
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Ok"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    client = Client();
    web3client = Web3Client(rpc_url, client);
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionData != null) {
      getBalanceToken(account ?? "");
      getTokenName();
      getTokenSymbol();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("ERC20 Integration"),
        centerTitle: true,
      ),
      drawer: Drawer(
          child: ListView(
        children: [
          (account != null)
              ? UserAccountsDrawerHeader(
                  accountName: const Text("Asad"),
                  accountEmail: Text(account!),
                  currentAccountPicture: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text("A"),
                  ),
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  onPressed: () {
                    createSession().then((value) => (value) async {
                          print("value");
                        });
                  },
                  child: const Text("Connect with Metamask")),
        ],
      )),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50),
            margin: const EdgeInsets.all(10),
            child: Text(
              name ?? "",
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 50),
            margin: const EdgeInsets.all(10),
            child: Text(
              "${EtherAmount.inWei(myData).getInEther} ${symbol ?? "Coin"}",
              style: const TextStyle(fontSize: 40),
            ),
          ),
          Center(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                onPressed: () => mintToken(context),
                child: const Text("Mint Token")),
          ),
          Center(
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => transferToken(context),
                child: const Text("Transfer Token")),
          ),
        ],
      ),
    );
  }
}

