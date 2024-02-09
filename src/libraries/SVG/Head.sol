// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

library Head {
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
}
