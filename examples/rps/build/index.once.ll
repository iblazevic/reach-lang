#lang ll
parts {
  "A" = interact {
    commits = Fun([], Null),
    endsWith = Fun([Bytes], Null),
    getHand = Fun([], Bytes),
    getParams = Fun([], Tuple(UInt256, UInt256)),
    partnerIs = Fun([Address], Null),
    random = Fun([], UInt256),
    reveals = Fun([Bytes], Null)},
  "B" = interact {
    acceptParams = Fun([UInt256, UInt256], Null),
    endsWith = Fun([Bytes], Null),
    getHand = Fun([], Bytes),
    partnerIs = Fun([Address], Null),
    random = Fun([], UInt256),
    shows = Fun([], Null)},
  "O" = interact {
    }};

only("A") {
  const v2 = interact("A")."getParams"();
  const v3 = v2[0];
  const v4 = v2[1];
   };
only("A") {
  const v8 = ADD(v3, v4);
   };
publish("A", join(v7))(v3, v4)(v5, v6).pay(v8){
  const v9 = ADD(v5, v6);
  const v10 = TXN_VALUE();
  const v12 = PEQ(v9, v10);
  claim(CT_Require)(v12);
  commit();
  only("B") {
    const v14 = interact("B")."partnerIs"(v7);
    const v15 = interact("B")."acceptParams"(v5, v6);
     };
  only("B") {
     };
  publish("B", join(v16))()().pay(v5)
    .timeout((DLC_Int 10, {
      only("A") {
         };
      publish("A", again(v7))()().pay(DLC_Int 0){
        const v22 = TXN_VALUE();
        const v24 = PEQ(DLC_Int 0, v22);
        claim(CT_Require)(v24);
        const v25 = BALANCE();
        transfer.(v25).to(v7);
        commit();
        only("A") {
          claim(CT_Assert)(DLC_Bool True);
          const v34 = interact("A")."endsWith"(DLC_Bytes "Bob quits");
           };
        only("B") {
          claim(CT_Assert)(DLC_Bool True);
          const v42 = interact("B")."endsWith"(DLC_Bytes "Bob quits");
           };
        exit(); } })){
    const v17 = TXN_VALUE();
    const v19 = PEQ(v5, v17);
    claim(CT_Require)(v19);
    commit();
    only("A") {
      const v44 = interact("A")."partnerIs"(v16);
       };
    only("A") {
      let v48;
      const v49 = interact("A")."getHand"();
      const v51 = BYTES_EQ(v49, DLC_Bytes "ROCK");
      const v53 = BYTES_EQ(v49, DLC_Bytes "PAPER");
      const v55 = BYTES_EQ(v49, DLC_Bytes "SCISSORS");
      const v56 = IF_THEN_ELSE(v51, DLC_Bool True, v53);
      const v57 = IF_THEN_ELSE(v56, DLC_Bool True, v55);
      claim(CT_Assume)(v57);
      if v51 then {
        v48 = DLC_Int 0;
         }
      else {
        if v53 then {
          v48 = DLC_Int 1;
           }
        else {
          v48 = DLC_Int 2;
           };
         };
      const v60 = PLE(DLC_Int 0, v48);
      const v61 = PLT(v48, DLC_Int 3);
      const v62 = IF_THEN_ELSE(v60, v61, DLC_Bool False);
      claim(CT_Assert)(v62);
      const v64 = interact("A")."random"();
      const v65 = digest(v64, v48);
      const v66 = interact("A")."commits"();
       };
    only("A") {
       };
    publish("A", again(v7))(v65)(v67).pay(DLC_Int 0)
      .timeout((DLC_Int 10, {
        only("B") {
           };
        publish("B", again(v16))()().pay(DLC_Int 0){
          const v73 = TXN_VALUE();
          const v75 = PEQ(DLC_Int 0, v73);
          claim(CT_Require)(v75);
          const v76 = BALANCE();
          transfer.(v76).to(v16);
          commit();
          only("A") {
            claim(CT_Assert)(DLC_Bool True);
            const v85 = interact("A")."endsWith"(DLC_Bytes "Alice quits");
             };
          only("B") {
            claim(CT_Assert)(DLC_Bool True);
            const v93 = interact("B")."endsWith"(DLC_Bytes "Alice quits");
             };
          exit(); } })){
      const v68 = TXN_VALUE();
      const v70 = PEQ(DLC_Int 0, v68);
      claim(CT_Require)(v70);
      commit();
      only("B") {
        let v96;
        const v97 = interact("B")."getHand"();
        const v99 = BYTES_EQ(v97, DLC_Bytes "ROCK");
        const v101 = BYTES_EQ(v97, DLC_Bytes "PAPER");
        const v103 = BYTES_EQ(v97, DLC_Bytes "SCISSORS");
        const v104 = IF_THEN_ELSE(v99, DLC_Bool True, v101);
        const v105 = IF_THEN_ELSE(v104, DLC_Bool True, v103);
        claim(CT_Assume)(v105);
        if v99 then {
          v96 = DLC_Int 0;
           }
        else {
          if v101 then {
            v96 = DLC_Int 1;
             }
          else {
            v96 = DLC_Int 2;
             };
           };
        const v108 = PLE(DLC_Int 0, v96);
        const v109 = PLT(v96, DLC_Int 3);
        const v110 = IF_THEN_ELSE(v108, v109, DLC_Bool False);
        claim(CT_Assert)(v110);
        const v111 = interact("B")."shows"();
         };
      only("B") {
         };
      publish("B", again(v16))(v96)(v112).pay(DLC_Int 0)
        .timeout((DLC_Int 10, {
          only("A") {
             };
          publish("A", again(v7))()().pay(DLC_Int 0){
            const v118 = TXN_VALUE();
            const v120 = PEQ(DLC_Int 0, v118);
            claim(CT_Require)(v120);
            const v121 = BALANCE();
            transfer.(v121).to(v7);
            commit();
            only("A") {
              claim(CT_Assert)(DLC_Bool True);
              const v130 = interact("A")."endsWith"(DLC_Bytes "Bob quits");
               };
            only("B") {
              claim(CT_Assert)(DLC_Bool True);
              const v138 = interact("B")."endsWith"(DLC_Bytes "Bob quits");
               };
            exit(); } })){
        const v113 = TXN_VALUE();
        const v115 = PEQ(DLC_Int 0, v113);
        claim(CT_Require)(v115);
        const v140 = PLE(DLC_Int 0, v112);
        const v141 = PLT(v112, DLC_Int 3);
        const v142 = IF_THEN_ELSE(v140, v141, DLC_Bool False);
        claim(CT_Require)(v142);
        commit();
        only("A") {
          let v144;
          const v146 = PLE(DLC_Int 0, v112);
          const v147 = PLT(v112, DLC_Int 3);
          const v148 = IF_THEN_ELSE(v146, v147, DLC_Bool False);
          claim(CT_Assert)(v148);
          const v150 = PEQ(v112, DLC_Int 0);
          if v150 then {
            v144 = DLC_Bytes "ROCK";
             }
          else {
            const v152 = PEQ(v112, DLC_Int 1);
            if v152 then {
              v144 = DLC_Bytes "PAPER";
               }
            else {
              v144 = DLC_Bytes "SCISSORS";
               };
             };
          const v153 = interact("A")."reveals"(v144);
           };
        only("A") {
           };
        publish("A", again(v7))(v64, v48)(v154, v155).pay(DLC_Int 0)
          .timeout((DLC_Int 10, {
            only("B") {
               };
            publish("B", again(v16))()().pay(DLC_Int 0){
              const v161 = TXN_VALUE();
              const v163 = PEQ(DLC_Int 0, v161);
              claim(CT_Require)(v163);
              const v164 = BALANCE();
              transfer.(v164).to(v16);
              commit();
              only("A") {
                claim(CT_Assert)(DLC_Bool True);
                const v173 = interact("A")."endsWith"(DLC_Bytes "Alice quits");
                 };
              only("B") {
                claim(CT_Assert)(DLC_Bool True);
                const v181 = interact("B")."endsWith"(DLC_Bytes "Alice quits");
                 };
              exit(); } })){
          const v156 = TXN_VALUE();
          const v158 = PEQ(DLC_Int 0, v156);
          claim(CT_Require)(v158);
          const v183 = digest(v154, v155);
          const v185 = PEQ(v67, v183);
          claim(CT_Require)(v185);
          const v187 = PLE(DLC_Int 0, v155);
          const v188 = PLT(v155, DLC_Int 3);
          const v189 = IF_THEN_ELSE(v187, v188, DLC_Bool False);
          claim(CT_Require)(v189);
          let v191;
          const v193 = PLE(DLC_Int 0, v155);
          const v194 = PLT(v155, DLC_Int 3);
          const v195 = IF_THEN_ELSE(v193, v194, DLC_Bool False);
          const v197 = PLE(DLC_Int 0, v112);
          const v198 = PLT(v112, DLC_Int 3);
          const v199 = IF_THEN_ELSE(v197, v198, DLC_Bool False);
          const v200 = IF_THEN_ELSE(v195, v199, DLC_Bool False);
          if v200 then {
            const v201 = SUB(DLC_Int 4, v112);
            const v202 = ADD(v155, v201);
            const v203 = MOD(v202, DLC_Int 3);
            v191 = v203;
             }
          else {
            if v195 then {
              v191 = DLC_Int 2;
               }
            else {
              if v199 then {
                v191 = DLC_Int 0;
                 }
              else {
                v191 = DLC_Int 1;
                 };
               };
             };
          const v206 = PLE(DLC_Int 0, v191);
          const v207 = PLT(v191, DLC_Int 5);
          const v208 = IF_THEN_ELSE(v206, v207, DLC_Bool False);
          claim(CT_Assert)(v208);
          const v210 = PEQ(v191, DLC_Int 2);
          const v212 = PLE(DLC_Int 0, v155);
          const v213 = PLT(v155, DLC_Int 3);
          const v214 = IF_THEN_ELSE(v212, v213, DLC_Bool False);
          const v217 = IF_THEN_ELSE(v210, DLC_Bool False, DLC_Bool True);
          const v218 = IF_THEN_ELSE(v217, DLC_Bool True, v214);
          claim(CT_Assert)(v218);
          const v220 = PEQ(v191, DLC_Int 0);
          const v222 = PLE(DLC_Int 0, v112);
          const v223 = PLT(v112, DLC_Int 3);
          const v224 = IF_THEN_ELSE(v222, v223, DLC_Bool False);
          const v227 = IF_THEN_ELSE(v220, DLC_Bool False, DLC_Bool True);
          const v228 = IF_THEN_ELSE(v227, DLC_Bool True, v224);
          claim(CT_Assert)(v228);
          const v231 = PEQ(v191, DLC_Int 2);
          const v235 = PEQ(v155, DLC_Int 0);
          const v236 = IF_THEN_ELSE(v235, v231, DLC_Bool False);
          claim(CT_Possible)(v236);
          const v239 = PEQ(v155, DLC_Int 1);
          const v240 = IF_THEN_ELSE(v239, v231, DLC_Bool False);
          claim(CT_Possible)(v240);
          const v243 = PEQ(v155, DLC_Int 2);
          const v244 = IF_THEN_ELSE(v243, v231, DLC_Bool False);
          claim(CT_Possible)(v244);
          const v246 = PEQ(v191, DLC_Int 0);
          const v250 = PEQ(v112, DLC_Int 0);
          const v251 = IF_THEN_ELSE(v250, v246, DLC_Bool False);
          claim(CT_Possible)(v251);
          const v254 = PEQ(v112, DLC_Int 1);
          const v255 = IF_THEN_ELSE(v254, v246, DLC_Bool False);
          claim(CT_Possible)(v255);
          const v258 = PEQ(v112, DLC_Int 2);
          const v259 = IF_THEN_ELSE(v258, v246, DLC_Bool False);
          claim(CT_Possible)(v259);
          let v261;
          const v263 = PEQ(v191, DLC_Int 2);
          if v263 then {
            const v264 = MUL(DLC_Int 2, v5);
            v261 = [v264, DLC_Int 0];
             }
          else {
            const v266 = PEQ(v191, DLC_Int 0);
            if v266 then {
              const v267 = MUL(DLC_Int 2, v5);
              v261 = [DLC_Int 0, v267];
               }
            else {
              v261 = [v5, v5];
               };
             };
          const v268 = v261[0];
          const v269 = v261[1];
          const v270 = ADD(v6, v268);
          transfer.(v270).to(v7);
          transfer.(v269).to(v16);
          commit();
          only("A") {
            let v274;
            const v276 = PLE(DLC_Int 0, v191);
            const v277 = PLT(v191, DLC_Int 5);
            const v278 = IF_THEN_ELSE(v276, v277, DLC_Bool False);
            claim(CT_Assert)(v278);
            const v280 = PEQ(v191, DLC_Int 0);
            if v280 then {
              v274 = DLC_Bytes "Bob wins";
               }
            else {
              const v282 = PEQ(v191, DLC_Int 1);
              if v282 then {
                v274 = DLC_Bytes "Draw";
                 }
              else {
                const v284 = PEQ(v191, DLC_Int 2);
                if v284 then {
                  v274 = DLC_Bytes "Alice wins";
                   }
                else {
                  const v286 = PEQ(v191, DLC_Int 3);
                  if v286 then {
                    v274 = DLC_Bytes "Alice quits";
                     }
                  else {
                    v274 = DLC_Bytes "Bob quits";
                     };
                   };
                 };
               };
            const v287 = interact("A")."endsWith"(v274);
             };
          only("B") {
            let v289;
            const v291 = PLE(DLC_Int 0, v191);
            const v292 = PLT(v191, DLC_Int 5);
            const v293 = IF_THEN_ELSE(v291, v292, DLC_Bool False);
            claim(CT_Assert)(v293);
            const v295 = PEQ(v191, DLC_Int 0);
            if v295 then {
              v289 = DLC_Bytes "Bob wins";
               }
            else {
              const v297 = PEQ(v191, DLC_Int 1);
              if v297 then {
                v289 = DLC_Bytes "Draw";
                 }
              else {
                const v299 = PEQ(v191, DLC_Int 2);
                if v299 then {
                  v289 = DLC_Bytes "Alice wins";
                   }
                else {
                  const v301 = PEQ(v191, DLC_Int 3);
                  if v301 then {
                    v289 = DLC_Bytes "Alice quits";
                     }
                  else {
                    v289 = DLC_Bytes "Bob quits";
                     };
                   };
                 };
               };
            const v302 = interact("B")."endsWith"(v289);
             };
          exit(); } } } } }