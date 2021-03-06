'reach 0.1';

// RPS Logic

const [ isHand, ROCK, PAPER, SCISSORS ] = makeEnum(3);
function showHand(handX) {
  assert(isHand(handX));
  if ( handX == ROCK ) { return 'ROCK'; }
  else if ( handX == PAPER ) { return 'PAPER'; }
  else { return 'SCISSORS'; } }

function getHand_(interact) {
  const s = interact.getHand();
  const rockP = s === 'ROCK';
  const paperP = s === 'PAPER';
  const scissorsP = s === 'SCISSORS';
  assume(rockP || paperP || scissorsP);
  if (rockP) { return ROCK; }
  else if (paperP) { return PAPER; }
  else { return SCISSORS; } }
function getHand(interact) {
  return ensure(isHand, getHand_(interact)); }

const [ isOutcome, B_WINS, DRAW, A_WINS, A_QUITS, B_QUITS ] = makeEnum(5);
function showOutcome(o) {
  assert(isOutcome(o));
  if (o == B_WINS) { return 'Bob wins'; }
  else if (o == DRAW) { return 'Draw'; }
  else if (o == A_WINS) { return 'Alice wins'; }
  else if (o == A_QUITS) { return 'Alice quits'; }
  else { return 'Bob quits'; } }

function winner_(handA, handB) {
  const validA = isHand(handA);
  const validB = isHand(handB);
  if (validA && validB) {
    return (handA + (4 - handB)) % 3; }
  else if (validA) {
    return A_WINS; }
  else if (validB) {
    return B_WINS; }
  else {
    return DRAW; } }
function winner(handA, handB) {
  return ensure(isOutcome, winner_(handA, handB)); }

function fair_if(handX, optionX, canWinX) {
  return possible((handX == optionX) && canWinX); }

function fair_for_player(handX, canWinX) {
  fair_if(handX, ROCK, canWinX);
  fair_if(handX, PAPER, canWinX);
  fair_if(handX, SCISSORS, canWinX); }

function fair_game(handA, handB, outcome) {
  fair_for_player(handA, (outcome == A_WINS));
  fair_for_player(handB, (outcome == B_WINS)); }

// Protocol
const DELAY = 10; // in blocks

const Player =
      { ...hasRandom,
        getHand: Fun([], Bytes),
        partnerIs: Fun([Address], Null),
        endsWith: Fun([Bytes], Null) };
const Alice =
      { ...Player,
        getParams: Fun([], Tuple(UInt256, UInt256)),
        commits: Fun([], Null),
        reveals: Fun([Bytes], Null) };
const Bob =
      { ...Player,
        acceptParams: Fun([UInt256, UInt256], Null),
        shows: Fun([], Null) };

const con_once =
  Reach.App(
    {},
    [['A', Alice], ['B', Bob], ['O', {}]],
    (A, B, O) => {
      function sendOutcome(which) {
        return () => {
          each([A, B], (which) => {
            interact.endsWith(showOutcome(which)); }); }; }

      A.only(() => {
        const [wagerAmount, escrowAmount] =
              declassify(interact.getParams()); });
      A.publish(wagerAmount, escrowAmount)
        .pay(wagerAmount + escrowAmount);
      commit();

      B.only(() => {
        interact.partnerIs(A);
        interact.acceptParams(wagerAmount, escrowAmount); });
      B.pay(wagerAmount)
        .timeout(DELAY, () => closeTo(A, sendOutcome(B_QUITS)));
      commit();

      A.only(() => {
        interact.partnerIs(B);
        const _handA = getHand(interact);
        const [_commitA, _saltA] = makeCommitment(interact, _handA);
        const commitA = declassify(_commitA);
        interact.commits(); });
      A.publish(commitA)
        .timeout(DELAY, () => closeTo(B, sendOutcome(A_QUITS)));
      commit();

      B.only(() => {
        const handB = declassify(getHand(interact));
        interact.shows(); });
      B.publish(handB)
        .timeout(DELAY, () => closeTo(A, sendOutcome(B_QUITS)));
      require(isHand(handB));
      commit();

      A.only(() => {
        const saltA = declassify(_saltA);
        const handA = declassify(_handA);
        interact.reveals(showHand(handB)); });
      A.publish(saltA, handA)
        .timeout(DELAY, () => closeTo(B, sendOutcome(A_QUITS)));
      checkCommitment(commitA, saltA, handA);
      require(isHand(handA));
      const outcome = winner(handA, handB);
      assert(implies(outcome == A_WINS, isHand(handA)));
      assert(implies(outcome == B_WINS, isHand(handB)));
      fair_game(handA, handB, outcome);

      const [getsA, getsB] = (() => {
        if (outcome == A_WINS) {
          return [2 * wagerAmount, 0]; }
        else if (outcome == B_WINS) {
          return [0, 2 * wagerAmount]; }
        else {
          return [wagerAmount, wagerAmount]; } })();
      transfer(escrowAmount + getsA).to(A);
      transfer(getsB).to(B);
      commit();

      sendOutcome(outcome)(); });

