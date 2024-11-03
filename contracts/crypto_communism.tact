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

message Withdraw {
  amount: Int as coins;
  queryId: Int as uint64;
  destination: Address;
}

/*
 * buildings:
 * 0 - factory
 * 1 - farm
 * 2 - jail
 */
struct Buildings {
  factories: Int as uint64 = 0;
  farms: Int as uint64 = 0;
  jails: Int as uint64 = 0;
}

fun buildMore(b: Buildings, buildingType: Int, value: Int) {
  if (buildingType == 0) {
    b.factories = b.factories + value;
  }
  else if (buildingType == 1) {
    b.farms = b.farms + value;
  }
  else if (buildingType == 2) {
    b.jails = b.jails + value;
  }
}

fun getByNumber(b: Buildings, n: Int): Int {
  if (n == 0) {
    return b.factories;
  }
  else if (n == 1) {
    return b.farms;
  }
  else if (n == 2) {
    return b.jails;
  }

  throw(42);
}

/*
 * Player statuses:
 * 0 - playing
 * 1 - sent to GULAG
 * 2 - dekulakized
 * 3 - special, resigned
 */

struct Player {
  address: Address;
  status: Int as uint8 = -1;
  normVote: Int as int8 = -1;
  dekulakVote: Int as int8 = -1;
  buildings: Buildings;
  balance: Int as uint64 = 0;
  chosen: Bool = false;
}

fun playerToString(p: Player): String {
  let bs = beginString();
  bs.append(p.address.toString());
  bs.append(":");
  bs.append(p.status.toString());

  return bs.toString();
}
/*
 * actions:
 * 0 - build something
 * 1 - vote to dekulakize
 * 2 - vote for new norm
 */

struct Move {
  playerId: Int as uint8;
  action: Int as uint8;
  arg1: Int? as uint8;
  arg2: Int? as uint64;
}

fun evalMove(players: map<Int as int8, Player>, move: Move) {
  let playerId: Int = move.playerId;
  let player: Player = players.get(playerId)!!;

  if (player.status != 0) {
    return
  }

  let action: Int = move.action;

  if (action == 0) {
    let buildingType: Int = move.arg1!!;
    let value: Int = move.arg2!!;
    if (value <= player.balance) {
      player.balance = player.balance - value;
      buildMore(player.buildings, buildingType, value);
    }
  }
  else if (action == 1) {
    let target: Int = move.arg1!!;
    if (player.dekulakVote == -1) {
      player.dekulakVote = target;
    }
  }
  else if (action == 2) {
    let target: Int = move.arg1!!;
    if (player.normVote == -1) {
      player.normVote = target;
    }
  }
}

fun resetPlayers(players: map<Int as int8, Player>, n: Int) {
  let i: Int = 0;

  while (i < n) {
    let p: Player = players.get(i)!!;
    p.dekulakVote = -1;
    p.normVote = -1;
    i = i + 1;
  }
}

fun resignPlayer(players: map<Int, Player>, activePlayers: Int, n: Int, idx: Int, reason: Int) {
  let toResign: Player = players.get(idx)!!;
  toResign.status = reason;

  let balanceSplit: Int = toResign.balance / activePlayers;
  let factoriesSplit: Int = toResign.buildings.factories / activePlayers;
  let farmsSplit: Int = toResign.buildings.farms / activePlayers;
  let jailsSplit: Int = toResign.buildings.jails / activePlayers;

  let i: Int = 0;
  while (i < n) {
    if (i != idx) {
      let p: Player = players.get(i)!!;
      if (p.status == 0) {
        p.balance = p.balance + balanceSplit;
        p.buildings.factories = p.buildings.factories + factoriesSplit;
        p.buildings.farms = p.buildings.farms + farmsSplit;
        p.buildings.jails = p.buildings.jails + jailsSplit;
      }
    }
    i = i + 1;
  }

  toResign.balance = 0;
  toResign.buildings.factories = 0;
  toResign.buildings.farms = 0;
  toResign.buildings.jails = 0;
}

/* round check
 * 0 - round going
 * 1 - round finished
 * 2 - game finished
 */

