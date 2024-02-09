// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length

pragma solidity ^0.8.0;

import {DataTypes} from "./DataTypes.sol";
// import {ISVGGenerator} from "./interfaces/ISVGGenerator.sol";
import {SVGFrameTraits} from "./SVGFrameTraits.sol";

library SVGGenerator {
    string public constant baseSVGHead =
        '<?xml version="1.0" encoding="utf-8"?><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 100 100" style="enable-background:new 0 0 100 100;background-color:black;" xml:space="preserve">';

    string public constant baseSVGTail = "</svg>";

    string public constant color1 = "#DEE5D9";
    string public constant color2 = "#FB1467";
    string public constant color3 = "#1477FB";
    string public constant color4 = "#FFD600";
    string public constant color5 = "#31C040";

    string public constant eyesSVGs1 =
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 66 50)" width="12"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 64 48)" width="10"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 62 46)" width="6"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 66 52)" width="12"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 66 54)" width="12"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 64 56)" width="8"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(-1 0 0 1 61 54)" width="4"/>'
        '<rect fill="black" height="2" width="12" x="34" y="50"/>'
        '<rect fill="black" height="2" width="10" x="36" y="48"/>'
        '<rect fill="black" height="2" width="6" x="38" y="46"/>'
        '<rect fill="black" height="2" width="12" x="34" y="52"/>'
        '<rect fill="black" height="2" width="12" x="34" y="54"/>'
        '<rect fill="black" height="2" width="8" x="36" y="56"/>'
        '<rect fill="#DEE5D9" height="2" width="4" x="40" y="54"/>'
        '<rect fill="black" height="2" width="8" x="46" y="56"/>'
        '<rect fill="black" height="2" width="4" x="48" y="58"/>';
    string public constant eyesSVGs2 =
        '<rect fill="black" height="4" width="2" x="36" y="52"/>'
        '<rect fill="black" height="4" width="2" x="42" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 42 56)" width="2" x="42" y="56"/>'
        '<rect fill="black" height="4" width="2" x="56" y="52"/>'
        '<rect fill="black" height="4" width="2" x="62" y="52"/>'
        '<rect fill="black" height="4" transform="rotate(90 62 56)" width="2" x="62" y="56"/>'
        '<rect fill="black" height="4" width="2" x="48" y="54"/>'
        '<rect fill="black" height="2" width="2" x="50" y="56"/>';
    string public constant eyesSVGs3 =
        '<rect fill="black" height="6" width="2" x="34" y="50"/>'
        '<rect fill="black" height="2" width="6" x="36" y="56"/>'
        '<rect fill="black" height="2" width="6" x="36" y="48"/>'
        '<rect fill="black" height="6" width="2" x="42" y="50"/>'
        '<rect fill="black" height="6" width="6" x="36" y="50"/>'
        '<rect fill="#DEE5D9" height="2" width="6" x="36" y="50"/>'
        '<rect fill="#DEE5D9" height="2" width="6" x="36" y="54"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 42 50)" width="6" x="42" y="50"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 38 50)" width="6" x="38" y="50"/>'
        '<rect fill="black" height="6" width="2" x="56" y="50"/>'
        '<rect fill="black" height="2" width="6" x="58" y="56"/>'
        '<rect fill="black" height="2" width="6" x="58" y="48"/>'
        '<rect fill="black" height="6" width="2" x="64" y="50"/>'
        '<rect fill="black" height="6" width="6" x="58" y="50"/>'
        '<rect fill="#DEE5D9" height="2" width="6" x="58" y="50"/>'
        '<rect fill="#DEE5D9" height="2" width="6" x="58" y="54"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 64 50)" width="6" x="64" y="50"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(90 60 50)" width="6" x="60" y="50"/>'
        '<rect fill="black" height="2" transform="rotate(180 52 58)" width="4" x="52" y="58"/>'
        '<rect fill="black" height="2" width="2" x="46" y="54"/>'
        '<rect fill="black" height="2" width="2" x="52" y="54"/>';
    string public constant eyesSVGs4 =
        '<rect fill="black" height="4" width="2" x="34" y="50"/>'
        '<path d="M34 46H36V50H34V46Z" fill="black"/>'
        '<path d="M39 46H41V50H39V46Z" fill="black"/>'
        '<rect fill="black" height="4" width="2" x="44" y="46"/>'
        '<rect fill="black" height="2" width="8" x="36" y="54"/>'
        '<rect fill="black" height="4" width="2" x="44" y="50"/>'
        '<path d="M36 48H44V50H36V48Z" fill="black"/>'
        '<path d="M37 50H43V52H37V50Z" fill="black"/>'
        '<path d="M38 52H42V54H38V52Z" fill="black"/>'
        '<path d="M36 50H38V54H36V50Z" fill="#DEE5D9"/>'
        '<path d="M38 50H40V52H38V50Z" fill="#DEE5D9"/>'
        '<path d="M42 50H44V54H42V50Z" fill="#DEE5D9"/>'
        '<rect fill="black" height="4" width="2" x="54" y="50"/>'
        '<path d="M54 46H56V50H54V46Z" fill="black"/>'
        '<path d="M59 46H61V50H59V46Z" fill="black"/>'
        '<rect fill="black" height="4" width="2" x="64" y="46"/>'
        '<rect fill="black" height="2" width="8" x="56" y="54"/>'
        '<rect fill="black" height="4" width="2" x="64" y="50"/>'
        '<path d="M56 48H64V50H56V48Z" fill="black"/>'
        '<path d="M57 50H63V52H57V50Z" fill="black"/>'
        '<path d="M58 52H62V54H58V52Z" fill="black"/>'
        '<path d="M56 50H58V54H56V50Z" fill="#DEE5D9"/>'
        '<path d="M58 50H60V52H58V50Z" fill="#DEE5D9"/>'
        '<path d="M62 50H64V54H62V50Z" fill="#DEE5D9"/>'
        '<rect fill="black" height="2" transform="rotate(-90 48 58)" width="2" x="48" y="58"/>'
        '<rect fill="black" height="2" transform="rotate(-90 50 56)" width="2" x="50" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 50 58)" width="2" x="50" y="58"/>'
        '<rect fill="black" height="2" transform="rotate(-90 50 54)" width="2" x="50" y="54"/>';
    string public constant eyesSVGs5 =
        '<rect fill="black" height="2" width="2" x="34" y="50"/>'
        '<rect fill="black" height="2" width="24" x="38" y="48"/>'
        '<rect fill="#DEE5D9" height="4" width="28" x="36" y="50"/>'
        '<rect fill="black" height="2" width="2" x="36" y="48"/>'
        '<rect fill="black" height="2" width="12" x="38" y="46"/>'
        '<rect fill="black" height="2" transform="matrix(1 0 0 -1 34 54)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(1 0 0 -1 36 56)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(1 0 0 -1 38 58)" width="12"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(1 0 0 -1 38 56)" width="12"/>'
        '<rect fill="black" height="2" transform="rotate(-180 66 54)" width="2" x="66" y="54"/>'
        '<rect fill="black" height="2" transform="rotate(-180 64 56)" width="2" x="64" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-180 62 58)" width="12" x="62" y="58"/>'
        '<rect fill="#DEE5D9" height="2" transform="rotate(-180 62 56)" width="12" x="62" y="56"/>'
        '<rect fill="black" height="2" transform="matrix(-1 -8.74228e-08 -8.74228e-08 1 66 50)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 -8.74228e-08 -8.74228e-08 1 64 48)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 -8.74228e-08 -8.74228e-08 1 62 46)" width="12"/>'
        '<rect fill="black" height="4" width="4" x="48" y="48"/>';
    string public constant eyesSVGs6 =
        '<rect fill="black" height="44" transform="rotate(90 72 48)" width="2" x="72" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(90 36 48)" width="2" x="36" y="48"/>'
        '<rect fill="black" height="2" width="2" x="48" y="56"/>'
        '<rect fill="black" height="2" width="2" x="50" y="56"/>'
        '<rect fill="black" height="2" width="2" x="56" y="52"/>'
        '<rect fill="black" height="2" width="2" x="58" y="52"/>'
        '<rect fill="black" height="2" width="2" x="56" y="54"/>'
        '<rect fill="black" height="2" width="2" x="58" y="54"/>'
        '<rect fill="black" height="6" width="2" x="34" y="50"/>'
        '<rect fill="black" height="6" width="8" x="36" y="50"/>'
        '<rect fill="black" height="6" width="2" x="44" y="50"/>'
        '<rect fill="black" height="8" transform="rotate(90 44 56)" width="2" x="44" y="56"/>'
        '<rect fill="black" height="10" transform="rotate(90 46 48)" width="2" x="46" y="48"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 44 54)" width="2"/>';
    string public constant eyesSVGs7 =
        '<rect fill="black" height="2" transform="rotate(-90 36 58)" width="2" x="36" y="58"/>'
        '<rect fill="black" height="2" transform="rotate(-90 36 48)" width="2" x="36" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(-90 38 48)" width="2" x="38" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(-90 40 48)" width="2" x="40" y="48"/>'
        '<rect fill="black" height="2" transform="rotate(-90 40 50)" width="2" x="40" y="50"/>'
        '<rect fill="black" height="2" transform="rotate(-90 40 52)" width="2" x="40" y="52"/>'
        '<rect fill="black" height="2" transform="rotate(-90 40 54)" width="2" x="40" y="54"/>'
        '<rect fill="black" height="2" transform="rotate(-90 38 54)" width="2" x="38" y="54"/>'
        '<rect fill="black" height="2" transform="rotate(-90 34 56)" width="8" x="34" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 38 58)" width="2" x="38" y="58"/>'
        '<rect fill="black" height="4" transform="rotate(-90 40 58)" width="2" x="40" y="58"/>'
        '<rect fill="black" height="2" transform="rotate(-90 44 56)" width="4" x="44" y="56"/>'
        '<rect fill="black" height="2" transform="rotate(-90 44 52)" width="4" x="44" y="52"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 56 46)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 56 56)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 58 56)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 56)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 54)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 52)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 50)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 58 50)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 54 48)" width="8"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 58 46)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 46)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 64 48)" width="4"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 64 52)" width="4"/>';
    string public constant eyesSVGs8 =
        '<rect fill="black" height="2" width="4" x="40" y="50"/>'
        '<rect fill="black" height="2" width="4" x="40" y="56"/>'
        '<rect fill="black" height="2" width="4" x="40" y="54"/>'
        '<rect fill="black" height="2" transform="rotate(90 40 50)" width="8" x="40" y="50"/>'
        '<rect fill="black" height="2" width="4" x="58" y="50"/>'
        '<rect fill="black" height="2" width="4" x="58" y="56"/>'
        '<rect fill="black" height="2" width="4" x="58" y="54"/>'
        '<rect fill="black" height="2" transform="rotate(90 58 50)" width="8" x="58" y="50"/>'
        '<rect fill="black" height="2" width="4" x="48" y="56"/>';
    string public constant eyesSVGs9 =
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 36 46)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 36 54)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 38 54)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1.31134e-07 1 1 1.31134e-07 40 54)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(2.62268e-08 -1 -1 -7.28523e-08 42 50)" width="2"/>'
        '<rect fill="black" height="8" transform="matrix(2.62268e-08 -1 -1 -7.28523e-08 44 52)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 34 48)" width="6"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 38 46)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1.31134e-07 1 1 1.31134e-07 40 46)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 44 48)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 44 50)" width="4"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 56 46)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 56 54)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 58 54)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 54)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(2.62268e-08 -1 -1 -7.28523e-08 62 50)" width="2"/>'
        '<rect fill="black" height="8" transform="matrix(2.62268e-08 -1 -1 -7.28523e-08 64 52)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 54 48)" width="6"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 58 46)" width="2"/>'
        '<rect fill="black" height="4" transform="matrix(-1.31134e-07 1 1 1.31134e-07 60 46)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 64 48)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1.31134e-07 1 1 1.31134e-07 64 50)" width="4"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 50 56)" width="2" x="50" y="56"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 49.5 56)" width="2" x="49.5" y="56"/>'
        '<rect fill="black" height="1" transform="rotate(90 49 56)" width="2" x="49" y="56"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 38 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 37.5 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="1" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 37 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 58 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 57.5 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="1" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 57 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 44 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 43.5 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="1" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 43 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 64 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="0.5" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 63.5 50)" width="2"/>'
        '<rect fill="#DEE5D9" height="1" transform="matrix(6.77526e-07 -1 -1 -4.22543e-07 63 50)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 50 56)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 50.5 56)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 51 56)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 46 46)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 46.5 46)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 47 46)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 44 44)" width="2"/>'
        '<rect fill="black" height="0.5" transform="matrix(-2.40413e-07 1 1 5.68248e-07 44.5 44)" width="2"/>'
        '<rect fill="black" height="1" transform="matrix(-2.40413e-07 1 1 5.68248e-07 45 44)" width="2"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 54 46)" width="2" x="54" y="46"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 53.5 46)" width="2" x="53.5" y="46"/>'
        '<rect fill="black" height="1" transform="rotate(90 53 46)" width="2" x="53" y="46"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 56 44)" width="2" x="56" y="44"/>'
        '<rect fill="black" height="0.5" transform="rotate(90 55.5 44)" width="2" x="55.5" y="44"/>'
        '<rect fill="black" height="1" transform="rotate(90 55 44)" width="2" x="55" y="44"/>';
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
    string public constant mouthsSVGs1 =
        '<rect fill="black" height="6" width="2" x="38" y="62"/>'
        '<rect fill="black" height="6" width="2" x="60" y="62"/>'
        '<rect fill="black" height="20" transform="rotate(-90 40 62)" width="2" x="40" y="62"/>'
        '<rect fill="#DEE5D9" height="20" transform="rotate(-90 40 68)" width="6" x="40" y="68"/>'
        '<rect fill="black" height="20" transform="rotate(-90 40 66)" width="2" x="40" y="66"/>'
        '<rect fill="black" height="20" transform="rotate(-90 40 70)" width="2" x="40" y="70"/>';
    string public constant mouthsSVGs2 =
        '<rect fill="black" height="2" width="2" x="42" y="62"/>'
        '<rect fill="black" height="12" transform="rotate(-90 44 62)" width="2" x="44" y="62"/>'
        '<rect fill="black" height="2" width="2" x="56" y="62"/>'
        '<rect fill="black" height="2" width="2" x="58" y="64"/>'
        '<rect fill="black" height="2" width="2" x="40" y="64"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 58 64)" width="16"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 56 62)" width="12"/>'
        '<rect fill="black" height="2" width="2" x="40" y="66"/>'
        '<rect fill="black" height="2" width="2" x="58" y="66"/>'
        '<rect fill="black" height="2" width="2" x="56" y="66"/>'
        '<rect fill="black" height="2" width="14" x="42" y="66"/>'
        '<rect fill="#DEE5D9" height="2" width="16" x="42" y="64"/>';
    string public constant mouthsSVGs3 =
        '<rect fill="black" height="2" width="2" x="40" y="62"/>'
        '<rect fill="black" height="2" width="2" x="42" y="64"/>'
        '<rect fill="black" height="2" width="2" x="42" y="62"/>'
        '<rect fill="black" height="2" width="2" x="44" y="64"/>'
        '<rect fill="black" height="4" width="16" x="44" y="64"/>';
    string public constant mouthsSVGs4 =
        '<rect fill="black" height="2" width="2" x="38" y="61"/>'
        '<rect fill="black" height="4" width="4" x="42" y="63"/>'
        '<rect fill="black" height="4" width="2" x="40" y="63"/>'
        '<rect fill="#DEE5D9" height="2" width="4" x="54" y="63"/>'
        '<rect fill="black" height="4" width="2" x="46" y="63"/>'
        '<rect fill="black" height="4" width="2" x="52" y="63"/>'
        '<rect fill="black" height="4" width="2" x="58" y="63"/>'
        '<rect fill="black" height="2" width="20" x="40" y="61"/>'
        '<rect fill="black" height="4" width="4" x="54" y="63"/>'
        '<rect fill="#DEE5D9" height="2" width="4" x="54" y="61"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="44" y="61"/>'
        '<rect fill="black" height="2" width="2" x="60" y="61"/>'
        '<rect fill="black" height="4" width="4" x="48" y="63"/>'
        '<rect fill="black" height="2" width="20" x="40" y="67"/>'
        '<rect fill="black" height="2" width="2" x="36" y="63"/>'
        '<rect fill="black" height="2" width="2" x="34" y="61"/>'
        '<rect fill="black" height="2" width="2" x="34" y="63"/>'
        '<rect fill="black" height="2" width="2" x="34" y="65"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 66 61)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 66 63)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 66 65)" width="2"/>'
        '<rect fill="black" height="4" width="2" x="38" y="63"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="52" y="67"/>'
        '<rect fill="black" height="4" width="2" x="60" y="63"/>'
        '<rect fill="black" height="2" width="2" x="62" y="63"/>';
    string public constant mouthsSVGs5 =
        '<rect fill="black" height="2" width="2" x="36" y="60"/>'
        '<rect fill="black" height="2" width="2" x="62" y="60"/>'
        '<rect fill="black" height="2" width="24" x="38" y="62"/>'
        '<rect fill="black" height="2" width="20" x="40" y="64"/>';
    string public constant mouthsSVGs6 =
        '<rect fill="black" height="2" width="2" x="43" y="62"/>'
        '<rect fill="black" height="2" width="2" x="55" y="62"/>'
        '<rect fill="black" height="2" width="2" x="45" y="64"/>'
        '<rect fill="black" height="2" width="2" x="53" y="64"/>'
        '<rect fill="black" height="2" width="2" x="57" y="60"/>'
        '<rect fill="black" height="2" width="2" x="57" y="62"/>'
        '<rect fill="black" height="2" width="2" x="57" y="64"/>'
        '<rect fill="black" height="2" width="2" x="59" y="66"/>'
        '<rect fill="black" height="2" width="2" x="61" y="66"/>'
        '<rect fill="black" height="2" width="2" x="59" y="58"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 43 60)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 43 62)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 43 64)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 41 66)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 39 66)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 41 58)" width="2"/>'
        '<rect fill="black" height="2" width="6" x="47" y="64"/>'
        '<rect fill="black" height="2" width="6" x="47" y="66"/>';
    string public constant mouthsSVGs7 =
        '<rect fill="black" height="2" width="4" x="48" y="62"/>'
        '<rect fill="black" height="2" width="4" x="48" y="68"/>'
        '<rect fill="black" height="2" transform="rotate(90 48 64)" width="4" x="48" y="64"/>'
        '<rect fill="black" height="2" transform="rotate(90 54 64)" width="4" x="54" y="64"/>'
        '<rect fill="black" height="4" transform="rotate(90 52 64)" width="4" x="52" y="64"/>';
    string public constant mouthsSVGs8 =
        '<rect fill="black" height="2" width="4" x="28" y="62"/>'
        '<rect fill="black" height="2" width="2" x="32" y="62"/>'
        '<rect fill="black" height="2" width="6" x="66" y="62"/>'
        '<rect fill="black" height="4" width="2" x="34" y="62"/>'
        '<rect fill="black" height="4" width="2" x="64" y="62"/>'
        '<rect fill="black" height="2" width="2" x="36" y="66"/>'
        '<rect fill="black" height="2" width="2" x="38" y="68"/>'
        '<rect fill="black" height="2" width="2" x="40" y="66"/>'
        '<rect fill="black" height="2" width="2" x="42" y="68"/>'
        '<rect fill="black" height="2" width="2" x="44" y="66"/>'
        '<rect fill="black" height="2" width="4" x="48" y="66"/>'
        '<rect fill="black" height="2" width="2" x="46" y="68"/>'
        '<rect fill="black" height="2" width="2" x="52" y="68"/>'
        '<rect fill="black" height="2" width="2" x="54" y="66"/>'
        '<rect fill="black" height="2" width="2" x="56" y="68"/>'
        '<rect fill="black" height="2" width="2" x="58" y="66"/>'
        '<rect fill="black" height="2" width="2" x="60" y="68"/>'
        '<rect fill="black" height="2" width="2" x="62" y="66"/>';
    string public constant mouthsSVGs9 =
        '<rect fill="black" height="2" width="24" x="38" y="62"/>'
        '<rect fill="black" height="2" width="20" x="40" y="64"/>'
        '<rect fill="black" height="2" width="16" x="42" y="66"/>'
        '<rect fill="black" height="2" width="16" x="42" y="68"/>'
        '<rect fill="black" height="2" width="12" x="44" y="70"/>'
        '<rect fill="#DEE5D9" height="8" width="8" x="46" y="66"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(1 0 0 -1 48 76)" width="4"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="46" y="64"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="52" y="64"/>'
        '<rect fill="black" height="2" width="2" x="36" y="60"/>'
        '<rect fill="black" height="2" width="2" x="62" y="60"/>';
    string public constant mouthsSVGs10 =
        '<rect fill="black" height="2" width="28" x="36" y="60"/>'
        '<rect fill="black" height="2" width="24" x="38" y="62"/>'
        '<rect fill="black" height="2" width="20" x="40" y="64"/>'
        '<rect fill="#DEE5D9" height="2" width="16" x="42" y="62"/>'
        '<rect fill="black" height="2" width="16" x="42" y="66"/>';
    string public constant mouthsSVGs11 =
        '<rect fill="black" height="2" width="2" x="38" y="61"/>'
        '<rect fill="black" height="2" width="4" x="40" y="63"/>'
        '<rect fill="black" height="2" width="4" x="44" y="61"/>'
        '<rect fill="black" height="2" width="4" x="48" y="63"/>'
        '<rect fill="black" height="2" width="4" x="52" y="61"/>'
        '<rect fill="black" height="2" width="4" x="56" y="63"/>'
        '<rect fill="black" height="2" width="2" x="60" y="61"/>'
        '<rect fill="black" height="2" width="2" x="64" y="65"/>'
        '<rect fill="black" height="2" width="2" x="34" y="65"/>'
        '<rect fill="black" height="2" width="2" x="36" y="63"/>'
        '<rect fill="black" height="2" width="2" x="62" y="63"/>';
    string public constant mouthsSVGs12 =
        '<rect fill="black" height="2" width="2" x="44" y="64"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="42" y="64"/>'
        '<rect fill="black" height="2" width="2" x="58" y="64"/>'
        '<rect fill="black" height="2" width="2" x="40" y="64"/>'
        '<rect fill="black" height="2" width="2" x="54" y="64"/>'
        '<rect fill="#DEE5D9" height="2" width="2" x="56" y="64"/>'
        '<rect fill="black" height="2" width="2" x="42" y="66"/>'
        '<rect fill="black" height="2" width="2" x="36" y="60"/>'
        '<rect fill="black" height="2" width="2" x="62" y="60"/>'
        '<rect fill="black" height="2" width="2" x="56" y="66"/>'
        '<rect fill="black" height="2" width="24" x="38" y="62"/>';
    string public constant mouthsSVGs13 =
        '<rect fill="#DEE5D9" height="10" width="20" x="40" y="62"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(1 0 0 -1 40 74)" width="20"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(1 0 0 -1 42 76)" width="16"/>'
        '<rect fill="black" height="8" width="2" x="38" y="64"/>'
        '<rect fill="black" height="2" width="2" x="38" y="62"/>'
        '<rect fill="black" height="2" width="2" x="40" y="60"/>'
        '<rect fill="black" height="2" width="2" x="42" y="60"/>'
        '<rect fill="black" height="2" width="2" x="44" y="60"/>'
        '<rect fill="black" height="2" width="2" x="46" y="60"/>'
        '<rect fill="black" height="2" width="2" x="48" y="60"/>'
        '<rect fill="black" height="8" transform="matrix(-1 0 0 1 62 64)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 62 62)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 60 60)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 58 60)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 56 60)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 54 60)" width="2"/>'
        '<rect fill="black" height="2" transform="matrix(-1 0 0 1 52 60)" width="2"/>'
        '<rect fill="black" height="2" width="8" x="46" y="68"/>'
        '<rect fill="black" height="2" width="2" x="44" y="66"/>'
        '<rect fill="black" height="2" width="2" x="54" y="66"/>';
    string public constant mouthsSVGs14 =
        '<rect fill="black" height="2" width="12" x="44" y="60"/>'
        '<rect fill="black" height="2" width="8" x="46" y="66"/>'
        '<rect fill="black" height="2" width="5" x="44" y="62"/>'
        '<rect fill="black" height="2" width="2" x="42" y="62"/>'
        '<rect fill="black" height="2" width="2" x="42" y="64"/>'
        '<rect fill="black" height="2" width="2" x="40" y="64"/>'
        '<rect fill="black" height="2" width="4" x="56" y="64"/>'
        '<rect fill="black" height="2" width="2" x="38" y="62"/>'
        '<rect fill="black" height="2" width="2" x="60" y="62"/>'
        '<rect fill="black" height="2" width="2" x="56" y="62"/>'
        '<rect fill="black" height="2" width="5" x="51" y="62"/>';
    string public constant mouthsSVGs15 =
        '<rect fill="black" height="8" width="28" x="36" y="60"/>'
        '<rect fill="black" height="2" width="24" x="38" y="64"/>'
        '<rect fill="black" height="2" width="20" x="40" y="66"/>'
        '<rect fill="black" height="2" width="24" x="38" y="68"/>'
        '<rect fill="black" height="2" width="16" x="42" y="70"/>'
        '<rect fill="#DEE5D9" height="8" width="12" x="44" y="66"/>'
        '<rect fill="black" height="2" transform="matrix(1 0 0 -1 48 68)" width="4"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(1 0 0 -1 38 64)" width="24"/>'
        '<rect fill="#DEE5D9" height="2" transform="matrix(1 0 0 -1 46 76)" width="8"/>'
        '<rect fill="black" height="2" width="2" x="36" y="60"/>'
        '<rect fill="black" height="2" width="2" x="62" y="60"/>';
    string public constant mouthsSVGs16 =
        '<rect fill="#DEE5D9" height="8" width="8" x="46" y="58"/>'
        '<rect fill="#DEE5D9" height="4" width="12" x="44" y="60"/>'
        '<rect fill="#140B1C" height="2" width="8" x="46" y="56"/>'
        '<rect fill="#140B1C" height="2" width="8" x="46" y="66"/>'
        '<rect fill="#140B1C" height="2" width="2" x="54" y="58"/>'
        '<rect fill="#140B1C" height="2" width="2" x="54" y="64"/>'
        '<rect fill="#140B1C" height="2" width="2" x="52" y="60"/>'
        '<rect fill="#140B1C" height="2" width="2" x="52" y="62"/>'
        '<rect fill="#140B1C" height="2" width="2" x="56" y="60"/>'
        '<rect fill="#140B1C" height="2" width="2" x="56" y="62"/>'
        '<rect fill="#140B1C" height="2" width="2" x="44" y="58"/>'
        '<rect fill="#140B1C" height="2" width="2" x="44" y="64"/>'
        '<rect fill="#140B1C" height="2" width="2" x="42" y="60"/>'
        '<rect fill="#140B1C" height="2" width="2" x="42" y="62"/>'
        '<rect fill="#140B1C" height="2" width="2" x="46" y="60"/>'
        '<rect fill="#140B1C" height="2" width="2" x="46" y="62"/>';
    string public constant mouthsSVGs17 =
        '<rect fill="black" height="2" width="20" x="40" y="66"/>'
        '<rect fill="black" height="2" width="2" x="44" y="66"/>'
        '<rect fill="black" height="2" width="2" x="48" y="66"/>'
        '<rect fill="black" height="2" width="2" x="52" y="66"/>'
        '<rect fill="black" height="2" width="2" x="56" y="66"/>'
        '<rect fill="black" height="2" width="2" x="42" y="64"/>'
        '<rect fill="black" height="2" width="2" x="46" y="64"/>'
        '<rect fill="black" height="2" width="2" x="50" y="64"/>'
        '<rect fill="black" height="2" width="2" x="54" y="64"/>'
        '<rect fill="black" height="2" width="2" x="58" y="64"/>'
        '<rect fill="black" height="2" width="2" x="40" y="62"/>'
        '<rect fill="black" height="4" width="2" x="38" y="62"/>'
        '<rect fill="black" height="4" width="2" x="60" y="62"/>'
        '<rect fill="black" height="2" width="2" x="44" y="62"/>'
        '<rect fill="black" height="2" width="2" x="48" y="62"/>'
        '<rect fill="black" height="2" width="2" x="52" y="62"/>'
        '<rect fill="black" height="2" width="2" x="56" y="62"/>'
        '<rect fill="black" height="2" width="2" x="42" y="60"/>'
        '<rect fill="black" height="2" width="2" x="46" y="60"/>'
        '<rect fill="black" height="2" width="2" x="50" y="60"/>'
        '<rect fill="black" height="2" width="2" x="54" y="60"/>'
        '<rect fill="black" height="2" width="24" x="38" y="60"/>';
    string public constant mouthsSVGs18 =
        '<rect fill="black" height="2" width="4" x="48" y="60"/>'
        '<rect fill="black" height="2" width="4" x="48" y="66"/>'
        '<rect fill="black" height="2" width="2" x="46" y="62"/>'
        '<rect fill="black" height="2" width="2" x="44" y="64"/>'
        '<rect fill="black" height="2" width="2" x="38" y="60"/>'
        '<rect fill="black" height="2" width="2" x="42" y="62"/>'
        '<rect fill="black" height="2" width="2" x="40" y="62"/>'
        '<rect fill="black" height="2" width="2" x="52" y="62"/>'
        '<rect fill="black" height="2" width="2" x="54" y="64"/>'
        '<rect fill="black" height="2" width="2" x="60" y="60"/>'
        '<rect fill="black" height="2" width="2" x="56" y="62"/>'
        '<rect fill="black" height="2" width="2" x="58" y="62"/>';
    string public constant mouthsSVGs19 =
        '<rect fill="black" height="2" width="28" x="36" y="60"/>'
        '<rect fill="#DEE5D9" height="5" width="8" x="46" y="62"/>'
        '<rect fill="black" height="2" transform="rotate(90 46 60)" width="7" x="46" y="60"/>'
        '<rect fill="black" height="2" transform="rotate(90 56 60)" width="7" x="56" y="60"/>'
        '<rect fill="black" height="2" transform="rotate(90 51 60)" width="7" x="51" y="60"/>'
        '<rect fill="black" height="2" width="12" x="44" y="65"/>';
    string public constant baseHeadsSVGs1 =
        '<polygon class="st-base-head" points="72,48 72,64 70,64 70,66 68,66 68,68 64,68 64,70 60,70 60,72 40,72 40,70 36,70 36,68 32,68 32,66   30,66 30,64 28,64 28,48 30,48 30,46 32,46 32,44 68,44 68,46 70,46 70,48 "/>';
    string public constant baseHeadsSVGs2 =
        '<polygon class="st-base-head" points="72,44 72,68 70,68 70,70 68,70 68,72 32,72 32,70 30,70 30,68 28,68 28,44 "/>';
    string public constant baseHeadsSVGs3 =
        '<polygon class="st-base-head" points="72,46 72,64 70,64 70,66 68,66 68,68 66,68 66,70 64,70 64,72 36,72 36,70 34,70 34,68 32,68 32,66   30,66 30,64 28,64 28,46 30,46 30,44 70,44 70,46 "/>';

    //st-head
    string public constant headSVGs1 =
        '<path class="st-head" d="M66,40v-2h-2v-2h-2v-2h-2v-2h-2v-2h-2v-2h-4v-2h-2v-2H38v2h-2v2h-4v2h-2v4h2v-2h7v4h-4v2h-2v2h-7v2h48v-2H66z   M58,40H42v-2h16V40z"/>';
    string public constant headSVGs2 =
        '<path class="st-head st-head-evenodd" d="M70,34v-4h-2v-2h-2v-2h-6v2h-2v2h-2v2h-2v2h-8v-2h-2v-2h-2v-2h-2v-2h-6v2h-2v2h-2v4h-2v8h44v-8H70z M44,38H30  v-2h2v-4h2v-2h6v2h2v4h2V38z M70,38H56v-2h2v-4h2v-2h6v2h2v4h2V38z"/>';
    string public constant headSVGs3 =
        '<path class="st-head st-head-evenodd" d="M72,38v4h2v-4H72z M26,38v4h2v-4H26z"/>'
        '<path class="st-head st-head-evenodd" d="M68,36v-2h-2v-2h-4v-2h-2v-2H40v2h-2v2h-4v2h-2v2h-4v2h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v4h8v-4h2v4h2v-4  h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v-2H68z M52,40h-4v-4h4V40z"/>';
    string public constant headSVGs4 =
        '<rect class="st-head" height="2" width="44" x="28" y="40"/>'
        '<path class="st-head st-head-evenodd" d="M40,33v-3h-2v-2h-2v2h-2v2h-2v2h-2v2h-2v2h5v-2h2v2h5v-3h-4v-2H40z"/>'
        '<path class="st-head st-head-evenodd" d="M42,24v2h-4v2h4v2h5v2h-5v6h7V24H42z M47,28h-2v-2h2V28z"/>'
        '<path class="st-head st-head-evenodd" d="M70,36v-2h-2v-2h-2v-2h-2v-2h-2v2h-2v3h4v2h-6v-3h-3v6h10v-2h2v2h5v-2H70z"/>'
        '<path class="st-head st-head-evenodd" d="M58,26v-2h-7v14h2v-8h5v-2h4v-2H58z M55,28h-2v-2h2V28z"/>';
    string public constant headSVGs5 =
        '<rect class="st-head" height="2" width="4" x="30" y="24"/>'
        '<rect class="st-head" height="8" width="2" x="34" y="26"/>'
        '<polygon class="st-head" points="72,26 72,40 70,40 70,42 30,42 30,40 28,40 28,26 30,26 30,38 34,38 34,36 36,36 36,34 40,34 40,32   60,32 60,34 64,34 64,36 66,36 66,38 70,38 70,26 "/>'
        '<rect class="st-head" height="2" width="4" x="66" y="24"/>'
        '<rect class="st-head" height="8" width="2" x="64" y="26"/>';
    string public constant headSVGs6 =
        '<polygon class="st-head" points="70,38 70,42 30,42 30,38 32,38 32,36 34,36 34,34 36,34 36,32 38,32 38,39 40,39 40,30 44,30 44,39   46,39 46,32 54,32 54,39 56,39 56,30 60,30 60,39 62,39 62,32 64,32 64,34 66,34 66,36 68,36 68,38 "/>'
        '<rect class="st-head" height="4" width="2" x="38" y="26"/>'
        '<rect class="st-head" height="4" width="2" x="44" y="26"/>'
        '<rect class="st-head" height="2" width="4" x="40" y="24"/>'
        '<rect class="st-head" height="4" width="2" x="54" y="26"/>'
        '<rect class="st-head" height="4" width="2" x="60" y="26"/>'
        '<rect class="st-head" height="2" width="4" x="56" y="24"/>';
    string public constant headSVGs7 =
        '<polygon class="st-head" points="72,34 72,36 28,36 28,34 30,34 30,32 32,32 32,30 34,30 34,28 36,28 36,26 64,26 64,28 66,28 66,30   68,30 68,32 70,32 70,34 "/>'
        '<rect class="st-head" height="2" width="2" x="24" y="38"/>'
        '<rect class="st-head" height="2" width="48" x="26" y="40"/>'
        '<rect class="st-head" height="2" width="2" x="74" y="38"/>';
    string public constant headSVGs8 =
        '<polygon class="st-head" points="72,30 72,42 28,42 28,30 30,30 30,36 36,36 36,34 40,34 40,26 42,26 42,34 48,34 48,36 52,36 52,34   58,34 58,26 60,26 60,34 64,34 64,36 70,36 70,30 "/>'
        '<rect class="st-head" height="4" width="2" x="30" y="26"/>'
        '<rect class="st-head" height="4" width="2" x="68" y="26"/>'
        '<rect class="st-head" height="2" width="8" x="32" y="24"/>'
        '<rect class="st-head" height="2" width="8" x="60" y="24"/>';
    string public constant headSVGs9 =
        '<rect class="st-head" height="2" width="4" x="47" y="24"/>'
        '<polygon class="st-head st-head-evenodd" points="78,40 78,42 63,42 63,36 61,36 61,34 59,34 59,32 57,32 57,30 55,30 55,28 59,28 59,30 61,30 61,32   63,32 63,34 66,34 66,36 68,36 68,38 70,38 70,40 "/>'
        '<path class="st-head st-head-evenodd" d="M59,36v-2h-2v-2h-2v-2h-2v-2h-4v2h-2v2h-2v2h-2v-2h2v-2h2v-2h-8v2h-2v2h-2v2h-3v2h-2v2h-2v4h33v-6H59z M50,40  H38v-2h2v-2h8v2h2V40z"/>';
    string public constant headSVGs10 =
        '<path class="st-head st-head-evenodd" d="M74,34v-2h-2v-2h-2v-2h-4v-2h-4v2h-8v-2h-2v-2h-4v2h-2v2h-8v-2h-4v2h-4v2h-2v2h-2v2h-2v6h2v2h2v-6h2v-2h8v2h2v6  h20v-6h2v-2h8v2h2v6h2v-2h2v-6H74z M56,38h-2v2h-8v-2h-2v-6h2v-2h8v2h2V38z"/>';
    string public constant headSVGs11 =
        '<path clip-rule="evenodd" d="M70 28H72V30V32V38V42H28V38V32V30V28H30V30H34V32H36V34H44V32H46V30H48V28H52V30H54V32H56V34H64V32H66V30H70V28ZM62 30H64V32H56V30H58V28H62V30ZM44 32H36V30H38V28H42V30H44V32ZM32 32H30V34V36V38V40H32V38H34V36V34H32V32ZM52 32H48V34H46V36V38H48V40H52V38H54V36V34H52V32ZM70 32H68V34H66V36V38H68V40H70V38V36V34V32Z" fill="#DEE5D9" fill-rule="evenodd"/>';
    string public constant headSVGs12 =
        '<path clip-rule="evenodd" d="M32 26H34V28H32V26ZM30 30V28H32V30H30ZM28 32V30H30V32H28ZM28 40H26V32H28V40ZM34 40V42H32H30H28V40H30H32H34ZM34 38H36V36H38V34H40V32H44V42H42H36V40H34V38ZM34 32V38H32V32H34ZM34 32H36V28H34V32ZM46 42V32H48V30H52V32H54V42H50H46ZM56 42H58H64V40H66V42H70H72V40H74V32H72V30H70V28H68V26H66V28H64V32H66V38H64V36H62V34H60V32H56V42ZM66 38V40H70H72V32H70V30H68V28H66V32H68V38H66ZM52 33H48V37H52V33ZM48 38H52V40H48V38Z" fill="#DEE5D9" fill-rule="evenodd"/>';
    string public constant headSVGs13 =
        '<path class="st-head st-head-evenodd" d="M70,40v2h2v-2H70z M48,22v2h4v-2H48z"/>'
        '<path class="st-head st-head-evenodd" d="M74,30v-2h-2v-2H41v2h-7v2h-6v2h-2v2h-2v2h-2v4h4v2h4v-2h-2v-2h2v2h2v2h8v-2h-2v-2h-2v-2h2v2h2v2h2v2h16v-2h2v2  h8v-2h2v-2h4v-2h2v-6H74z M54,40h-8v-6h2v-2h4v2h2V40z"/>'
        '<rect class="st-head" height="2" width="4" x="48" y="36"/>';
    string public constant headSVGs14 =
        '<polygon class="st-head" points="66,34 66,36 34,36 34,34 36,34 36,30 38,30 38,28 40,28 40,26 44,26 44,28 46,28 46,30 54,30 54,28   56,28 56,26 60,26 60,28 62,28 62,30 64,30 64,34 "/>'
        '<polygon class="st-head" points="74,32 74,38 72,38 72,40 70,40 70,42 30,42 30,40 28,40 28,38 26,38 26,32 28,32 28,34 30,34 30,36   32,36 32,38 68,38 68,36 70,36 70,34 72,34 72,32 "/>';
    string public constant headSVGs15 =
        '<rect fill="#DEE5D9" height="2" width="36" x="32" y="48"/>'
        '<path clip-rule="evenodd" d="M40 28H60V30H62V32H66V34H68V36H72V38H74V58H26V38H28V36H32V34H34V32H38V30H40V28ZM48 30H46V32H48V30ZM30 46V54H70V46H30ZM50 30H52V32H50V30ZM48 34H46V36H48V34ZM46 38H48V40H46V38ZM48 42H46V44H48V42ZM28 42H30V44H28V42ZM52 34H50V36H52V34ZM50 38H52V40H50V38ZM52 42H50V44H52V42ZM70 42H72V44H70V42Z" fill="#DEE5D9" fill-rule="evenodd"/>';
    string public constant headSVGs16 =
        '<polygon class="st-head" points="74,24 74,26 70,26 70,29 68,29 68,32 70,32 70,34 30,34 30,32 32,32 32,29 30,29 30,26 26,26 26,24 "/>'
        '<rect class="st-head" height="2" width="44" x="28" y="36"/>'
        '<rect class="st-head" height="2" width="52" x="24" y="40"/>'
        '<rect class="st-head" height="2" width="2" x="22" y="38"/>'
        '<rect class="st-head" height="2" width="2" x="76" y="38"/>';

    function generateSVG(
        DataTypes.NodeTraits memory nodeTraits,
        DataTypes.ChipTraits memory chipTraits
    ) external pure returns (string memory) {
        string memory styleSVG = getSVGStyle(
            nodeTraits.frameColor,
            nodeTraits.chipDetailColor,
            chipTraits.headShapeColor,
            chipTraits.headDetailColor
        );

        string memory corner = nodeTraits.pgCorner ? SVGFrameTraits.pgSVG : SVGFrameTraits.alphaSVG;

        string[9] memory frameSVGs = [
            SVGFrameTraits.frameSVGs1,
            SVGFrameTraits.frameSVGs2,
            SVGFrameTraits.frameSVGs3,
            SVGFrameTraits.frameSVGs4,
            SVGFrameTraits.frameSVGs5,
            SVGFrameTraits.frameSVGs6,
            SVGFrameTraits.frameSVGs7,
            SVGFrameTraits.frameSVGs8,
            SVGFrameTraits.frameSVGs9
        ];

        string[11] memory chipDetailSVGs = [
            SVGFrameTraits.chipDetailSVGs1,
            SVGFrameTraits.chipDetailSVGs2,
            SVGFrameTraits.chipDetailSVGs3,
            SVGFrameTraits.chipDetailSVGs4,
            SVGFrameTraits.chipDetailSVGs5,
            SVGFrameTraits.chipDetailSVGs6,
            SVGFrameTraits.chipDetailSVGs7,
            SVGFrameTraits.chipDetailSVGs8,
            SVGFrameTraits.chipDetailSVGs9,
            SVGFrameTraits.chipDetailSVGs10,
            SVGFrameTraits.chipDetailSVGs11
        ];

        string memory innerSVG1 = string(
            abi.encodePacked(
                baseSVGHead,
                styleSVG,
                frameSVGs[nodeTraits.frameId % 9],
                chipDetailSVGs[nodeTraits.chipDetailId % 11],
                // chipDetailSVGs[nodeTraits.chipDetailId % chipDetailSVGs.length], chipCorner
                corner
            )
        );

        string memory innerSVG2 = getChipTraitsInnerSVG(chipTraits);

        return string(abi.encodePacked(innerSVG1, innerSVG2));
    }

    function getChipTraitsInnerSVG(DataTypes.ChipTraits memory chipTraits) internal pure returns (string memory) {
        string[3] memory baseHeadsSVGs = [baseHeadsSVGs1, baseHeadsSVGs2, baseHeadsSVGs3];

        string[18] memory eyesSVGs = [
            eyesSVGs1,
            eyesSVGs2,
            eyesSVGs3,
            eyesSVGs4,
            eyesSVGs5,
            eyesSVGs6,
            eyesSVGs7,
            eyesSVGs8,
            eyesSVGs9,
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

        string[19] memory mouthsSVGs = [
            mouthsSVGs1,
            mouthsSVGs2,
            mouthsSVGs3,
            mouthsSVGs4,
            mouthsSVGs5,
            mouthsSVGs6,
            mouthsSVGs7,
            mouthsSVGs8,
            mouthsSVGs9,
            mouthsSVGs10,
            mouthsSVGs11,
            mouthsSVGs12,
            mouthsSVGs13,
            mouthsSVGs14,
            mouthsSVGs15,
            mouthsSVGs16,
            mouthsSVGs17,
            mouthsSVGs18,
            mouthsSVGs19
        ];

        string[16] memory headSVGs = [
            headSVGs1,
            headSVGs2,
            headSVGs3,
            headSVGs4,
            headSVGs5,
            headSVGs6,
            headSVGs7,
            headSVGs8,
            headSVGs9,
            headSVGs10,
            headSVGs11,
            headSVGs12,
            headSVGs13,
            headSVGs14,
            headSVGs15,
            headSVGs16
        ];

        string memory innerSVG2 = string(
            abi.encodePacked(
                baseHeadsSVGs[chipTraits.headShapeId % 3],
                eyesSVGs[chipTraits.eyesId % 18],
                mouthsSVGs[chipTraits.mouthId % 19],
                headSVGs[chipTraits.headDetailId % 16],
                baseSVGTail
            )
        );
        return innerSVG2;
    }

    function getSVGStyle(
        uint8 frameColor,
        uint8 chipDetailColor,
        uint8 headShapeColor,
        uint8 headDetailColor
    ) internal pure returns (string memory) {
        string[5] memory colors = [color1, color2, color3, color4, color5];
        return
            string(
                abi.encodePacked(
                    '<style type="text/css">.st-frames{fill:',
                    colors[frameColor],
                    ";}.st-chip-detail{fill:",
                    colors[chipDetailColor],
                    ";}.st-base-head{fill:",
                    colors[headShapeColor],
                    ";}.st-head{fill:",
                    colors[headDetailColor],
                    ";}.st-alpha{fill:#1477FB;}.st-pg{fill:#FB1467;}.st-head-evenodd{fill-rule:evenodd;clip-rule:evenodd;}</style>"
                )
            );
    }

    function getNodeTraitsCount() external pure returns (uint8, uint8, uint8, uint8) {
        return (
            5, // uint8(_colors.length),
            9, //            uint8(_frameSVGs.length),
            7, // uint8(_cornerSVGs.length),
            11 // uint8(_chipDetailSVGs.length)
        );
    }

    function getChipTraitsCount() external pure returns (uint8, uint8, uint8, uint8) {
        return (
            18, // uint8(_eyesSVGs.length),
            19, //uint8(_mouthsSVGs.length),
            3, //uint8(_baseHeadsSVGs.length),
            16 //uint8(_headSVGs.length)
        );
    }
}
