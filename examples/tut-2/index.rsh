'reach 0.1';

const Player =
      { getHand: Fun([], UInt256),
        seeOutcome: Fun([UInt256], Null) };

export const main =
  Reach.App(
    {},
    [['Alice', Player], ['Bob', Player]],
    (A, B) => {
      A.only(() => {
        const handA = declassify(interact.getHand()); });
      A.publish(handA);
      commit();

      B.only(() => {
        const handB = declassify(interact.getHand()); });
      B.publish(handB);

      const outcome = (handA + (4 - handB)) % 3;
      commit();

      each([A, B], () => {
        interact.seeOutcome(outcome); });
      exit(); });