const con_nodraw =
  Reach.App(
    {},
    [['A', Alice], ['B', Bob], ['O', {}]],
    (A, B, O) => {
      function sendOutcome(which) {
        return () => {
          each([A, B], (which) => {
            interact.endsWith(showOutcome(which)); }); }; }

      A.only(() => {
        const [wagerAmount, escrowAmount] =
              declassify(interact.getParams()); });
      A.publish(wagerAmount, escrowAmount)
        .pay(wagerAmount + escrowAmount);
      commit();

      B.only(() => {
        interact.acceptParams(wagerAmount, escrowAmount); });
      B.pay(wagerAmount)
        .timeout(DELAY, () => closeTo(A, sendOutcome(B_QUITS)));

      var [ count, outcome ] = [ 0, DRAW ];
      invariant((balance() == ((2 * wagerAmount) + escrowAmount))
                && isOutcome(outcome)
                && outcome != A_QUITS
                && outcome != B_QUITS);
      while ( outcome == DRAW ) {
        commit();

        A.only(() => {
          const _handA = getHand(interact);
          const [_commitA, _saltA] = makeCommitment(interact, _handA);
          const commitA = declassify(_commitA);
          interact.commits(); });
        A.publish(commitA)
          .timeout(DELAY, () => closeTo(B, sendOutcome(A_QUITS)));
        commit();

        B.only(() => {
          const handB = declassify(getHand(interact));
          interact.shows(); });
        B.publish(handB)
          .timeout(DELAY, () => closeTo(A, sendOutcome(B_QUITS)));
        require(isHand(handB));
        commit();

        A.only(() => {
          const saltA = declassify(_saltA);
          const handA = declassify(_handA);
          interact.reveals(showHand(handB)); });
        A.publish(saltA, handA)
          .timeout(DELAY, () => closeTo(B, sendOutcome(A_QUITS)));
        checkCommitment(commitA, saltA, handA);
        require(isHand(handA));
        const roundOutcome = winner(handA, handB);
        assert(implies(roundOutcome == A_WINS, isHand(handA)));
        assert(implies(roundOutcome == B_WINS, isHand(handB)));
        fair_game(handA, handB, roundOutcome);

        [ count, outcome ] = [ 1 + count, roundOutcome ];
        continue; }

      assert(outcome != DRAW);

      const [getsA, getsB] = (() => {
        if (outcome == A_WINS) {
          return [2 * wagerAmount, 0]; }
        else if (outcome == B_WINS) {
          return [0, 2 * wagerAmount]; }
        else {
          return [wagerAmount, wagerAmount]; } })();
      transfer(escrowAmount + getsA).to(A);
      transfer(getsB).to(B);
      commit();

      sendOutcome(outcome)(); });

// Abstracted version

function abs_sendOutcome(A, B, which) {
  return () => {
    each([A, B], () => {
      interact.endsWith(showOutcome(which)); }); }; }

