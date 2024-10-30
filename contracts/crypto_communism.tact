import "@stdlib/deploy";

message(0xf8a7ea5) JettonTransfer {
  queryId: Int as uint64;
  amount: Int as coins;
  destination: Address;
  responseDestination: Address?;
  customPayload: Cell? = null;
  forwardTonAmount: Int as coins;
  forwardPayload: Slice as remaining;
}

const JettonTransferGas: Int = ton("0.05");

struct JettonWalletData {
  balance: Int as coins;
  ownerAddress: Address;
  jettonMasterAddress: Address;
  jettonWalletCode: Cell;
}

fun calculateJettonWalletAddress(
  ownerAddress: Address,
  jettonMasterAddress: Address,
  jettonWalletCode: Cell,
): Address {

  let initData = JettonWalletData{
    balance: 0,
    ownerAddress,
    jettonMasterAddress,
    jettonWalletCode,
  };

  return contractAddress(StateInit{
    code: jettonWalletCode,
    data: initData.toCell(),
  });
}

message SendJetton {
  amount: Int as coins;
  queryId: Int as uint64;
  destination: Address;
}

contract CryptoCommunism with Deployable {
  jettonWalletAddress: Address;
  jettonAmount: Int as coins = 0;
  admin: Address;

  init(jettonWalletCode: Cell, jettonMasterAddress: Address) {
    self.admin = sender();

    self.jettonWalletAddress = calculateJettonWalletAddress(
      myAddress(),
      jettonMasterAddress,
      jettonWalletCode,
    );
  }

  sendJetton(msg: SendJetton) {
    require(
      msg.amount <= self.jettonAmount,
      "Not enough funds to withdraw"
    );

    send(SendParameters{
      to: self.jettonWalletAddress,
      value: JettonTransferGas,
      body: JettonTransfer{
        queryId: msg.queryId,
        amount: msg.amount,
        destination: msg.destination,
        responseDestination: sender(),
        customPayload: null,
        forwardTonAmount: 0,
        //beginCell().storeUint(0xF, 4).endCell().beginParse()
        forwardPayload: rawSlice("F")
      }.toCell(),
    });
  }
}
