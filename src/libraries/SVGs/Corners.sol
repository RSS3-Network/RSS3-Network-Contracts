// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

library Corners {
    // class: r: corner
    string public constant cornerSVG1 = '<path d="M6 6h6v6H6zm82 0h6v6h-6zM6 88h6v6H6zm82 0h6v6h-6z" class="r"/>';
    string public constant cornerSVG2 =
        '<path clip-rule="evenodd" d="M12 4v2h2v6h-2v2H6v-2H4V6h2V4zm-2 2H8v2H6v2h2v2h2v-2h2V8h-2zm84-2v2h2v6h-2v2h-6v-2h-2V6h2V4zm-2 2h-2v2h-2v2h2v2h2v-2h2V8h-2zM12 86v2h2v6h-2v2H6v-2H4v-6h2v-2zm-2 2H8v2H6v2h2v2h2v-2h2v-2h-2zm84-2v2h2v6h-2v2h-6v-2h-2v-6h2v-2zm-2 2h-2v2h-2v2h2v2h2v-2h2v-2h-2z" class="r" fill-rule="evenodd"/>';
    string public constant cornerSVG3 =
        '<path class="r" d="M6 12h2v2H6zm2-2h2v2H8zm2-2h2v2h-2zm2-2h2v2h-2zm2 2h2v2h-2zM6 4v2H4v2h4V4zm4 0h2v2h-2zM8 14h2v2H8zm-4-4h2v2H4zm90 2h-2v2h2zm-2-2h-2v2h2zm-2-2h-2v2h2zm-2-2h-2v2h2zm-2 2h-2v2h2zm10-2v2h-4V4h2v2zm-6-2h-2v2h2zm2 10h-2v2h2zm4-4h-2v2h2zM6 88h2v-2H6zm2 2h2v-2H8zm2 2h2v-2h-2zm2 2h2v-2h-2zm2-2h2v-2h-2zm-6 0v4H6v-2H4v-2zm2 4h2v-2h-2zM8 86h2v-2H8zm-4 4h2v-2H4zm90-2h-2v-2h2zm-2 2h-2v-2h2zm-2 2h-2v-2h2zm-2 2h-2v-2h2zm-2-2h-2v-2h2zm6 0v4h2v-2h2v-2zm-2 4h-2v-2h2zm2-10h-2v-2h2zm4 4h-2v-2h2z"/>';
    string public constant cornerSVG4 =
        '<path clip-rule="evenodd" d="M12 4H4v8h8zM6 6h4v2H8v2H6zm6 82H4v8h8zm-4 2v2h2v2H6v-4zM88 4h8v8h-8zm6 2h-4v2h2v2h2zm-6 82h8v8h-8zm4 2v2h-2v2h4v-4z" class="r" fill-rule="evenodd"/>';
    string public constant cornerSVG5 =
        '<path class="r" d="M16 84v4h-4v-4zm-8 4v4h4v-4zm-4 4v4h4v-4zm84-4h-4v-4h4zm4 0h-4v4h4zm0 4v4h4v-4zm-4-80v4h-4v-4zm0-4v4h4V8zm4-4v4h4V4zM12 8v4H8V8zM4 4v4h4V4zm8 8v4h4v-4z"/>';
    string public constant cornerSVG6 =
        '<path class="r" d="M92 84v2h-4v-2zm0 4h2v-2h-2zm2-2h2v-2h-2zm-10 0h2v-2h-2zm10 2v4h2v-4zm-2 6h2v-2h-2zm-4 0v2h4v-2zm-4 2h2v-2h-2zm10 0h2v-2h-2zm-8-2h2v-2h-2zm-2-6v4h2v-4zm2 0h2v-2h-2zM12 4v2H8V4zm0 4h2V6h-2zm2-2h2V4h-2zM4 6h2V4H4zm10 2v4h2V8zm-2 6h2v-2h-2zm-4 0v2h4v-2zm-4 2h2v-2H4zm10 0h2v-2h-2zm-8-2h2v-2H6zM4 8v4h2V8zm2 0h2V6H6zm86-4v2h-4V4zm0 4h2V6h-2zm2-2h2V4h-2zM84 6h2V4h-2zm10 2v4h2V8zm-2 6h2v-2h-2zm-4 0v2h4v-2zm-4 2h2v-2h-2zm10 0h2v-2h-2zm-8-2h2v-2h-2zm-2-6v4h2V8zm2 0h2V6h-2zM12 84v2H8v-2zm0 4h2v-2h-2zm2-2h2v-2h-2zM4 86h2v-2H4zm10 2v4h2v-4zm-2 6h2v-2h-2zm-4 0v2h4v-2zm-4 2h2v-2H4zm10 0h2v-2h-2zm-8-2h2v-2H6zm-2-6v4h2v-4zm2 0h2v-2H6z"/>';
    string public constant cornerSVG7 =
        '<path class="r" d="M94 88h-2v-2h2zm-2 0h-4v4h4zm2 6v-2h-2v2zm-8-8v2h2v-2zm0 8h2v-2h-2zm-74 0v-2h2v2zm0-6H8v4h4zm-6-2v2h2v-2zm8 0h-2v2h2zm-8 8h2v-2H6zm86-80v-2h2v2zm-6 0h2v-2h-2zm8-8h-2v2h2zm-2 2h-4v4h4zm-6-2v2h2V6zm-74 8v-2h2v2zm0-6H8v4h4zM6 6v2h2V6zm0 8h2v-2H6zm8-8h-2v2h2z"/>';

    string public constant alphaSVG =
        '<path class="alpha" d="M6 6V4h4v2zm4 0v2H6V6H4v6h2v-2h4v2h2V6zm84-2v2h-4V4zm0 2v2h-4V6h-2v6h2v-2h4v2h2V6zM10 88v2H6v-2zm0 2v2H6v-2H4v6h2v-2h4v2h2v-6zm84-2v2h-4v-2zm0 2v2h-4v-2h-2v6h2v-2h4v2h2v-6z"/>';

    string public constant pgSVG =
        '<path class="pg" d="M14 6v4h-2v2h-2v2H8v-2H6v-2H4V6h2V4h2v2h2V4h2v2zm82 0v4h-2v2h-2v2h-2v-2h-2v-2h-2V6h2V4h2v2h2V4h2v2zM14 88v4h-2v2h-2v2H8v-2H6v-2H4v-4h2v-2h2v2h2v-2h2v2zm82 0v4h-2v2h-2v2h-2v-2h-2v-2h-2v-4h2v-2h2v2h2v-2h2v2z"/>';
}
