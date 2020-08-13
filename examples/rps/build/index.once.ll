#lang ll
parts {
  "A" = interact {
    commits = T_Fun [] T_Null,
    endsWith = T_Fun [T_Bytes] T_Null,
    getHand = T_Fun [] T_Bytes,
    getParams = T_Fun [] (T_Tuple [T_UInt256,T_UInt256]),
    partnerIs = T_Fun [T_Address] T_Null,
    random = T_Fun [] T_UInt256,
    reveals = T_Fun [T_Bytes] T_Null},
  "B" = interact {
    acceptParams = T_Fun [T_UInt256,T_UInt256] T_Null,
    endsWith = T_Fun [T_Bytes] T_Null,
    getHand = T_Fun [] T_Bytes,
    partnerIs = T_Fun [T_Address] T_Null,
    random = T_Fun [] T_UInt256,
    shows = T_Fun [] T_Null},
  "O" = interact {
    }};

only("A") {
  const "one of [\"wagerAmount\",\"escrowAmount\"] (as interact)":T_Tuple [T_UInt256,T_UInt256]:1 = interact("A")."getParams"();
  const "tuple idx":T_UInt256:2 = "one of [\"wagerAmount\",\"escrowAmount\"] (as interact)":T_Tuple [T_UInt256,T_UInt256]:1[0];
  const "tuple idx":T_UInt256:3 = "one of [\"wagerAmount\",\"escrowAmount\"] (as interact)":T_Tuple [T_UInt256,T_UInt256]:1[1];
   };
only("A") {
  const "prim":T_UInt256:7 = ADD("tuple idx":T_UInt256:2,"tuple idx":T_UInt256:3);
   };