function setup(A, B) {
  A.only(() => {
    const [wagerAmount, escrowAmount] =
          declassify(interact.getParams()); });
  A.publish(wagerAmount, escrowAmount)
    .pay(wagerAmount + escrowAmount);
  commit();

  B.only(() => {
    interact.partnerIs(A);
    interact.acceptParams(wagerAmount, escrowAmount); });
  B.pay(wagerAmount)
    .timeout(DELAY, () => closeTo(A, abs_sendOutcome(A, B, B_QUITS)));
  commit();

  A.only(() => {
    interact.partnerIs(B); });

  return [wagerAmount, escrowAmount, A, B]; }

function round(A, B) {
  A.only(() => {
    const _handA = getHand(interact);
    const [_commitA, _saltA] = makeCommitment(interact, _handA);
    const commitA = declassify(_commitA);
    interact.commits(); });
  A.publish(commitA)
    .timeout(DELAY, () => closeTo(B, abs_sendOutcome(A, B, A_QUITS)) );
  commit();

  B.only(() => {
    const handB = declassify(getHand(interact));
    interact.shows(); });
  B.publish(handB)
    .timeout(DELAY, () => closeTo(A, abs_sendOutcome(A, B, B_QUITS)) );
  require(isHand(handB));
  commit();

  A.only(() => {
    const saltA = declassify(_saltA);
    const handA = declassify(_handA);
    interact.reveals(showHand(handB)); });
  A.publish(saltA, handA)
    .timeout(DELAY, () => closeTo(B, abs_sendOutcome(A, B, A_QUITS)) );
  checkCommitment(commitA, saltA, handA);
  require(isHand(handA));
  const outcome = winner(handA, handB);
  assert(implies(outcome == A_WINS, isHand(handA)));
  assert(implies(outcome == B_WINS, isHand(handB)));
  fair_game(handA, handB, outcome);

  return outcome; }

function finalize(wagerAmount, escrowAmount, A, B, outcome) {
  const [getsA, getsB] = (() => {
    if (outcome == A_WINS) {
      return [2 * wagerAmount, 0]; }
    else if (outcome == B_WINS) {
      return [0, 2 * wagerAmount]; }
    else {
      return [wagerAmount, wagerAmount]; } })();
  transfer(escrowAmount + getsA).to(A);
  transfer(getsB).to(B); }

const abs_once =
  Reach.App(
    {},
    [['A', Alice], ['B', Bob], ['O', {}]],
    (A, B, O) => {
      const [wagerAmount, escrowAmount, Ap, Bp] = setup(A, B);

      const outcome = round(A, B);
      finalize(wagerAmount, escrowAmount, Ap, Bp, outcome);
      commit();

      abs_sendOutcome(A, B, outcome)(); });

const abs_nodraw =
  Reach.App(
    {},
    [['A', Alice], ['B', Bob], ['O', {}]],
    (A, B, O) => {
      const [wagerAmount, escrowAmount, Ap, Bp] = setup(A, B);

      // setup ends in `step` mode, but we need to be in `consensus`
      // mode to start the while loop, so we have to have a blank
      // publish. We could have either part do it, but we're choosing
      // `A` to be "fair" and balance out how many times each party
      // publishes.
      //
      // But it would be cool to for it to be `B`, then have an
      // optimizer than can see that the previous publish was B and
      // combine them.
      A.publish()
        .timeout(DELAY, () => closeTo(B, abs_sendOutcome(A, B, A_QUITS)));

      var [ count, outcome ] = [ 0, DRAW ];
      invariant((balance() == ((2 * wagerAmount) + escrowAmount))
                && isOutcome(outcome)
                && outcome != A_QUITS
                && outcome != B_QUITS);
      while ( outcome == DRAW ) {
        commit();
        const roundOutcome = round(A, B);
        [ count, outcome ] = [ 1 + count, roundOutcome ];
        continue; }

      assert(outcome != DRAW);
      finalize(wagerAmount, escrowAmount, Ap, Bp, outcome);
      commit();

      abs_sendOutcome(A, B, outcome)(); });

// Interface

export const once = abs_once;
export const main = abs_nodraw;
