// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;
import {IErrors} from "../../interfaces/IErrors.sol";

library Eyes10to18 {
    string public constant eyesSVGs10 =
        '<rect fill="black" height="2" width="4" x="48" y="56"/>'
        '<rect fill="black" height="6" width="2" x="36" y="50"/>'
        '<rect fill="black" height="2" width="6" x="38" y="56"/>'
        '<rect fill="black" height="2" width="6" x="38" y="48"/>'
        '<rect fill="black" height="6" width="2" x="44" y="50"/>'
        '<rect fill="black" height="6" width="6" x="38" y="50"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="38" y="50"/>'
        '<rect fill="#DEE5D9" height="4" width="4" x="40" y="52"/>'
        '<rect fill="black" height="6" width="2" x="54" y="50"/>'
        '<rect fill="black" height="2" width="6" x="56" y="56"/>'
        '<rect fill="black" height="2" width="6" x="56" y="48"/>'
        '<rect fill="black" height="6" width="2" x="62" y="50"/>'
        '<rect fill="black" height="6" width="6" x="56" y="50"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="56" y="50"/>'
        '<rect fill="#DEE5D9" height="4" width="4" x="58" y="52"/>';
    string public constant eyesSVGs11 =
        '<rect fill="black" height="4" width="2" x="36" y="52"/>'
        '<rect fill="black" height="4" width="2" x="42" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 56)" width="2" x="42" y="56"/>'
        '<rect fill="black" height="12" transform="rotate(90 46 50)" width="2" x="46" y="50"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 52)" width="4" x="42" y="52"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 40 52)" width="2" x="40" y="52"/>'
        '<rect fill="black" height="4" width="2" x="56" y="52"/>'
        '<rect fill="black" height="4" width="2" x="62" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 62 56)" width="2" x="62" y="56"/>'
        '<rect fill="black" height="12" transform="rotate(90 66 50)" width="2" x="66" y="50"/>'
        '<rect fill="black" height="4" transform="rotate(90 62 52)" width="4" x="62" y="52"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 60 52)" width="2" x="60" y="52"/>'
        '<rect fill="black" height="4" width="2" x="48" y="54"/>'
        '<rect fill="black" height="2" width="2" x="50" y="56"/>';
    string public constant eyesSVGs12 =
        '<rect fill="black" height="44" transform="rotate(90 72 48)" width="2" x="72" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(90 36 48)" width="2" x="36" y="48"/>'
        '<rect fill="black" height="2" width="2" x="48" y="56"/>'
        '<rect fill="black" height="2" width="2" x="50" y="56"/>'
        '<rect fill="black" height="8" width="6" x="30" y="50"/>'
        '<rect fill="black" height="6" width="2" x="28" y="50"/>'
        '<rect fill="black" height="6" width="8" x="36" y="50"/>'
        '<rect fill="black" height="6" width="2" x="44" y="50"/>'
        '<rect fill="black" height="4" width="2" x="46" y="50"/>'
        '<rect fill="black" height="4" width="6" x="48" y="50"/>'
        '<rect fill="#DEE5D9" height="4" width="4" x="38" y="52"/>'
        '<rect fill="black" height="8" transform="rotate(90 44 56)" width="2" x="44" y="56"/>'
        '<rect fill="black" height="10" transform="rotate(90 46 48)" width="2" x="46" y="48"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 44 54)" width="2"/>'
        '<rect fill="black" height="8" transform="matrix(-1 0 0 1 70 50)" width="6"/>'
        '<rect fill="black" height="6" transform="matrix(-1 0 0 1 72 50)" width="2"/>'
        '<rect fill="black" height="6" transform="matrix(-1 0 0 1 64 50)" width="8"/>'
        '<rect fill="black" height="6" transform="matrix(-1 0 0 1 56 50)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1 0 0 1 54 50)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1 0 0 1 52 50)" width="6"/>'
        '<rect fill="#DEE5D9" height="4" transform="matrix(-1 0 0 1 62 52)" width="4"/>'
        '<rect fill="black" height="8" transform="matrix(4.37114e-08 1 1 -4.37114e-08 56 56)" width="2"/>'
        '<rect fill="black" height="10" transform="matrix(4.37114e-08 1 1 -4.37114e-08 54 48)" width="2"/>'
        '<rect fill="black" height="2" width="2" x="56" y="54"/>';
    string public constant eyesSVGs13 =
        '<rect fill="black" height="2" width="2" x="36" y="50"/>'
        '<rect fill="black" height="2" width="2" x="38" y="52"/>'
        '<rect fill="black" height="2" width="2" x="40" y="54"/>'
        '<rect fill="black" height="2" width="2" x="36" y="54"/>'
        '<rect fill="black" height="2" width="2" x="40" y="50"/>'
        '<rect fill="black" height="2" width="2" x="58" y="50"/>'
        '<rect fill="black" height="2" width="2" x="60" y="52"/>'
        '<rect fill="black" height="2" width="2" x="62" y="54"/>'
        '<rect fill="black" height="2" width="2" x="58" y="54"/>'
        '<rect fill="black" height="2" width="2" x="62" y="50"/>'
        '<rect fill="black" height="2" width="4" x="48" y="56"/>'
        '<rect fill="black" height="2" width="2" x="46" y="54"/>'
        '<rect fill="black" height="2" width="2" x="52" y="54"/>';
    string public constant eyesSVGs14 =
        '<rect fill="black" height="8" transform="rotate(90 54 48)" width="2" x="54" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(90 66 48)" width="2" x="66" y="48"/>'
        '<rect fill="black" height="6" transform="rotate(90 72 46)" width="2" x="72" y="46"/>'
        '<rect fill="black" height="6" transform="rotate(90 34 46)" width="2" x="34" y="46"/>'
        '<rect fill="black" height="2" transform="rotate(90 36 48)" width="2" x="36" y="48"/>'
        '<rect fill="black" height="2" width="2" x="48" y="56"/>'
        '<rect fill="black" height="2" width="2" x="50" y="56"/>'
        '<rect fill="black" height="12" transform="rotate(90 66 48)" width="2" x="66" y="48"/>'
        '<rect fill="black" height="6" width="2" x="54" y="50"/>'
        '<rect fill="black" height="6" width="2" x="64" y="50"/>'
        '<rect fill="black" height="8" transform="rotate(90 64 56)" width="2" x="64" y="56"/>'
        '<rect fill="black" height="4" width="6" x="56" y="52"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 64 54)" width="2"/>'
        '<rect fill="black" height="6" width="2" x="34" y="50"/>'
        '<rect fill="black" height="4" width="6" x="36" y="52"/>'
        '<rect fill="black" height="6" width="2" x="44" y="50"/>'
        '<rect fill="black" height="8" transform="rotate(90 44 56)" width="2" x="44" y="56"/>'
        '<rect fill="black" height="10" transform="rotate(90 46 48)" width="2" x="46" y="48"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 44 54)" width="2"/>'
        '<rect fill="#DEE5D9" height="4" transform="matrix(-1 0 0 1 44 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="4" transform="matrix(-1 0 0 1 64 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(-1 0 0 1 42 50)" width="6"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(-1 0 0 1 62 50)" width="6"/>';
    string public constant eyesSVGs15 =
        '<rect fill="black" height="4" width="2" x="35" y="52"/>'
        '<rect fill="black" height="4" width="2" x="43" y="52"/>'
        '<rect fill="black" height="6" transform="rotate(90 43 56)" width="2" x="43" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(90 41 54)" width="2" x="41" y="54"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 39 54)" width="2" x="39" y="54"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 43 54)" width="2" x="43" y="54"/>'
        '<rect fill="black" height="6" transform="rotate(90 43 52)" width="2" x="43" y="52"/>'
        '<rect fill="black" height="2" width="2" x="45" y="48"/>'
        '<rect fill="black" height="2" width="2" x="53" y="48"/>'
        '<rect fill="black" height="6" transform="rotate(90 53 50)" width="2" x="53" y="50"/>'
        '<rect fill="black" height="2" transform="rotate(90 51 48)" width="2" x="51" y="48"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 49 48)" width="2" x="49" y="48"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 53 48)" width="2" x="53" y="48"/>'
        '<rect fill="black" height="6" transform="rotate(90 53 46)" width="2" x="53" y="46"/>'
        '<rect fill="black" height="4" width="2" x="55" y="52"/>'
        '<rect fill="black" height="4" width="2" x="63" y="52"/>'
        '<rect fill="black" height="6" transform="rotate(90 63 56)" width="2" x="63" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(90 61 54)" width="2" x="61" y="54"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 59 54)" width="2" x="59" y="54"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 63 54)" width="2" x="63" y="54"/>'
        '<rect fill="black" height="6" transform="rotate(90 63 52)" width="2" x="63" y="52"/>'
        '<rect fill="black" height="2" width="2" x="47" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(90 53 56)" width="2" x="53" y="56"/>';
    string public constant eyesSVGs16 =
        '<rect fill="black" height="2" width="16" x="26" y="48"/>'
        '<rect fill="black" height="2" width="18" x="26" y="50"/>'
        '<rect fill="black" height="2" width="16" x="28" y="52"/>'
        '<rect fill="black" height="2" width="14" x="30" y="54"/>'
        '<rect fill="black" height="2" width="12" x="32" y="56"/>'
        '<rect fill="#DEE5D9" height="4" width="2" x="38" y="52"/>'
        '<rect fill="black" height="2" width="2" x="46" y="56"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 74 48)" width="16"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 74 50)" width="18"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 72 52)" width="16"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 70 54)" width="14"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 68 56)" width="12"/>'
        '<rect fill="#DEE5D9" height="4" transform="matrix(-1 0 0 1 62 52)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 54 56)" width="2"/>';
    string public constant eyesSVGs17 =
        '<rect fill="black" height="4" width="2" x="36" y="52"/>'
        '<rect fill="black" height="4" width="2" x="42" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 56)" width="2" x="42" y="56"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 50)" width="2" x="42" y="50"/>'
        '<rect fill="black" height="4" width="2" x="56" y="52"/>'
        '<rect fill="black" height="4" width="2" x="62" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 62 56)" width="2" x="62" y="56"/>'
        '<rect fill="black" height="4" transform="rotate(90 62 50)" width="2" x="62" y="50"/>'
        '<rect fill="black" height="4" width="2" x="48" y="54"/>'
        '<rect fill="black" height="2" width="2" x="50" y="56"/>';
    string public constant eyesSVGs18 =
        '<rect fill="black" height="2" transform="rotate(-90 36 56)" width="2" x="36" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 36 48)" width="2" x="36" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(-90 38 48)" width="2" x="38" y="48"/>'
        '<rect fill="black" height="4" transform="rotate(-90 40 48)" width="2" x="40" y="48"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 52)" width="2" x="42" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 50)" width="2" x="42" y="50"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 48)" width="2" x="42" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(-90 34 56)" width="8" x="34" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 38 56)" width="2" x="38" y="56"/>'
        '<rect fill="black" height="4" transform="rotate(-90 40 56)" width="2" x="40" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 44 56)" width="4" x="44" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 44 52)" width="4" x="44" y="52"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 54 51)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 56 51)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1.31134e-07 1 1 1.31134e-07 58 51)" width="2"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 52 54)" width="2" x="52" y="54"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 51.5 54)" width="2" x="51.5" y="54"/>'
        '<rect fill="black" height="1" transform="rotate(90 51 54)" width="2" x="51" y="54"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 50 56)" width="2" x="50" y="56"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 49.5 56)" width="2" x="49.5" y="56"/>'
        '<rect fill="black" height="1" transform="rotate(90 49 56)" width="2" x="49" y="56"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="rotate(90 40 50)" width="2" x="40" y="50"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="rotate(90 39.5 50)" width="2" x="39.5" y="50"/>'
        '<rect fill="#DEE5D9" height="1" transform="rotate(90 39 50)" width="2" x="39" y="50"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="rotate(90 38 48)" width="6" x="38" y="48"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="rotate(90 37.5 48)" width="6" x="37.5" y="48"/>'
        '<rect fill="#DEE5D9" height="1" transform="rotate(90 37 48)" width="6" x="37" y="48"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="rotate(90 44 48)" width="6" x="44" y="48"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="rotate(90 43.5 48)" width="6" x="43.5" y="48"/>'
        '<rect fill="#DEE5D9" height="1" transform="rotate(90 43 48)" width="6" x="43" y="48"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 62 53)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 62.5 53)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 63 53)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 64 55)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 64.5 55)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 65 55)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 50 56)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 50.5 56)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 51 56)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 64 47)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 64.5 47)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 65 47)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 62 49)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 62.5 49)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 63 49)" width="2"/>';

    function getEyes(uint256 id) public pure returns (string memory) {
        string[9] memory eyesSVGs = [
            eyesSVGs10,
            eyesSVGs11,
            eyesSVGs12,
            eyesSVGs13,
            eyesSVGs14,
            eyesSVGs15,
            eyesSVGs16,
            eyesSVGs17,
            eyesSVGs18
        ];

        if (id < 18 && id >= 9) {
            return eyesSVGs[id - 9];
        } else {
            revert IErrors.InvalidTraitId(id);
        }
    }
}