publish("A", join("A":T_Address:6))("tuple idx":T_UInt256:2,"tuple idx":T_UInt256:3)("tuple idx":T_UInt256:4, "tuple idx":T_UInt256:5).pay("prim":T_UInt256:7){
  const "prim":T_UInt256:8 = ADD("tuple idx":T_UInt256:4,"tuple idx":T_UInt256:5);
  const "prim":T_UInt256:9 = TXN_VALUE();
  const "prim":T_Bool:10 = PEQ("prim":T_UInt256:8,"prim":T_UInt256:9);
  claim(CT_Require)("prim":T_Bool:10);
  commit();
  only("B") {
    const "interact":T_Null:12 = interact("B")."partnerIs"("A":T_Address:6);
    const "interact":T_Null:13 = interact("B")."acceptParams"("tuple idx":T_UInt256:4,"tuple idx":T_UInt256:5);
     };
  only("B") {
     };
  publish("B", join("B":T_Address:14))()().pay("tuple idx":T_UInt256:4).timeout((DLC_Int 10, {
    only("A") {
       };
    publish("A", again("A":T_Address:6))()().pay(DLC_Int 0){
      const "prim":T_UInt256:19 = TXN_VALUE();
      const "prim":T_Bool:20 = PEQ(DLC_Int 0,"prim":T_UInt256:19);
      claim(CT_Require)("prim":T_Bool:20);
      const "prim":T_UInt256:21 = BALANCE();
      transfer.("prim":T_UInt256:21).to("A":T_Address:6);
      commit();
      only("A") {
        claim(CT_Require)(DLC_Bool True);
        const "interact":T_Null:27 = interact("A")."endsWith"(DLC_Bytes "Bob quits");
         };
      only("B") {
        claim(CT_Require)(DLC_Bool True);
        const "interact":T_Null:32 = interact("B")."endsWith"(DLC_Bytes "Bob quits");
         };
      exit(); } })){
    const "prim":T_UInt256:15 = TXN_VALUE();
    const "prim":T_Bool:16 = PEQ("tuple idx":T_UInt256:4,"prim":T_UInt256:15);
    claim(CT_Require)("prim":T_Bool:16);
    commit();
    only("A") {
      const "interact":T_Null:34 = interact("A")."partnerIs"("B":T_Address:14);
      let "_handA (as clo app)":T_UInt256:36;
      const "s (as interact)":T_Bytes:37 = interact("A")."getHand"();
      const "rockP (as prim)":T_Bool:38 = BYTES_EQ("s (as interact)":T_Bytes:37,DLC_Bytes "ROCK");
      const "paperP (as prim)":T_Bool:39 = BYTES_EQ("s (as interact)":T_Bytes:37,DLC_Bytes "PAPER");
      const "scissorsP (as prim)":T_Bool:40 = BYTES_EQ("s (as interact)":T_Bytes:37,DLC_Bytes "SCISSORS");
      const "_handA (as prim)":T_Bool:42 = IF_THEN_ELSE("rockP (as prim)":T_Bool:38,DLC_Bool True,"paperP (as prim)":T_Bool:39);
      const "_handA (as prim)":T_Bool:44 = IF_THEN_ELSE("_handA (as prim)":T_Bool:42,DLC_Bool True,"scissorsP (as prim)":T_Bool:40);
      claim(CT_Assume)("_handA (as prim)":T_Bool:44);
      if "rockP (as prim)":T_Bool:38 then {
        "_handA (as clo app)":T_UInt256:36 = DLC_Int 0;
         }
      else {
        if "paperP (as prim)":T_Bool:39 then {
          "_handA (as clo app)":T_UInt256:36 = DLC_Int 1;
           }
        else {
          "_handA (as clo app)":T_UInt256:36 = DLC_Int 2;
           };
         };
      const "_handA (as prim)":T_Bool:47 = PLE(DLC_Int 0,"_handA (as clo app)":T_UInt256:36);
      const "_handA (as prim)":T_Bool:48 = PLT("_handA (as clo app)":T_UInt256:36,DLC_Int 3);
      const "_handA (as prim)":T_Bool:50 = IF_THEN_ELSE("_handA (as prim)":T_Bool:47,"_handA (as prim)":T_Bool:48,DLC_Bool False);
      claim(CT_Assert)("_handA (as prim)":T_Bool:50);
      const "salt (as interact)":T_UInt256:52 = interact("A")."random"();
      const "commitment (as digest)":T_UInt256:53 = digest("salt (as interact)":T_UInt256:52,"_handA (as clo app)":T_UInt256:36);
      const "interact":T_Null:54 = interact("A")."commits"();
       };
    only("A") {
       };
    publish("A", again("A":T_Address:6))("commitment (as digest)":T_UInt256:53)("commitment (as digest)":T_UInt256:55).pay(DLC_Int 0).timeout((DLC_Int 10, {
      only("B") {
         };
      publish("B", again("B":T_Address:14))()().pay(DLC_Int 0){
        const "prim":T_UInt256:60 = TXN_VALUE();
        const "prim":T_Bool:61 = PEQ(DLC_Int 0,"prim":T_UInt256:60);
        claim(CT_Require)("prim":T_Bool:61);
        const "prim":T_UInt256:62 = BALANCE();
        transfer.("prim":T_UInt256:62).to("B":T_Address:14);
        commit();
        only("A") {
          claim(CT_Require)(DLC_Bool True);
          const "interact":T_Null:68 = interact("A")."endsWith"(DLC_Bytes "Alice quits");
           };
        only("B") {
          claim(CT_Require)(DLC_Bool True);
          const "interact":T_Null:73 = interact("B")."endsWith"(DLC_Bytes "Alice quits");
           };
        exit(); } })){
      const "prim":T_UInt256:56 = TXN_VALUE();
      const "prim":T_Bool:57 = PEQ(DLC_Int 0,"prim":T_UInt256:56);
      claim(CT_Require)("prim":T_Bool:57);
      commit();
      only("B") {
        let "handB (as clo app)":T_UInt256:76;
        const "s (as interact)":T_Bytes:77 = interact("B")."getHand"();
        const "rockP (as prim)":T_Bool:78 = BYTES_EQ("s (as interact)":T_Bytes:77,DLC_Bytes "ROCK");
        const "paperP (as prim)":T_Bool:79 = BYTES_EQ("s (as interact)":T_Bytes:77,DLC_Bytes "PAPER");
        const "scissorsP (as prim)":T_Bool:80 = BYTES_EQ("s (as interact)":T_Bytes:77,DLC_Bytes "SCISSORS");
        const "handB (as prim)":T_Bool:82 = IF_THEN_ELSE("rockP (as prim)":T_Bool:78,DLC_Bool True,"paperP (as prim)":T_Bool:79);
        const "handB (as prim)":T_Bool:84 = IF_THEN_ELSE("handB (as prim)":T_Bool:82,DLC_Bool True,"scissorsP (as prim)":T_Bool:80);
        claim(CT_Assume)("handB (as prim)":T_Bool:84);
        if "rockP (as prim)":T_Bool:78 then {
          "handB (as clo app)":T_UInt256:76 = DLC_Int 0;
           }
        else {
          if "paperP (as prim)":T_Bool:79 then {
            "handB (as clo app)":T_UInt256:76 = DLC_Int 1;
             }
          else {
            "handB (as clo app)":T_UInt256:76 = DLC_Int 2;
             };
           };
        const "handB (as prim)":T_Bool:87 = PLE(DLC_Int 0,"handB (as clo app)":T_UInt256:76);
        const "handB (as prim)":T_Bool:88 = PLT("handB (as clo app)":T_UInt256:76,DLC_Int 3);
        const "handB (as prim)":T_Bool:90 = IF_THEN_ELSE("handB (as prim)":T_Bool:87,"handB (as prim)":T_Bool:88,DLC_Bool False);
        claim(CT_Assert)("handB (as prim)":T_Bool:90);
        const "interact":T_Null:91 = interact("B")."shows"();
         };
      only("B") {
         };
      publish("B", again("B":T_Address:14))("handB (as clo app)":T_UInt256:76)("handB (as clo app)":T_UInt256:92).pay(DLC_Int 0).timeout((DLC_Int 10, {
        only("A") {
           };
        publish("A", again("A":T_Address:6))()().pay(DLC_Int 0){
          const "prim":T_UInt256:97 = TXN_VALUE();
          const "prim":T_Bool:98 = PEQ(DLC_Int 0,"prim":T_UInt256:97);
          claim(CT_Require)("prim":T_Bool:98);
          const "prim":T_UInt256:99 = BALANCE();
          transfer.("prim":T_UInt256:99).to("A":T_Address:6);
          commit();
          only("A") {
            claim(CT_Require)(DLC_Bool True);
            const "interact":T_Null:105 = interact("A")."endsWith"(DLC_Bytes "Bob quits");
             };
          only("B") {
            claim(CT_Require)(DLC_Bool True);
            const "interact":T_Null:110 = interact("B")."endsWith"(DLC_Bytes "Bob quits");
             };
          exit(); } })){
        const "prim":T_UInt256:93 = TXN_VALUE();
        const "prim":T_Bool:94 = PEQ(DLC_Int 0,"prim":T_UInt256:93);
        claim(CT_Require)("prim":T_Bool:94);
        const "prim":T_Bool:112 = PLE(DLC_Int 0,"handB (as clo app)":T_UInt256:92);
        const "prim":T_Bool:113 = PLT("handB (as clo app)":T_UInt256:92,DLC_Int 3);
        const "prim":T_Bool:115 = IF_THEN_ELSE("prim":T_Bool:112,"prim":T_Bool:113,DLC_Bool False);
        claim(CT_Require)("prim":T_Bool:115);
        commit();
        only("A") {
          let "clo app":T_Bytes:117;
          const "prim":T_Bool:119 = PLE(DLC_Int 0,"handB (as clo app)":T_UInt256:92);
          const "prim":T_Bool:120 = PLT("handB (as clo app)":T_UInt256:92,DLC_Int 3);
          const "prim":T_Bool:122 = IF_THEN_ELSE("prim":T_Bool:119,"prim":T_Bool:120,DLC_Bool False);
          claim(CT_Require)("prim":T_Bool:122);
          const "prim":T_Bool:123 = PEQ("handB (as clo app)":T_UInt256:92,DLC_Int 0);
          if "prim":T_Bool:123 then {
            "clo app":T_Bytes:117 = DLC_Bytes "ROCK";
             }
          else {
            const "prim":T_Bool:124 = PEQ("handB (as clo app)":T_UInt256:92,DLC_Int 1);
            if "prim":T_Bool:124 then {
              "clo app":T_Bytes:117 = DLC_Bytes "PAPER";
               }
            else {
              "clo app":T_Bytes:117 = DLC_Bytes "SCISSORS";
               };
             };
          const "interact":T_Null:125 = interact("A")."reveals"("clo app":T_Bytes:117);
           };
        only("A") {
           };
        publish("A", again("A":T_Address:6))("salt (as interact)":T_UInt256:52,"_handA (as clo app)":T_UInt256:36)("salt (as interact)":T_UInt256:126, "_handA (as clo app)":T_UInt256:127).pay(DLC_Int 0).timeout((DLC_Int 10, {
          only("B") {
             };
          publish("B", again("B":T_Address:14))()().pay(DLC_Int 0){
            const "prim":T_UInt256:132 = TXN_VALUE();
            const "prim":T_Bool:133 = PEQ(DLC_Int 0,"prim":T_UInt256:132);
            claim(CT_Require)("prim":T_Bool:133);
            const "prim":T_UInt256:134 = BALANCE();
            transfer.("prim":T_UInt256:134).to("B":T_Address:14);
            commit();
            only("A") {
              claim(CT_Require)(DLC_Bool True);
              const "interact":T_Null:140 = interact("A")."endsWith"(DLC_Bytes "Alice quits");
               };
            only("B") {
              claim(CT_Require)(DLC_Bool True);
              const "interact":T_Null:145 = interact("B")."endsWith"(DLC_Bytes "Alice quits");
               };
            exit(); } })){
          const "prim":T_UInt256:128 = TXN_VALUE();
          const "prim":T_Bool:129 = PEQ(DLC_Int 0,"prim":T_UInt256:128);
          claim(CT_Require)("prim":T_Bool:129);
          const "digest":T_UInt256:147 = digest("salt (as interact)":T_UInt256:126,"_handA (as clo app)":T_UInt256:127);
          const "prim":T_Bool:148 = PEQ("commitment (as digest)":T_UInt256:55,"digest":T_UInt256:147);
          claim(CT_Require)("prim":T_Bool:148);
          const "prim":T_Bool:150 = PLE(DLC_Int 0,"_handA (as clo app)":T_UInt256:127);
          const "prim":T_Bool:151 = PLT("_handA (as clo app)":T_UInt256:127,DLC_Int 3);
          const "prim":T_Bool:153 = IF_THEN_ELSE("prim":T_Bool:150,"prim":T_Bool:151,DLC_Bool False);
          claim(CT_Require)("prim":T_Bool:153);
          let "outcome (as clo app)":T_UInt256:155;
          const "validA (as prim)":T_Bool:157 = PLE(DLC_Int 0,"_handA (as clo app)":T_UInt256:127);
          const "validA (as prim)":T_Bool:158 = PLT("_handA (as clo app)":T_UInt256:127,DLC_Int 3);
          const "validA (as prim)":T_Bool:160 = IF_THEN_ELSE("validA (as prim)":T_Bool:157,"validA (as prim)":T_Bool:158,DLC_Bool False);
          const "validB (as prim)":T_Bool:162 = PLE(DLC_Int 0,"handB (as clo app)":T_UInt256:92);
          const "validB (as prim)":T_Bool:163 = PLT("handB (as clo app)":T_UInt256:92,DLC_Int 3);
          const "validB (as prim)":T_Bool:165 = IF_THEN_ELSE("validB (as prim)":T_Bool:162,"validB (as prim)":T_Bool:163,DLC_Bool False);
          const "outcome (as prim)":T_Bool:167 = IF_THEN_ELSE("validA (as prim)":T_Bool:160,"validB (as prim)":T_Bool:165,DLC_Bool False);
          if "outcome (as prim)":T_Bool:167 then {
            const "outcome (as prim)":T_UInt256:168 = SUB(DLC_Int 4,"handB (as clo app)":T_UInt256:92);
            const "outcome (as prim)":T_UInt256:169 = ADD("_handA (as clo app)":T_UInt256:127,"outcome (as prim)":T_UInt256:168);
            const "outcome (as prim)":T_UInt256:170 = MOD("outcome (as prim)":T_UInt256:169,DLC_Int 3);
            "outcome (as clo app)":T_UInt256:155 = "outcome (as prim)":T_UInt256:170;
             }
          else {
            if "validA (as prim)":T_Bool:160 then {
              "outcome (as clo app)":T_UInt256:155 = DLC_Int 2;
               }
            else {
              if "validB (as prim)":T_Bool:165 then {
                "outcome (as clo app)":T_UInt256:155 = DLC_Int 0;
                 }
              else {
                "outcome (as clo app)":T_UInt256:155 = DLC_Int 1;
                 };
               };
             };
          const "outcome (as prim)":T_Bool:173 = PLE(DLC_Int 0,"outcome (as clo app)":T_UInt256:155);
          const "outcome (as prim)":T_Bool:174 = PLT("outcome (as clo app)":T_UInt256:155,DLC_Int 5);
          const "outcome (as prim)":T_Bool:176 = IF_THEN_ELSE("outcome (as prim)":T_Bool:173,"outcome (as prim)":T_Bool:174,DLC_Bool False);
          claim(CT_Assert)("outcome (as prim)":T_Bool:176);
          const "prim":T_Bool:177 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 2);
          const "prim":T_Bool:179 = PLE(DLC_Int 0,"_handA (as clo app)":T_UInt256:127);
          const "prim":T_Bool:180 = PLT("_handA (as clo app)":T_UInt256:127,DLC_Int 3);
          const "prim":T_Bool:182 = IF_THEN_ELSE("prim":T_Bool:179,"prim":T_Bool:180,DLC_Bool False);
          const "prim":T_Bool:185 = IF_THEN_ELSE("prim":T_Bool:177,DLC_Bool False,DLC_Bool True);
          const "prim":T_Bool:187 = IF_THEN_ELSE("prim":T_Bool:185,DLC_Bool True,"prim":T_Bool:182);
          claim(CT_Assert)("prim":T_Bool:187);
          const "prim":T_Bool:188 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 0);
          const "prim":T_Bool:190 = PLE(DLC_Int 0,"handB (as clo app)":T_UInt256:92);
          const "prim":T_Bool:191 = PLT("handB (as clo app)":T_UInt256:92,DLC_Int 3);
          const "prim":T_Bool:193 = IF_THEN_ELSE("prim":T_Bool:190,"prim":T_Bool:191,DLC_Bool False);
          const "prim":T_Bool:196 = IF_THEN_ELSE("prim":T_Bool:188,DLC_Bool False,DLC_Bool True);
          const "prim":T_Bool:198 = IF_THEN_ELSE("prim":T_Bool:196,DLC_Bool True,"prim":T_Bool:193);
          claim(CT_Assert)("prim":T_Bool:198);
          const "prim":T_Bool:200 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 2);
          const "prim":T_Bool:203 = PEQ("_handA (as clo app)":T_UInt256:127,DLC_Int 0);
          const "prim":T_Bool:205 = IF_THEN_ELSE("prim":T_Bool:203,"prim":T_Bool:200,DLC_Bool False);
          claim(CT_Possible)("prim":T_Bool:205);
          const "prim":T_Bool:207 = PEQ("_handA (as clo app)":T_UInt256:127,DLC_Int 1);
          const "prim":T_Bool:209 = IF_THEN_ELSE("prim":T_Bool:207,"prim":T_Bool:200,DLC_Bool False);
          claim(CT_Possible)("prim":T_Bool:209);
          const "prim":T_Bool:211 = PEQ("_handA (as clo app)":T_UInt256:127,DLC_Int 2);
          const "prim":T_Bool:213 = IF_THEN_ELSE("prim":T_Bool:211,"prim":T_Bool:200,DLC_Bool False);
          claim(CT_Possible)("prim":T_Bool:213);
          const "prim":T_Bool:214 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 0);
          const "prim":T_Bool:217 = PEQ("handB (as clo app)":T_UInt256:92,DLC_Int 0);
          const "prim":T_Bool:219 = IF_THEN_ELSE("prim":T_Bool:217,"prim":T_Bool:214,DLC_Bool False);
          claim(CT_Possible)("prim":T_Bool:219);
          const "prim":T_Bool:221 = PEQ("handB (as clo app)":T_UInt256:92,DLC_Int 1);
          const "prim":T_Bool:223 = IF_THEN_ELSE("prim":T_Bool:221,"prim":T_Bool:214,DLC_Bool False);
          claim(CT_Possible)("prim":T_Bool:223);
          const "prim":T_Bool:225 = PEQ("handB (as clo app)":T_UInt256:92,DLC_Int 2);
          const "prim":T_Bool:227 = IF_THEN_ELSE("prim":T_Bool:225,"prim":T_Bool:214,DLC_Bool False);
          claim(CT_Possible)("prim":T_Bool:227);
          let "one of [\"getsA\",\"getsB\"] (as clo app)":T_Tuple [T_UInt256,T_UInt256]:228;
          const "one of [\"getsA\",\"getsB\"] (as prim)":T_Bool:229 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 2);
          if "one of [\"getsA\",\"getsB\"] (as prim)":T_Bool:229 then {
            const "one of [\"getsA\",\"getsB\"] (as prim)":T_UInt256:230 = MUL(DLC_Int 2,"tuple idx":T_UInt256:4);
            "one of [\"getsA\",\"getsB\"] (as clo app)":T_Tuple [T_UInt256,T_UInt256]:228 = ["one of [\"getsA\",\"getsB\"] (as prim)":T_UInt256:230,DLC_Int 0];
             }
          else {
            const "one of [\"getsA\",\"getsB\"] (as prim)":T_Bool:231 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 0);
            if "one of [\"getsA\",\"getsB\"] (as prim)":T_Bool:231 then {
              const "one of [\"getsA\",\"getsB\"] (as prim)":T_UInt256:232 = MUL(DLC_Int 2,"tuple idx":T_UInt256:4);
              "one of [\"getsA\",\"getsB\"] (as clo app)":T_Tuple [T_UInt256,T_UInt256]:228 = [DLC_Int 0,"one of [\"getsA\",\"getsB\"] (as prim)":T_UInt256:232];
               }
            else {
              "one of [\"getsA\",\"getsB\"] (as clo app)":T_Tuple [T_UInt256,T_UInt256]:228 = ["tuple idx":T_UInt256:4,"tuple idx":T_UInt256:4];
               };
             };
          const "tuple idx":T_UInt256:233 = "one of [\"getsA\",\"getsB\"] (as clo app)":T_Tuple [T_UInt256,T_UInt256]:228[0];
          const "tuple idx":T_UInt256:234 = "one of [\"getsA\",\"getsB\"] (as clo app)":T_Tuple [T_UInt256,T_UInt256]:228[1];
          const "prim":T_UInt256:235 = ADD("tuple idx":T_UInt256:5,"tuple idx":T_UInt256:233);
          transfer.("prim":T_UInt256:235).to("A":T_Address:6);
          transfer.("tuple idx":T_UInt256:234).to("B":T_Address:14);
          commit();
          only("A") {
            let "clo app":T_Bytes:239;
            const "prim":T_Bool:241 = PLE(DLC_Int 0,"outcome (as clo app)":T_UInt256:155);
            const "prim":T_Bool:242 = PLT("outcome (as clo app)":T_UInt256:155,DLC_Int 5);
            const "prim":T_Bool:244 = IF_THEN_ELSE("prim":T_Bool:241,"prim":T_Bool:242,DLC_Bool False);
            claim(CT_Require)("prim":T_Bool:244);
            const "prim":T_Bool:245 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 0);
            if "prim":T_Bool:245 then {
              "clo app":T_Bytes:239 = DLC_Bytes "Bob wins";
               }
            else {
              const "prim":T_Bool:246 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 1);
              if "prim":T_Bool:246 then {
                "clo app":T_Bytes:239 = DLC_Bytes "Draw";
                 }
              else {
                const "prim":T_Bool:247 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 2);
                if "prim":T_Bool:247 then {
                  "clo app":T_Bytes:239 = DLC_Bytes "Alice wins";
                   }
                else {
                  const "prim":T_Bool:248 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 3);
                  if "prim":T_Bool:248 then {
                    "clo app":T_Bytes:239 = DLC_Bytes "Alice quits";
                     }
                  else {
                    "clo app":T_Bytes:239 = DLC_Bytes "Bob quits";
                     };
                   };
                 };
               };
            const "interact":T_Null:249 = interact("A")."endsWith"("clo app":T_Bytes:239);
             };
          only("B") {
            let "clo app":T_Bytes:251;
            const "prim":T_Bool:253 = PLE(DLC_Int 0,"outcome (as clo app)":T_UInt256:155);
            const "prim":T_Bool:254 = PLT("outcome (as clo app)":T_UInt256:155,DLC_Int 5);
            const "prim":T_Bool:256 = IF_THEN_ELSE("prim":T_Bool:253,"prim":T_Bool:254,DLC_Bool False);
            claim(CT_Require)("prim":T_Bool:256);
            const "prim":T_Bool:257 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 0);
            if "prim":T_Bool:257 then {
              "clo app":T_Bytes:251 = DLC_Bytes "Bob wins";
               }
            else {
              const "prim":T_Bool:258 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 1);
              if "prim":T_Bool:258 then {
                "clo app":T_Bytes:251 = DLC_Bytes "Draw";
                 }
              else {
                const "prim":T_Bool:259 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 2);
                if "prim":T_Bool:259 then {
                  "clo app":T_Bytes:251 = DLC_Bytes "Alice wins";
                   }
                else {
                  const "prim":T_Bool:260 = PEQ("outcome (as clo app)":T_UInt256:155,DLC_Int 3);
                  if "prim":T_Bool:260 then {
                    "clo app":T_Bytes:251 = DLC_Bytes "Alice quits";
                     }
                  else {
                    "clo app":T_Bytes:251 = DLC_Bytes "Bob quits";
                     };
                   };
                 };
               };
            const "interact":T_Null:261 = interact("B")."endsWith"("clo app":T_Bytes:251);
             };
          exit(); } } } } }