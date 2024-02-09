// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

library Corners {
    string public constant cornerSVG1 =
        '<rect class="st2" height="6" width="6" x="6" y="6"/>'
        '<rect class="st2" height="6" width="6" x="88" y="6"/>'
        '<rect class="st2" height="6" width="6" x="6" y="88"/>'
        '<rect class="st2" height="6" width="6" x="88" y="88"/>';
    string public constant cornerSVG2 =
        '<path clip-rule="evenodd" d="M12 4V6L14 6V12H12V14H6L6 12H4V6H6L6 4H12ZM10 6H8V8H6L6 10H8V12H10V10H12V8H10V6Z" class="st2" fill-rule="evenodd"/>'
        '<path clip-rule="evenodd" d="M94 4V6L96 6V12H94V14H88L88 12H86V6H88L88 4H94ZM92 6H90V8H88L88 10H90V12H92V10H94V8H92V6Z" class="st2" fill-rule="evenodd"/>'
        '<path clip-rule="evenodd" d="M12 86V88L14 88V94H12V96H6L6 94H4V88H6L6 86H12ZM10 88H8V90H6L6 92H8V94H10V92H12V90H10V88Z" class="st2" fill-rule="evenodd"/>'
        '<path clip-rule="evenodd" d="M94 86V88L96 88V94H94V96H88L88 94H86V88H88L88 86H94ZM92 88H90V90H88L88 92H90V94H92V92H94V90H92V88Z" class="st2" fill-rule="evenodd"/>';
    string public constant cornerSVG3 =
        '<path class="st2" d="M6,12h2v2H6V12z M8,10h2v2H8V10z M10,8h2v2h-2V8z M12,6h2v2h-2V6z M14,8h2v2h-2V8z M6,4v2H4v2h4V4H6z M10,4h2v2  h-2V4z M8,14h2v2H8V14z M4,10h2v2H4V10z"/>'
        '<path class="st2" d="M94,12h-2v2h2V12z M92,10h-2v2h2V10z M90,8h-2v2h2V8z M88,6h-2v2h2V6z M86,8h-2v2h2V8z M96,6v2h-4V4h2v2H96z   M90,4h-2v2h2V4z M92,14h-2v2h2V14z M96,10h-2v2h2V10z"/>'
        '<path class="st2" d="M6,88h2v-2H6V88z M8,90h2v-2H8V90z M10,92h2v-2h-2V92z M12,94h2v-2h-2V94z M14,92h2v-2h-2V92z M8,92v4H6v-2H4  v-2H8z M10,96h2v-2h-2V96z M8,86h2v-2H8V86z M4,90h2v-2H4V90z"/>'
        '<path class="st2" d="M94,88h-2v-2h2V88z M92,90h-2v-2h2V90z M90,92h-2v-2h2V92z M88,94h-2v-2h2V94z M86,92h-2v-2h2V92z M92,92v4h2  v-2h2v-2H92z M90,96h-2v-2h2V96z M92,86h-2v-2h2V86z M96,90h-2v-2h2V90z"/>';
    string public constant cornerSVG4 =
        '<path clip-rule="evenodd" d="M12 4H4V12H12V4ZM6 6H10V8H8V10H6V6Z" class="st2" fill-rule="evenodd"/>'
        '<path clip-rule="evenodd" d="M12 88H4V96H12V88ZM8 90V92H10V94H8H6V92V90H8Z" class="st2" fill-rule="evenodd"/>'
        '<path clip-rule="evenodd" d="M88 4H96V12H88V4ZM94 6H92H90V8H92V10H94V8V6Z" class="st2" fill-rule="evenodd"/>'
        '<path clip-rule="evenodd" d="M88 88H96V96H88V88ZM92 90V92H90V94H94V90H92Z" class="st2" fill-rule="evenodd"/>';
    string public constant cornerSVG5 =
        '<path class="st2" d="M16,84v4h-4v-4H16z M8,88v4h4v-4H8z M4,92v4h4v-4H4z"/>'
        '<path class="st2" d="M88,88h-4v-4h4V88z M92,88h-4v4h4V88z M92,92v4h4v-4H92z"/>'
        '<path class="st2" d="M88,12v4h-4v-4H88z M88,8v4h4V8H88z M92,4v4h4V4H92z"/>'
        '<path class="st2" d="M12,8v4H8V8H12z M4,4v4h4V4H4z M12,12v4h4v-4H12z"/>';
    string public constant cornerSVG6 =
        '<path class="st2" d="M92,84v2h-4v-2H92z M92,88h2v-2h-2V88z M94,86h2v-2h-2V86z M84,86h2v-2h-2V86z M94,88v4h2v-4H94z M92,94h2v-2  h-2V94z M88,94v2h4v-2H88z M84,96h2v-2h-2V96z M94,96h2v-2h-2V96z M86,94h2v-2h-2V94z M84,88v4h2v-4H84z M86,88h2v-2h-2V88z"/>'
        '<path class="st2" d="M12,4v2H8V4H12z M12,8h2V6h-2V8z M14,6h2V4h-2V6z M4,6h2V4H4V6z M14,8v4h2V8H14z M12,14h2v-2h-2V14z M8,14v2h4  v-2H8z M4,16h2v-2H4V16z M14,16h2v-2h-2V16z M6,14h2v-2H6V14z M4,8v4h2V8H4z M6,8h2V6H6V8z"/>'
        '<path class="st2" d="M92,4v2h-4V4H92z M92,8h2V6h-2V8z M94,6h2V4h-2V6z M84,6h2V4h-2V6z M94,8v4h2V8H94z M92,14h2v-2h-2V14z M88,14  v2h4v-2H88z M84,16h2v-2h-2V16z M94,16h2v-2h-2V16z M86,14h2v-2h-2V14z M84,8v4h2V8H84z M86,8h2V6h-2V8z"/>'
        '<path class="st2" d="M12,84v2H8v-2H12z M12,88h2v-2h-2V88z M14,86h2v-2h-2V86z M4,86h2v-2H4V86z M14,88v4h2v-4H14z M12,94h2v-2h-2  V94z M8,94v2h4v-2H8z M4,96h2v-2H4V96z M14,96h2v-2h-2V96z M6,94h2v-2H6V94z M4,88v4h2v-4H4z M6,88h2v-2H6V88z"/>';
    string public constant cornerSVG7 =
        '<path class="st2" d="M94,88h-2v-2h2V88z M92,88h-4v4h4V88z M94,94v-2h-2v2H94z M86,86v2h2v-2H86z M86,94h2v-2h-2V94z"/>'
        '<path class="st2" d="M12,94v-2h2v2H12z M12,88H8v4h4V88z M6,86v2h2v-2H6z M14,86h-2v2h2V86z M6,94h2v-2H6V94z"/>'
        '<path class="st2" d="M92,14v-2h2v2H92z M86,14h2v-2h-2V14z M94,6h-2v2h2V6z M92,8h-4v4h4V8z M86,6v2h2V6H86z"/>'
        '<path class="st2" d="M12,14v-2h2v2H12z M12,8H8v4h4V8z M6,6v2h2V6H6z M6,14h2v-2H6V14z M14,6h-2v2h2V6z"/>';

    string public constant alphaSVG =
        '<path class="st-alpha" d="M6,6V4h4v2H6z M10,6v2H6V6H4v6h2v-2h4v2h2V6H10z"/>'
        '<path class="st-alpha" d="M94,4v2h-4V4H94z M94,6v2h-4V6h-2v6h2v-2h4v2h2V6H94z"/>'
        '<path class="st-alpha" d="M10,88v2H6v-2H10z M10,90v2H6v-2H4v6h2v-2h4v2h2v-6H10z"/>'
        '<path class="st-alpha" d="M94,88v2h-4v-2H94z M94,90v2h-4v-2h-2v6h2v-2h4v2h2v-6H94z"/>';

    string public constant pgSVG =
        '<polygon class="st-pg" points="14,6 14,10 12,10 12,12 10,12 10,14 8,14 8,12 6,12 6,10 4,10 4,6 6,6 6,4 8,4 8,6 10,6 10,4 12,4   12,6 "/>'
        '<polygon class="st-pg" points="96,6 96,10 94,10 94,12 92,12 92,14 90,14 90,12 88,12 88,10 86,10 86,6 88,6 88,4 90,4 90,6 92,6   92,4 94,4 94,6 "/>'
        '<polygon class="st-pg" points="14,88 14,92 12,92 12,94 10,94 10,96 8,96 8,94 6,94 6,92 4,92 4,88 6,88 6,86 8,86 8,88 10,88 10,86   12,86 12,88 "/>'
        '<polygon class="st-pg" points="96,88 96,92 94,92 94,94 92,94 92,96 90,96 90,94 88,94 88,92 86,92 86,88 88,88 88,86 90,86 90,88   92,88 92,86 94,86 94,88 "/>';
}