fun roundCheck(players: map<Int, Player>, n: Int, currentRound: Int): Int {
  let i: Int = 0;
  let activePlayers: Int = 0;
  let votesOk: Bool = true;

  while (i < n) {
    let p: Player = players.get(i)!!;
    if (p.status == 0) {
      activePlayers = activePlayers + 1;
      if (p.dekulakVote == -1 || p.normVote == -1) {
        if (activePlayers > 1) {
          return 0;
        }
        else {
          votesOk = false;
        }
      }
    }
    i = i + 1;
  }

  if (activePlayers == 1) {
    return 2;
  }

  if (!votesOk) {
    return 0;
  }

  i = 0;
  let normVotes: Buildings = Buildings{ factories: 0, farms: 0, jails: 0 };
  let dekulakVotes: map<Int as uint8, Int as uint8> = emptyMap();
  let prevChosenPlayer: Int = -1;
  let chosenPlayer: Int = -1;
  let fst: Int = -1;

  while (i < n) {
    let p: Player = players.get(i)!!;
    if (p.chosen) {
      prevChosenPlayer = i;
    }
    if (p.status == 0) {
      if (prevChosenPlayer != -1 && chosenPlayer == -1) {
        p.chosen = true;
        chosenPlayer = i;
      }
      if (fst == -1) {
        fst = i;
      }
      buildMore(normVotes, p.normVote, 1);
      if (!dekulakVotes.exists(p.dekulakVote)) {
        dekulakVotes.set(p.dekulakVote, 1);
      }
      else {
        dekulakVotes.replace(p.dekulakVote, dekulakVotes.get(p.dekulakVote)!! + 1);
      }
    }
    i = i + 1;
  }

  if (chosenPlayer == -1) {
    let p: Player = players.get(fst)!!;
    p.chosen = true;
  }

  i = 0;

  let toDekulak: Int = -1;

  while (i < n) {
    let votes: Int = dekulakVotes.get(i)!!;
    if (votes > activePlayers / 2) {
      toDekulak = i;
    }
    i = i + 1;
  }

  let chosenNorm: Int = -1;
  if (normVotes.factories > normVotes.farms && normVotes.factories > normVotes.jails) {
    chosenNorm = 0;
  }
  else if (normVotes.farms > normVotes.factories && normVotes.farms > normVotes.jails) {
    chosenNorm = 1;
  }
  else if (normVotes.jails > normVotes.factories && normVotes.jails > normVotes.farms) {
    chosenNorm = 2;
  }
  else {
    chosenNorm = players.get(chosenPlayer)!!.normVote;
  }

  let toGulag: Int = -1;
  let minV: Int = -1;
  let minIdx: Int = -1;
  i = 0;

  while (i < n) {
    let p: Player = players.get(i)!!;
    if (p.status == 0) {
      let pV: Int = getByNumber(p.buildings, chosenNorm);
      if (minV == -1 || pV < minV) {
        minV = pV;
        minIdx = i;
      }
    }
    i = i + 1;
  }

  if (toGulag != -1) {
    activePlayers = activePlayers - 1;
    resignPlayer(players, toGulag, 1);
  }

  if (toDekulak != -1) {
    activePlayers = activePlayers - 1;
    resignPlayer(players, toDekulak, 2);
  }

  if (activePlayers < 2) {
    return 2;
  }

  return 1;
}

message Moves {
  head: Cell;
}

contract CryptoCommunism with Deployable {
  seqno: Int as uint64;

  jettonWalletAddress: Address;
  admin: Address;
  balance: Int as uint64;

  winner: Int as int8 = -1;
  round: Int as uint8 = 0;
  const MaxPlayers: Int = 5;
  players: map<Int as uint8, Player>;
  playersLength: Int as uint8 = 0;

  fun pushPlayer(addr: Address, deposit: Int) {
    if (self.playersLength >= self.MaxPlayers) {
      throw(36);
    } else {
      self.players.set(self.playersLength, Player{ address: addr, balance: deposit, status: 0, chosen: self.playersLength == 0 });
      self.playersLength += 1;
    }
  }

  init(seqno: Int, initBalance: Int, jettonWalletCode: Cell, jettonMasterAddress: Address, playersList: Cell) {
    self.seqno = seqno;
    self.admin = sender();
    self.balance = initBalance;

    self.jettonWalletAddress = calculateJettonWalletAddress(
      myAddress(),
      jettonMasterAddress,
      jettonWalletCode,
    );

    self.players = emptyMap();
    let ps: Slice = playersList.asSlice();

    while (ps.refs() > 0) {
      self.pushPlayer(ps.loadAddress(), ps.loadCoins());
      if (ps.refs() > 0) {
        ps = ps.loadRef().asSlice();
      }
    }

    self.pushPlayer(ps.loadAddress(), ps.loadCoins());
  }

  fun loadMove(ps: Slice): Move {
    /*
     * playerId: Int as uint8;
     * action: Int as uint8;
     * arg1: Int? as uint8;
     * arg2: Int? as uint64;
     */
    let playerId: Int = ps.loadUint(8);
    let action: Int = ps.loadUint(8);
    let arg1: Int = ps.loadUint(8);
    if (action == 0) { //build
      let arg2: Int = ps.loadCoins();
      return Move{ playerId, action, arg1, arg2 };
    }
    else {
      return Move{ playerId, action, arg1 };
    }
  }

  fun onMove(ps: Slice) {
    let m: Move = self.loadMove(ps);
    evalMove(self.players, m);

    let gameStatus: Int = roundCheck(players, playersLength, self.round);

    if (gameStatus == 0) {
      //DO NOTHING
    }
    else if (gameStatus == 1) {
      self.round = self.round + 1;
      resetPlayers(players, playersLength);
    }
    else if (gameStatue == 2) {
      let i: Int = 0;
      while (i < playersLength) {
        let p: Player = self.players.get(i)!!;

        if (p.status == 0 && p.address) {
          self.winner = i;
          self.sendJetton(Withdraw{ amount: self.balance, desination: p.address, queryId: self.seqno });

          return;
        }

        i = i + 1;
      }
    }
  }

  receive(msg: Moves) {
    require(sender() == self.admin, "Forbidden");
    require(self.winner == -1, "Game finished");

    let ps: Slice = playersList.asSlice();

    while (ps.refs() > 0) {
      self.onMove(ps);
      if (ps.refs() > 0) {
        ps = ps.loadRef().asSlice();
      }
    }

    self.onMove(ps);
  }

  fun sendJetton(msg: Withdraw) {
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

  receive(msg: Withdraw) {
    require(sender() == self.admin, "Forbidden");
    self.sendJetton(msg);
  }

  get fun balance(): Int {
    return self.balance;
  }

  get fun jettonWalletAddress(): Address {
    return self.jettonWalletAddress;
  }

  get fun playersLength(): Int {
    return self.playersLength;
  }

  get fun players(): String {
    let bs = beginString();
    let i: Int = 0;
    repeat(self.playersLength) {
      let p: Player = self.players.get(i)!!;
      bs.append(playerToString(p));
      bs.append("\n");
      i = i + 1;
    }

    return bs.toString();
  }

  get fun winner(): String {
    if (self.winner == -1) {
      return "";
    }

    return playerToString(self.players.get(self.winner)!!);
  }
}
