'reach 0.1 exe';

import "rps_shared.rsh";

const A = participant({
  _wagerAmount: uint256,
  _escrowAmount: uint256});

const B = participant({});

function main() {
  A.only(() => {
    const wagerAmount = declassify(_wagerAmount);
    const escrowAmount = declassify(_escrowAmount);
    interact.params(); });
  A.publish(wagerAmount, escrowAmount)
    .pay(wagerAmount + escrowAmount);
  commit();

  B.only(() => {
    interact.accepts(wagerAmount, escrowAmount); });
  B.pay(wagerAmount);

  var outcome = DRAW;
  invariant((balance() == ((2 * wagerAmount) + escrowAmount))
            && isOutcome(outcome));
  while ( outcome == DRAW ) {
    commit();

    A.only(() => {
      const _handA = getHand();
      const [_commitA, _saltA] = precommit(_handA);
      const commitA = declassify(_commitA);
      interact.commits(); });
    A.publish(commitA);
    commit();

    B.only(() => {
      const handB = declassify(getHand());
      interact.shows(); });
    B.publish(handB);
    require(isHand(handB));
    commit();

    A.only(() => {
      const saltA = declassify(_saltA);
      const handA = declassify(_handA);
      interact.reveals(showHand(handB)); });
    A.publish(saltA, handA);
    check_commit(commitA, saltA, handA);
    require(isHand(handA));
    const this_outcome = winner(handA, handB);
    assert(implies(this_outcome == A_WINS, isHand(handA)));
    assert(implies(this_outcome == B_WINS, isHand(handB)));
    fair_game(handA, handB, this_outcome);

    outcome = this_outcome;
    continue; }

  assert(outcome != DRAW);
  const [getsA, getsB] = (() => {
    if (outcome == A_WINS) {
      return [2 * wagerAmount, 0]; }
    else {
      return [0, 2 * wagerAmount]; } })();
  transfer(escrowAmount + getsA).to(A);
  transfer(getsB).to(B);
  commit();

  interact.outcome();
  return showOutcome(outcome); }