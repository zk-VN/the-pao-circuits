//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.11;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [20874166774567846249142019994695130409031048180657922654312421881836984633275,
             13774550616877834422483767879288560518675781299019066969630881892480927380186],
            [13232247056846671659229066227954960389882623788681967944408122977031485763322,
             21092584069359746820145307226288988012135877726704427781091217015611040620158]
        );
        vk.IC = new Pairing.G1Point[](31);
        
        vk.IC[0] = Pairing.G1Point( 
            15498526668381704486149173031836031945742834643325313827243672806251595792765,
            11646474446578899152564520393577600600350625551265204376120185038771177860736
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            17692295012978539812057624945204877626941305400223603439669178725168378920980,
            12804132944403958043588476394604758429647721386351074715731268999724843048012
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            7826989056779313702151809098964172586760469036566513359582217699069884409583,
            1376369301216622907590199143721910376772726794883475827904107572933247615796
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            20179093122948106316513051646808897559935275338374607819697936242179501293603,
            16038491786570387348074289712035624637012084012735356143803530378594586704634
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            7361260567956574206323553317281837756350602150420769356721998675167025864533,
            1572584166920321160755760147972024797766461183401291163185879000317117198675
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            2445792664894395108613415365806680202141759631984203348698437230416440599018,
            3546389040166706097213494791989376547080323218433008003530465125397488987496
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            9041925906250914357111139520495547102298112558260486271765462669277484839330,
            15983785075892266061323833947076865932285312867568338195132139283672400760017
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            12833815726579244353578189493741851802434224044555175091769986319501448011034,
            8273168982725115549257269704225630004112081746845761722836470611861853859923
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            19869580225059398547591212066311191451619104893518495581557381257574812426333,
            1926296867109255475220952658146800898845272952416578250963149244269052755249
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            4245197762848487987422970668962666561842095959775117962134800883453425042675,
            12350429053602387258299339194160134866743154489620514866516407983438253714366
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            12302545488806474037074667635798440724234148009943638079542275050515263702704,
            12413082608221254412952903633406162378344730946500556883574404907212830306525
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            2443455975966767131363436669890487423174678597307090080211945851852444897215,
            1634424297985459337933003809882797180138721800080840991753543543709709404303
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            8791427445326091182986632841081046517684409638981820771400369963622809988184,
            7001805818989479752146434588387009976363696823830042416395149382293330609448
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            7218037418526988387326256188117738523961360686554859044477385529458312460751,
            18198434416792654234678783683876521848765308345474780656629030114848065944823
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            6032007833863379059687911648913419468653665296073446831288292791799902594700,
            1059238400219894517579367832421960802273045361204698936811452923084501429828
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            18937246838915752953965143220418823028317225009808770685436502332477512411791,
            1509256469870465554108187782758199677680226022537395856222772414311168666559
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            10238713151817941701675596641355644901831858237488564186502414516036626540802,
            5625658046504598075901993688155279421354484361032351877166660137165648049557
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            13784305431902000769061629673070326807795875352880835173554262671680250294846,
            11781482733583924309105436255977692188778802204139951259183148154281359544720
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            11835978418667778324668901812986427462153197610377432665327648618640299337093,
            13686304547533468371867537183729610247750492922082331625427412805095209246130
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            14728431734859440698610455305794806317042579264948030523199836358769046275184,
            11454323711926139306021877281537631043024555160436283579507153312096929447058
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            21690743754095004671567375418157291695945319299074610292219568362207844582555,
            1784962484891751208020712068871318584803864832744000432216027105665920066151
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            17166533876832539776564125968583144649145334906403699461277834122997786888915,
            5938798526041487323153528522519924164464581298464767738839102076890271672865
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            2013254735886245662878799536178513027639018066275812026470459133276216137766,
            9992442668567974732392917063797716777262454131725760893745410898930464405235
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            9093600533082580272240308819951121354509243130318789232714879829475853731870,
            21084454140980511165925692128101923109393737904225180048570293382191254209774
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            11520110560146403470181364257409303130706033992333350144775154509316127952443,
            2300509496035513713078633005929273643184135010878291446594604549095697179869
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            35130768348867910844688629756472823639383221875113974277409880748142744916,
            18850533211519290366307867704804996248145499908200880351360021376463603111474
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            5423212934318635923126311261938776600088147582986305860651490140713269190226,
            11627820440666335812812152368610061675281787720738682921683789711583530789595
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            15194332627079852924995789867493059224448373159888391212500757554790842362352,
            9025966247161787658890396533321984739669373962495993112436602651247771960263
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            5226814480339965087780254007627839192687789608037411818182322398288563151266,
            15429409547450083689160305612716253004070630297958673431809608358522426369587
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            8713128764534117189142425346849546466946287367817283192170042849887347133029,
            841492547613674806419167611199357695802075524284850388760339679088118935388
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            15858350358188690128257700227027668358669749757259796902907299303885375598258,
            18694237750672000219119764761046963255333530325166100292473319867267587520114
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[30] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
