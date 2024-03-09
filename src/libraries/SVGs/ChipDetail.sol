// SPDX-License-Identifier: MIT
// solhint-disable max-line-length,quotes
pragma solidity 0.8.20;

library ChipDetail {
    // class: c
    function getChipDetail(uint256 id) external pure returns (string memory, string memory) {
        uint256 idx = id % 11;
        string[11] memory chipDetailSVGs = [
            '<path d="M18 82h2V18h-2zm0-62h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm0 4h-2v-2h2zm66 2v-2H20v2zm-62 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2zm4 0v2h-2v-2z"/>'
            '<path d="M82 18h-2v64h2zm0 62h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2zm0-4h2v2h-2z"/>'
            '<path d="M82 18v2H18v-2zm-62 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm4 0v-2h-2v2zm-6 2h2v2h-2zm2 2h2v2h-2zm2 2h2v2h-2zm-4 56h2v-2h-2zm2-2h2v-2h-2zm2-2h2v-2h-2zM26 20h-2v2h2zm-2 2h-2v2h2zm-2 2h-2v2h2zm4 56h-2v-2h2zm-2-2h-2v-2h2zm-2-2h-2v-2h2z"/>',
            '<path d="M14 26v2h2v-2zm2-2v2h2v-2zm-2-2v2h2v-2zm2 6v2h2v-2zm2-2v2h2v-2zm0-4v2h2v-2zm2-2v2h2v-2zm-6 18v2h2v-2zm2 2v2h2v-2zm2-2v2h2v-2zm-2 0v-2h2v2zm2-2v-2h2v2zm-2-2v-2h2v2zm2-2v-2h2v2zm-2 18v-2h2v2zm2-2v-2h2v2zm-2-2v-2h2v2zm2-2v-2h2v2zm-4 30v-2h2v2zm2 2v-2h2v2zm2 2v-2h2v2zm2 2v-2h2v2zm-6-2v-2h2v2zm2 2v-2h2v2zm0-8v-2h2v2zm2 2v-2h2v2zm-4-12v-2h2v2zm2-2v-2h2v2zm2 2v-2h2v2zm-2 0v2h2v-2zm2 2v2h2v-2zm-2 2v2h2v-2zm2 2v2h2v-2zm-2-18v2h2v-2zm2 2v2h2v-2zm-2 2v2h2v-2zm2 2v2h2v-2zm-2-36v2h2v-2zm2 0v-6h2v6zm-4 0v-6h2v6z"/>'
            '<path d="M20 20h-6v-2h6zm0-4h-6v-2h6zm-4 64v6h-2v-6zm4 0v6h-2v-6z"/>'
            '<path d="M14 80h6v2h-6zm0 4h6v2h-6zm72-10v-2h-2v2zm-2 2v-2h-2v2zm2 2v-2h-2v2zm-2-6v-2h-2v2zm-2 2v-2h-2v2zm0 4v-2h-2v2zm-2 2v-2h-2v2zm6-18v-2h-2v2zm-2-2v-2h-2v2zm-2 2v-2h-2v2zm2 0v2h-2v-2zm-2 2v2h-2v-2zm2 2v2h-2v-2zm-2 2v2h-2v-2zm2-18v2h-2v-2zm-2 2v2h-2v-2zm2 2v2h-2v-2zm-2 2v2h-2v-2zm4-30v2h-2v-2zm-2-2v2h-2v-2zm-2-2v2h-2v-2zm-2-2v2h-2v-2zm6 2v2h-2v-2zm-2-2v2h-2v-2zm0 8v2h-2v-2zm-2-2v2h-2v-2zm4 12v2h-2v-2zm-2 2v2h-2v-2zm-2-2v2h-2v-2zm2 0v-2h-2v2zm-2-2v-2h-2v2zm2-2v-2h-2v2zm-2-2v-2h-2v2zm2 18v-2h-2v2zm-2-2v-2h-2v2zm2-2v-2h-2v2zm-2-2v-2h-2v2zm2 36v-2h-2v2zm-2 0v6h-2v-6zm4 0v6h-2v-6z"/>'
            '<path d="M80 80h6v2h-6zm0 4h6v2h-6zm4-64v-6h2v6zm-4 0v-6h2v6z"/>'
            '<path d="M86 20h-6v-2h6zm0-4h-6v-2h6zM26 86h2v-2h-2zm-2-2h2v-2h-2zm-2 2h2v-2h-2zm6-2h2v-2h-2zm-2-2h2v-2h-2zm-4 0h2v-2h-2zm16 4h2v-2h-2zm2-2h2v-2h-2zm-2-2h2v-2h-2zm0 2h-2v-2h2zm-2-2h-2v-2h2zm-2 2h-2v-2h2zm-2-2h-2v-2h2zm18 2h-2v-2h2zm-2-2h-2v-2h2zm-2 2h-2v-2h2zm-2-2h-2v-2h2zm30 4h-2v-2h2zm2-2h-2v-2h2zm2-2h-2v-2h2zm0 4h-2v-2h2zm2-2h-2v-2h2zm-8 0h-2v-2h2zm2-2h-2v-2h2zm-12 4h-2v-2h2zm-2-2h-2v-2h2zm2-2h-2v-2h2zm0 2h2v-2h-2zm2-2h2v-2h-2zm2 2h2v-2h-2zm2-2h2v-2h-2zm-18 2h2v-2h-2zm2-2h2v-2h-2zm2 2h2v-2h-2zm2-2h2v-2h-2zm-36 2h2v-2h-2zm0-2h-6v-2h6zm0 4h-6v-2h6z"/>'
            '<path d="M20 80v6h-2v-6zm-4 0v6h-2v-6zm64 4h6v2h-6zm0-4h6v2h-6z"/>'
            '<path d="M80 86v-6h2v6zm4 0v-6h2v6zM74 14h-2v2h2zm2 2h-2v2h2zm2-2h-2v2h2zm-6 2h-2v2h2zm2 2h-2v2h2zm4 0h-2v2h2zm-16-4h-2v2h2zm-2 2h-2v2h2zm2 2h-2v2h2zm0-2h2v2h-2zm2 2h2v2h-2zm2-2h2v2h-2zm2 2h2v2h-2zm-18-2h2v2h-2zm2 2h2v2h-2zm2-2h2v2h-2zm2 2h2v2h-2zm-30-4h2v2h-2zm-2 2h2v2h-2zm-2-2h2v2h-2zm-2 2h2v2h-2zm8 0h2v2h-2zm-2 2h2v2h-2zm-4 0h2v2h-2zm16-4h2v2h-2zm2 2h2v2h-2zm-2 2h2v2h-2zm0-2h-2v2h2zm-2 2h-2v2h2zm-2-2h-2v2h2zm-2 2h-2v2h2zm18-2h-2v2h2zm-2 2h-2v2h2zm-2-2h-2v2h2zm-2 2h-2v2h2zm36-2h-2v2h2zm0 2h6v2h-6zm0-4h6v2h-6z"/>'
            '<path d="M80 20v-6h2v6zm4 0v-6h2v6zm-64-4h-6v-2h6zm0 4h-6v-2h6z"/>'
            '<path d="M20 14v6h-2v-6zm-4 0v6h-2v-6z"/>',
            '<path d="M14 74h2v10h-2zm8 0h2v10h-2zm0 8v2h-6v-2zm0-8v2h-6v-2zm-6-2h2v2h-2zm4 0h2v2h-2zm4 8h2v2h-2zm0-4h2v2h-2zm-8 8h2v2h-2zm4 0h2v2h-2zm-2-14h2v2h-2zm0-2h2v2h-2zm0-2h2v2h-2zm2-4h2v4h-2zm-4-8h2v12h-2zm2-24h2v-2h-2zm0 2h2v-2h-2zm0 2h2v-2h-2zm2 4h2v-4h-2zm-2 22h2v2h-2zm-2-14h2V34h-2zm2-6h2v-2h-2zm22 42h2v2h-2zm-2 0h2v2h-2zm-12-4h2v2h-2zm2 2h10v2H28z"/>'
            '<path clip-rule="evenodd" d="M58 80H42v6h16zm-12 2h-2v2h2zm8 0h2v2h-2zm-2 0h-4v2h4zM20 46h-6v8h6zm-2 2h-2v4h2z" fill-rule="evenodd"/>'
            '<path d="M14 26h2V16h-2zm8 0h2V16h-2zm0-8v-2h-6v2zm0 8v-2h-6v2zm-6 2h2v-2h-2zm4 0h2v-2h-2zm4-8h2v-2h-2zm0 4h2v-2h-2zm-8-8h2v-2h-2zm4 0h2v-2h-2zm20 2h2v-2h-2zm-2 0h2v-2h-2zm-12 4h2v-2h-2zm2-2h10v-2H28z"/>'
            '<path clip-rule="evenodd" d="M58 20H42v-6h16zm-12-2h-2v-2h2zm8 0h2v-2h-2zm-2 0h-4v-2h4z" fill-rule="evenodd"/>'
            '<path d="M86 74h-2v10h2zm-8 0h-2v10h2zm0 8v2h6v-2zm0-8v2h6v-2zm6-2h-2v2h2zm-4 0h-2v2h2zm-4 8h-2v2h2zm0-4h-2v2h2zm8 8h-2v2h2zm-4 0h-2v2h2zm2-14h-2v2h2zm0-2h-2v2h2zm0-2h-2v2h2zm-2-4h-2v4h2zm4-8h-2v12h2zm-2-24h-2v-2h2zm0 2h-2v-2h2zm0 2h-2v-2h2zm-2 4h-2v-4h2zm2 22h-2v2h2zm2-14h-2V34h2zm-2-6h-2v-2h2zM60 82h-2v2h2zm2 0h-2v2h2zm12-4h-2v2h2zm-2 2H62v2h10z"/>'
            '<path clip-rule="evenodd" d="M80 46h6v8h-6zm2 2h2v4h-2z" fill-rule="evenodd"/>'
            '<path d="M86 26h-2V16h2zm-8 0h-2V16h2zm0-8v-2h6v2zm0 8v-2h6v2zm6 2h-2v-2h2zm-4 0h-2v-2h2zm-4-8h-2v-2h2zm0 4h-2v-2h2zm8-8h-2v-2h2zm-4 0h-2v-2h2zm-20 2h-2v-2h2zm2 0h-2v-2h2zm12 4h-2v-2h2zm-2-2H62v-2h10z"/>',
            '<path d="M76 16h2v8h-2zm8 0h2v8h-2z"/>'
            '<path d="M86 22v2h-8v-2zm0-8v2H76v-2zm-6 4h2v2h-2zm-2 12h2v6h-2zm6 0h2v6h-2z"/>'
            '<path d="M86 34v2h-8v-2zm0-4v2h-8v-2zM70 78v2h-6v-2zm0 6v2h-6v-2z"/>'
            '<path d="M66 86h-2v-8h2zm4 0h-2v-8h2zm0-72v2h-6v-2zm0 6v2h-6v-2z"/>'
            '<path d="M66 22h-2v-6h2zm4 0h-2v-8h2zM30 86v-2h6v2zm0-6v-2h6v2z"/>'
            '<path d="M34 78h2v6h-2zm-4 0h2v8h-2zm56-8h-2v-6h2zm-6 0h-2v-6h2z"/>'
            '<path d="M78 66v-2h6v2zm0 4v-2h8v2zM30 22v-2h6v2zm0-6v-2h6v2z"/>'
            '<path d="M34 14h2v8h-2zm-4 0h2v8h-2zm26 64v6h-2v-6zm20 0h2v8h-2zm8 0h2v8h-2z"/>'
            '<path d="M86 84v2h-8v-2zm0-8v2H76v-2zm-6 4h2v2h-2zm-34-2v6h-2v-6zm32-34h6v2h-6zM52 78v6h-4v-6zm4-62v6h-2v-6zm6 64v2h-6v-2zm16-26h6v2h-6zM38 82v-2h6v2zm8-66v6h-2v-6zM36 80v-2h2v2zm42-32h6v4h-6zM64 82v2h-2v-2zM52 16v6h-4v-6zM36 84v-2h2v2zm44-46h2v6h-2zM64 78v2h-2v-2zm-2-60v2h-6v-2zM30 82v2h-2v-2zm52-20h-2v-6h2zM72 82v-2h4v2zM38 20v-2h6v2zm-8 58v2h-2v-2zm50-14h-2v-2h2zM28 80v2h-4v-2zm8-62v-2h2v2zm34 62v-2h2v2zm12-44h2v2h-2zM70 84v-2h2v2zm-6-64v2h-2v-2zm20 44h-2v-2h2zM36 22v-2h2v2zm42 14h2v2h-2zM64 16v2h-2v-2zm18 54h2v2h-2zM30 20v2h-2v-2zm52 8h-2v-4h2zm-10-8v-2h4v2zm6 50h2v2h-2zM30 16v2h-2v-2zm50 56h2v4h-2zM28 18v2h-4v-2zm52 12h-2v-2h2zM70 18v-2h2v2zm14 12h-2v-2h2zm-14-8v-2h2v2zm-56-6h2v8h-2zm8 0h2v8h-2z"/>'
            '<path d="M24 22v2h-8v-2zm0-8v2H14v-2zm-6 4h2v2h-2zm-4 12h2v6h-2zm6 0h2v6h-2z"/>'
            '<path d="M22 34v2h-6v-2zm0-4v2h-8v-2zm0 40h-2v-6h2zm-6 0h-2v-6h2z"/>'
            '<path d="M14 66v-2h8v2zm0 4v-2h8v2zm0 8h2v8h-2zm8 0h2v8h-2z"/>'
            '<path d="M24 84v2h-8v-2zm0-8v2H14v-2zm-6 4h2v2h-2zm-2-36h6v2h-6zm0 10h6v2h-6zm0-6h6v4h-6zm2-10h2v6h-2zm2 24h-2v-6h2zm-2 2h-2v-2h2zm2-28h2v2h-2zm2 28h-2v-2h2zm-6-28h2v2h-2zm4 34h2v2h-2zm0-42h-2v-4h2zm-4 42h2v2h-2zm2 2h2v4h-2zm0-42h-2v-2h2zm4 0h-2v-2h2z"/>',
            '<path d="M14 60V44h2v16zm4 0V44h2v16zm-4 2v-2h6v2z"/>'
            '<path d="M14 46v-2h6v2zm6 10v-2h2v2zm0 4v-2h2v2zm0-8v-2h2v2zm0-4v-2h2v2zm0 32h-2v6h2zm-4 0h-2v6h2z"/>'
            '<path d="M14 80v2h6v-2zm0 4v2h6v-2zm8-8v2h2v-2zm2-2v2h2v-2zm2 2v2h2v-2zm2 2v2h2v-2zm2-2v2h2v-2zm2 0v2h2v-2zm2 0v2h2v-2zm2 0v2h2v-2zm2 2v2h2v-2zm-18 0v2h2v-2zm22 2h-2v6h2zm-4 0h-2v6h2z"/>'
            '<path d="M36 80v2h6v-2zm0 4v2h6v-2zm-16-2h16v2H20zm22 0h9v2h-9zM22 72h2v2h-2zm-2-42v-2h2v2zm-2 0v-2h2v2zm-2 14V30h2v14zm4 26h2v2h-2zm-2 0h2v2h-2zm-2-8h2v8h-2zm4-42h-2v-6h2zm-4 0h-2v-6h2z"/>'
            '<path d="M14 20v-2h6v2zm0-4v-2h6v2zm8 8v-2h2v2zm2 2v-2h2v2zm2-2v-2h2v2zm2-2v-2h2v2zm2 2v-2h2v2zm2 0v-2h2v2zm2 0v-2h2v2zm2 0v-2h2v2zm2-2v-2h2v2zm-18 0v-2h2v2zm22-2h-2v-6h2zm-4 0h-2v-6h2z"/>'
            '<path d="M36 20v-2h6v2zm0-4v-2h6v2zm-16 2h16v-2H20zm22 0h9v-2h-9zM22 28h2v-2h-2zm64 32V44h-2v16zm-4 0V44h-2v16zm4 2v-2h-6v2z"/>'
            '<path d="M86 46v-2h-6v2zm-6 10v-2h-2v2zm0 4v-2h-2v2zm0-8v-2h-2v2zm0-4v-2h-2v2zm0 32h2v6h-2zm4 0h2v6h-2z"/>'
            '<path d="M86 80v2h-6v-2zm0 4v2h-6v-2zm-8-8v2h-2v-2zm-2-2v2h-2v-2zm-2 2v2h-2v-2zm-2 2v2h-2v-2zm-2-2v2h-2v-2zm-2 0v2h-2v-2zm-2 0v2h-2v-2zm-2 0v2h-2v-2zm-2 2v2h-2v-2zm18 0v2h-2v-2zm-22 2h2v6h-2zm4 0h2v6h-2z"/>'
            '<path d="M64 80v2h-6v-2zm0 4v2h-6v-2zm16-2H64v2h16zm-22 0h-7v2h7zm20-10h-2v2h2zm2-42v-2h-2v2zm2 0v-2h-2v2zm2 14V30h-2v14zm-4 26h-2v2h2zm2 0h-2v2h2zm2-8h-2v8h2zm-4-42h2v-6h-2zm4 0h2v-6h-2z"/>'
            '<path d="M86 20v-2h-6v2zm0-4v-2h-6v2zm-8 8v-2h-2v2zm-2 2v-2h-2v2zm-2-2v-2h-2v2zm-2-2v-2h-2v2zm-2 2v-2h-2v2zm-2 0v-2h-2v2zm-2 0v-2h-2v2zm-2 0v-2h-2v2zm-2-2v-2h-2v2zm18 0v-2h-2v2zm-22-2h2v-6h-2zm4 0h2v-6h-2z"/>'
            '<path d="M64 20v-2h-6v2zm0-4v-2h-6v2zm16 2H64v-2h16zm-22 0h-7v-2h7zm20 10h-2v-2h2z"/>',
            '<path d="M24 82h-2v2h2zm0-2h-2v2h2zm2 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm-22 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm-40 4h-2v2h2zm4-2h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm-28 2h-2v2h2zm16 0h-2v2h2zm10 0h-2v2h2zm-16 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm-28-2h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm10 0h-2v2h2zm14 0h2v2h-2zm0-2h2v2h-2zm-2 0h2v2h-2zm-10 0h2v2h-2z"/>'
            '<path d="M54 80h2v2h-2zm-10 0h2v2h-2zm22 0h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm40 4h2v2h-2zm-4-2h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm28 2h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm28-2h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm-10 0h2v2h-2zm-16-4h-2v2h2zm0 4h-2v2h2zm-2-2h-2v2h2zm-2 4h2v2h-2zm-2-2h2v2h-2zm-2-2h2v2h-2zm2-2h2v2h-2zm62 0h2v2h-2zm0 4h2v2h-2zm2-2h2v2h-2zm2 4h-2v2h2zm2-2h-2v2h2zm2-2h-2v2h2zm-2-2h-2v2h2zM24 18h-2v-2h2zm0 2h-2v-2h2zm2 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-22 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-40-4h-2v-2h2zm4 2h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-28-2h-2v-2h2zm16 0h-2v-2h2zm10 0h-2v-2h2zm-16 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-28 2h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm14 0h2v-2h-2zm0 2h2v-2h-2zm-2 0h2v-2h-2zm-10 0h2v-2h-2z"/>'
            '<path d="M54 20h2v-2h-2zm-10 0h2v-2h-2zm22 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm40-4h2v-2h-2zm-4 2h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm28-2h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm28 2h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-14 0h-2v-2h2zm0 2h-2v-2h2zm2 0h-2v-2h2zm10 0h-2v-2h2z"/>'
            '<path d="M46 20h-2v-2h2zm10 0h-2v-2h2zm-22 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-40-4h-2v-2h2zm4 2h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-28-2h-2v-2h2zm16 0h-2v-2h2zm10 0h-2v-2h2zm-16 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm-28 2h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm10 0h-2v-2h2zm14 0h2v-2h-2zm0 2h2v-2h-2zm-2 0h2v-2h-2zm-10 0h2v-2h-2z"/>'
            '<path d="M54 20h2v-2h-2zm-10 0h2v-2h-2zm22 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm40-4h2v-2h-2zm-4 2h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm28-2h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm28 2h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zm-10 0h2v-2h-2zM18 76v2h-2v-2zm2 0v2h-2v-2zm0-2v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm0 22v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm-4 40v2h-2v-2zm2-4v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm-2 28v2h-2v-2zm0-16v2h-2v-2zm0-10v2h-2v-2zm0 16v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm2 28v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm0-10v2h-2v-2zm0-14v-2h-2v2zm2 0v-2h-2v2zm0 2v-2h-2v2zm0 10v-2h-2v2z"/>'
            '<path d="M20 46v-2h-2v2zm0 10v-2h-2v2zm0-22v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm-4-40v-2h-2v2zm2 4v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm-2-28v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm2-28v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm0 10v-2h-2v2zm64 14v2h2v-2zm-2 0v2h2v-2zm0-2v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm0 22v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm4 40v2h2v-2zm-2-4v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm2 28v2h2v-2zm0-16v2h2v-2zm0-10v2h2v-2zm0 16v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm-2 28v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm0-10v2h2v-2zm0-14v-2h2v2zm-2 0v-2h2v2zm0 2v-2h2v2zm0 10v-2h2v2z"/>'
            '<path d="M80 46v-2h2v2zm0 10v-2h2v2zm0-22v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm4-40v-2h2v2zm-2 4v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm2-28v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm-2-28v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zm0 10v-2h2v2zM22 22h-2v-2h2zm0-4h-2v-2h2zm-2 2h-2v-2h2zm-2-4h2v-2h-2zm-2 2h2v-2h-2zm-2 2h2v-2h-2zm2 2h2v-2h-2zm62 0h2v-2h-2zm0-4h2v-2h-2zm2 2h2v-2h-2zm2-4h-2v-2h2zm2 2h-2v-2h2zm2 2h-2v-2h2zm-2 2h-2v-2h2z"/>',
            '<path d="M16 16h2v2h-2zm-2-2h2v2h-2zm2 6h2v2h-2zm2-2h2v2h-2zm-2 2h-2v2h2zm0 2h-2v2h2z"/>'
            '<path d="M16 22h-2v2h2zm0 2h-2v2h2zm2 0h-2v2h2zm2-2h-2v2h2zm2-2h-2v2h2zm2-2h-2v2h2zm-2-2h-2v2h2zm0-2h-2v2h2zm2 0h-2v2h2zm2 0h-2v2h2zm0 2h-2v2h2zm2 0h-2v2h2zm2 0h-2v2h2zm0-2h-2v2h2zm2 0h-2v2h2zm2 0h-2v2h2zm0 2h-2v2h2zm2 0h-2v2h2zm2 0h-2v2h2zm0-2h-2v2h2zm2 0h-2v2h2zm2 0h-2v2h2zm0 2h-2v2h2zm16 0H42v2h16zM18 26h-2v2h2zm0 2h-2v2h2zm-2 0h-2v2h2zm0 2h-2v2h2zm0 2h-2v2h2zm2 0h-2v2h2zm0 2h-2v2h2zm0 2h-2v2h2zm-2 0h-2v2h2zm0 2h-2v2h2zm2 0h-2v2h2zm0 2h-2v2h2zm-2 0h-2v2h2zm2 4h-2v2h2zm-2 0h-2v2h2zm0 40h2v-2h-2zm-2 2h2v-2h-2zm2-6h2v-2h-2zm2 2h2v-2h-2zm-2-2h-2v-2h2zm0-2h-2v-2h2z"/>'
            '<path d="M16 78h-2v-2h2zm0-2h-2v-2h2zm2 0h-2v-2h2zm2 2h-2v-2h2zm2 2h-2v-2h2zm2 2h-2v-2h2zm-2 2h-2v-2h2zm0 2h-2v-2h2zm2 0h-2v-2h2zm2 0h-2v-2h2zm0-2h-2v-2h2zm2 0h-2v-2h2zm2 0h-2v-2h2zm0 2h-2v-2h2zm2 0h-2v-2h2zm2 0h-2v-2h2zm0-2h-2v-2h2zm2 0h-2v-2h2zm2 0h-2v-2h2zm0 2h-2v-2h2zm2 0h-2v-2h2zm2 0h-2v-2h2zm16-2H40v-2h18zM18 74h-2v-2h2zm0-2h-2v-2h2zm-2 0h-2v-2h2zm0-2h-2v-2h2zm0-2h-2v-2h2zm2 0h-2v-2h2zm0-2h-2v-2h2zm0-2h-2v-2h2zm-2 0h-2v-2h2zm0-2h-2v-2h2zm2 0h-2v-2h2zm0-2h-2v-2h2zm-2 0h-2v-2h2zm2-4h-2v-2h2zm0-4h-2v-2h2zm0-2h-2v-2h2zm-2 6h-2v-2h2zm0-4h-2v-2h2zm0-2h-2v-2h2zm68-34h-2v2h2zm2-2h-2v2h2zm-2 6h-2v2h2zm-2-2h-2v2h2zm2 2h2v2h-2zm0 2h2v2h-2z"/>'
            '<path d="M84 22h2v2h-2zm0 2h2v2h-2zm-2 0h2v2h-2zm-2-2h2v2h-2zm-2-2h2v2h-2zm-2-2h2v2h-2zm2-2h2v2h-2zm0-2h2v2h-2zm-2 0h2v2h-2zm-2 0h2v2h-2zm0 2h2v2h-2zm-2 0h2v2h-2zm-2 0h2v2h-2zm0-2h2v2h-2zm-2 0h2v2h-2zm-2 0h2v2h-2zm0 2h2v2h-2zm-2 0h2v2h-2zm-2 0h2v2h-2zm0-2h2v2h-2zm-2 0h2v2h-2zm-2 0h2v2h-2zm0 2h2v2h-2zm24 10h2v2h-2zm0 2h2v2h-2zm2 0h2v2h-2zm0 2h2v2h-2zm0 2h2v2h-2zm-2 0h2v2h-2zm0 2h2v2h-2zm0 2h2v2h-2zm2 0h2v2h-2zm0 2h2v2h-2zm-2 0h2v2h-2zm0 2h2v2h-2zm2 0h2v2h-2zm-2 4h2v2h-2zm2 0h2v2h-2zm0 40h-2v-2h2zm2 2h-2v-2h2zm-2-6h-2v-2h2zm-2 2h-2v-2h2zm2-2h2v-2h-2zm0-2h2v-2h-2z"/>'
            '<path d="M84 78h2v-2h-2zm0-2h2v-2h-2zm-2 0h2v-2h-2zm-2 2h2v-2h-2zm-2 2h2v-2h-2zm-2 2h2v-2h-2zm2 2h2v-2h-2zm0 2h2v-2h-2zm-2 0h2v-2h-2zm-2 0h2v-2h-2zm0-2h2v-2h-2zm-2 0h2v-2h-2zm-2 0h2v-2h-2zm0 2h2v-2h-2zm-2 0h2v-2h-2zm-2 0h2v-2h-2zm0-2h2v-2h-2zm-2 0h2v-2h-2zm-2 0h2v-2h-2zm0 2h2v-2h-2zm-2 0h2v-2h-2zm-2 0h2v-2h-2zm0-2h2v-2h-2zm24-10h2v-2h-2zm0-2h2v-2h-2zm2 0h2v-2h-2zm0-2h2v-2h-2zm0-2h2v-2h-2zm-2 0h2v-2h-2zm0-2h2v-2h-2zm0-2h2v-2h-2zm2 0h2v-2h-2zm0-2h2v-2h-2zm-2 0h2v-2h-2zm0-2h2v-2h-2zm2 0h2v-2h-2zm-2-4h2v-2h-2zm0-4h2v-2h-2zm0-2h2v-2h-2zm2 6h2v-2h-2zm0-4h2v-2h-2zm0-2h2v-2h-2z"/>',
            '<path d="M14 16h2v4h-2zm4 0h2v4h-2zm-4-2h6v2h-6z"/>'
            '<path d="M14 18h6v2h-6zm2-6h2v2h-2zm-2 14h2v10h-2zm0 16h2v6h-2zm0 12h2v6h-2zm0 12h2v8h-2zm0 16h2v4h-2zm4-56h2v10h-2zm0 16h2v6h-2zm0 12h2v6h-2zm0 12h2v8h-2zm0 16h2v4h-2zm-4-58h6v2h-6zm0 16h6v2h-6zm0 12h6v2h-6zm0 12h6v2h-6zm0 16h6v2h-6z"/>'
            '<path d="M14 34h6v2h-6zm0 12h6v2h-6zm0 12h6v2h-6zm0 16h6v2h-6zm2-36h2v2h-2zm0 12h2v2h-2zm0 12h2v2h-2z"/>'
            '<path d="M16 74h2v6h-2zm0 12h2v2h-2zm0-66h2v6h-2zm0 16h2v2h-2zm0 12h2v2h-2zm0 36h2v2h-2zm64-68h2v4h-2zm4 0h2v4h-2zm-4-2h6v2h-6z"/>'
            '<path d="M80 18h6v2h-6zm2-6h2v2h-2zm-2 14h2v10h-2zm0 16h2v6h-2zm0 12h2v6h-2zm0 12h2v8h-2zm0 16h2v4h-2zm4-56h2v10h-2zm0 16h2v6h-2zm0 12h2v6h-2zm0 12h2v8h-2zm0 16h2v4h-2zm-4-58h6v2h-6zm0 16h6v2h-6zm0 12h6v2h-6zm0 12h6v2h-6zm0 16h6v2h-6z"/>'
            '<path d="M80 34h6v2h-6zm0 12h6v2h-6zm0 12h6v2h-6zm0 16h6v2h-6zm2-36h2v2h-2zm0 12h2v2h-2zm0 12h2v2h-2z"/>'
            '<path d="M82 74h2v6h-2zm0 12h2v2h-2zm0-66h2v6h-2zm0 16h2v2h-2zm0 12h2v2h-2zm0 36h2v2h-2zm2-70v2h-4v-2zm0 4v2h-4v-2zm2-4v6h-2v-6z"/>'
            '<path d="M82 14v6h-2v-6zm6 2v2h-2v-2zm-14-2v2H64v-2zm-16 0v2h-6v-2zm-12 0v2h-6v-2zm-12 0v2h-8v-2zm-16 0v2h-4v-2zm56 4v2H64v-2zm-16 0v2h-6v-2zm-12 0v2h-6v-2zm-12 0v2h-8v-2zm-16 0v2h-4v-2zm58-4v6h-2v-6zm-16 0v6h-2v-6zm-12 0v6h-2v-6zm-12 0v6h-2v-6zm-16 0v6h-2v-6z"/>'
            '<path d="M66 14v6h-2v-6zm-12 0v6h-2v-6zm-12 0v6h-2v-6zm-16 0v6h-2v-6zm36 2v2h-2v-2zm-12 0v2h-2v-2zm-12 0v2h-2v-2z"/>'
            '<path d="M26 16v2h-6v-2zm-12 0v2h-2v-2zm66 0v2h-6v-2zm-16 0v2h-2v-2zm-12 0v2h-2v-2zm-36 0v2h-2v-2zm68 64v2h-4v-2zm0 4v2h-4v-2zm2-4v6h-2v-6z"/>'
            '<path d="M82 80v6h-2v-6zm6 2v2h-2v-2zm-14-2v2H64v-2zm-16 0v2h-6v-2zm-12 0v2h-6v-2zm-12 0v2h-8v-2zm-16 0v2h-4v-2zm56 4v2H64v-2zm-16 0v2h-6v-2zm-12 0v2h-6v-2zm-12 0v2h-8v-2zm-16 0v2h-4v-2zm58-4v6h-2v-6zm-16 0v6h-2v-6zm-12 0v6h-2v-6zm-12 0v6h-2v-6zm-16 0v6h-2v-6z"/>'
            '<path d="M66 80v6h-2v-6zm-12 0v6h-2v-6zm-12 0v6h-2v-6zm-16 0v6h-2v-6zm36 2v2h-2v-2zm-12 0v2h-2v-2zm-12 0v2h-2v-2z"/>'
            '<path d="M26 82v2h-6v-2zm-12 0v2h-2v-2zm66 0v2h-6v-2zm-16 0v2h-2v-2zm-12 0v2h-2v-2zm-36 0v2h-2v-2z"/>',
            '<path d="M14 14h2v2h-2zm2 2h2v2h-2zm-2 2h2v2h-2zm4-4h2v2h-2zm0 4h2v2h-2zm-4 24h2v2h-2zm2 2h2v2h-2zm0-24h2v2h-2zm2 2h2v2h-2zm-4 24h2v2h-2zm4-4h2v2h-2zm0 4h2v2h-2zm2-30h2v2h-2zm-6 6h2v2h-2zm8-8h2v2h-2zm-6 34h2v2h-2zm0-24h2v2h-2zm0 2h2v2h-2zm0 2h2v2h-2zm0 2h2v2h-2zm-2 2h6v2h-6zm0 4h6v2h-6z"/>'
            '<path d="M18 32h2v6h-2zm-4 0h2v6h-2zm2 6h2v4h-2zm-2 48h2v-2h-2zm2-2h2v-2h-2zm-2-2h2v-2h-2zm4 4h2v-2h-2zm0-4h2v-2h-2zm-4-24h2v-2h-2zm2-2h2v-2h-2zm0 24h2v-2h-2zm2-2h2v-2h-2zm-4-24h2v-2h-2zm4 4h2v-2h-2zm0-4h2v-2h-2zm2 30h2v-2h-2zm-6-6h2v-2h-2zm8 8h2v-2h-2zm-6-34h2v-2h-2zm0 24h2v-2h-2zm0-2h2v-2h-2zm0-2h2v-2h-2zm0-2h2v-2h-2zm-2-2h6v-2h-6zm0-4h6v-2h-6z"/>'
            '<path d="M18 68h2v-6h-2zm-4 0h2v-6h-2zm2-6h2v-4h-2zm70 24h-2v-2h2zm-2-2h-2v-2h2zm2-2h-2v-2h2zm-4 4h-2v-2h2zm0-4h-2v-2h2zm4-24h-2v-2h2zM42 86v-2h2v2zm0-66v-2h2v2zm2 64v-2h2v2zm40-28h-2v-2h2zM44 18v-2h2v2zm40 62h-2v-2h2zm-38 6v-2h2v2zm36-8h-2v-2h2zm-40 4v-2h2v2zm44-28h-2v-2h2zM46 82v-2h2v2zm0-62v-2h2v2zm36 38h-2v-2h2zM42 16v-2h2v2zm40 38h-2v-2h2zM48 84v-2h2v2zm-2-68v-2h2v2zM24 84v-2h2v2zm56 0h-2v-2h2zm-54 0v-2h2v2zm60-6h-2v-2h2zm-58 6v-2h2v2zm50 2h-2v-2h2zm-48-2v-2h2v2zm54-32h-2v-2h2zM32 86v-6h2v6zm16-68v-2h2v2zM36 86v-6h2v6zm48-10h-2v-2h2z"/>'
            '<path d="M32 82v-2h6v2zm-8-64v-2h2v2zm8 68v-2h6v2zm52-12h-2v-2h2zM38 84v-2h4v2zM26 18v-2h2v2zm58 54h-2v-2h2zM28 18v-2h2v2zm56 52h-2v-2h2zM30 18v-2h2v2zm56 50h-6v-2h6zM58 86v-2h-2v2zM32 20v-6h2v6zm24 64v-2h-2v2zm30-20h-6v-2h6zM36 20v-6h2v6z"/>'
            '<path d="M82 68h-2v-6h2zM54 86v-2h-2v2zM32 16v-2h6v2zm26 66v-2h-2v2zm28-14h-2v-6h2zM54 82v-2h-2v2zM32 20v-2h6v2zm52 42h-2v-4h2zM38 18v-2h4v2zm48-4h-2v2h2zM52 84v-2h-2v2zm32-68h-2v2h2zm-8 68v-2h-2v2zm10-66h-2v2h2zM74 84v-2h-2v2zm8-70h-2v2h2zM72 84v-2h-2v2zm10-66h-2v2h2zM70 84v-2h-2v2zm16-42h-2v2h2zM68 86v-6h-2v6zM58 20v-2h-2v2zm6 66v-6h-2v6zm20-42h-2v2h2z"/>'
            '<path d="M68 82v-2h-6v2zM56 18v-2h-2v2zm12 68v-2h-6v2zm16-66h-2v2h2zM62 84v-2h-4v2zm20-62h-2v2h2zm4 24h-2v2h2zM54 20v-2h-2v2zm28 22h-2v2h2zM58 16v-2h-2v2zm24 30h-2v2h2zM54 16v-2h-2v2zm26 0h-2v2h2zm6 6h-2v2h2zm-8-8h-2v2h2zm6 34h-2v2h2zM52 18v-2h-2v2zm32 6h-2v2h2zm-8-6v-2h-2v2zm8 8h-2v2h2zm-10-8v-2h-2v2zm10 10h-2v2h2zM72 18v-2h-2v2zm12 12h-2v2h2zM70 18v-2h-2v2zm16 14h-6v2h6zM68 20v-6h-2v6zm18 16h-6v2h6zM64 20v-6h-2v6z"/>'
            '<path d="M82 32h-2v6h2zM68 16v-2h-6v2zm18 16h-2v6h2zM68 20v-2h-6v2zm16 18h-2v4h2zM62 18v-2h-4v2z"/>',
            '<path d="M14 16v2h2v-2zm2-2v2h2v-2zm0 4v2h2v-2zm2-2v2h2v-2zm-4 68v-2h2v2zm2 2v-2h2v2zm0-4v-2h2v2zm2 2v-2h2v2zm-4-26V42h2v16zm4 0V42h2v16z"/>'
            '<path d="M14 58v-2h6v2zm0-6v-4h6v4zm0-8v-2h6v2zm4 16v-2h2v2zm-4 0v-2h2v2zm4-18v-2h2v2zm-4 0v-2h2v2zm2 18v6h2v-6zm0 12v2h2v-2zm0-32v-6h2v6zm0-12v-2h2v2zm2-2v-2h2v2zm-2-2v-2h2v2zm2-2v-2h2v2zm-4 46h6v-2h-6zm0 4h6v-2h-6z"/>'
            '<path d="M14 66v6h2v-6zm4 0v6h2v-6zm-2 6v2h2v-2zm2 2v2h2v-2zm-2 2v2h2v-2zm2 2v2h2v-2z"/>'
            '<path d="M18 74v2h2v-2zm-4-42h6v2h-6zm0-4h6v2h-6z"/>'
            '<path d="M14 34v-6h2v6zm4 0v-6h2v6zm68-18v2h-2v-2zm-2-2v2h-2v-2zm0 4v2h-2v-2zm-2-2v2h-2v-2zm4 68v-2h-2v2zm-2 2v-2h-2v2zm0-4v-2h-2v2zm-2 2v-2h-2v2zm4-26V42h-2v16zm-4 0V42h-2v16z"/>'
            '<path d="M86 58v-2h-6v2zm0-6v-4h-6v4zm0-8v-2h-6v2zm-4 16v-2h-2v2zm4 0v-2h-2v2zm-4-18v-2h-2v2zm4 0v-2h-2v2zm-2 18v6h-2v-6zm0 12v2h-2v-2zm0-32v-6h-2v6zm0-12v-2h-2v2zm-2-2v-2h-2v2zm2-2v-2h-2v2zm-2-2v-2h-2v2zm4 46h-6v-2h6zm0 4h-6v-2h6z"/>'
            '<path d="M86 66v6h-2v-6zm-4 0v6h-2v-6zm2 6v2h-2v-2zm-2 2v2h-2v-2zm2 2v2h-2v-2zm-2 2v2h-2v-2z"/>'
            '<path d="M82 74v2h-2v-2zm4-42h-6v2h6zm0-4h-6v2h6z"/>'
            '<path d="M86 34v-6h-2v6zm-4 0v-6h-2v6zM16 86h2v-2h-2zm-2-2h2v-2h-2zm4 0h2v-2h-2zm-2-2h2v-2h-2zm68 4h-2v-2h2zm2-2h-2v-2h2zm-4 0h-2v-2h2zm2-2h-2v-2h2zm-26 4H42v-2h16zm0-4H42v-2h16z"/>'
            '<path d="M58 86h-2v-6h2zm-6 0h-4v-6h4zm-8 0h-2v-6h2zm16-4h-2v-2h2zm0 4h-2v-2h2zm-18-4h-2v-2h2zm0 4h-2v-2h2zm18-2h6v-2h-6zm12 0h2v-2h-2zm-32 0h-6v-2h6zm-12 0h-2v-2h2zm-2-2h-2v-2h2zm-2 2h-2v-2h2zm-2-2h-2v-2h2zm46 4v-6h-2v6zm4 0v-6h-2v6z"/>'
            '<path d="M66 86h6v-2h-6zm0-4h6v-2h-6zm6 2h2v-2h-2zm2-2h2v-2h-2zm2 2h2v-2h-2zm2-2h2v-2h-2z"/>'
            '<path d="M74 82h2v-2h-2zm-42 4v-6h2v6zm-4 0v-6h2v6z"/>'
            '<path d="M34 86h-6v-2h6zm0-4h-6v-2h6zM16 14h2v2h-2zm-2 2h2v2h-2zm4 0h2v2h-2zm-2 2h2v2h-2zm68-4h-2v2h2zm2 2h-2v2h2zm-4 0h-2v2h2zm2 2h-2v2h2zm-26-4H42v2h16zm0 4H42v2h16z"/>'
            '<path d="M58 14h-2v6h2zm-6 0h-4v6h4zm-8 0h-2v6h2zm16 4h-2v2h2zm0-4h-2v2h2zm-18 4h-2v2h2zm0-4h-2v2h2zm18 2h6v2h-6zm12 0h2v2h-2zm-32 0h-6v2h6zm-12 0h-2v2h2zm-2 2h-2v2h2zm-2-2h-2v2h2zm-2 2h-2v2h2zm46-4v6h-2v-6zm4 0v6h-2v-6z"/>'
            '<path d="M66 14h6v2h-6zm0 4h6v2h-6zm6-2h2v2h-2zm2 2h2v2h-2zm2-2h2v2h-2zm2 2h2v2h-2z"/>'
            '<path d="M74 18h2v2h-2zm-42-4v6h2v-6zm-4 0v6h2v-6z"/>'
            '<path d="M34 14h-6v2h6zm0 4h-6v2h6z"/>',
            '<path d="M52 80h2v6h-2zm4 0h2v6h-2z"/>'
            '<path d="M58 84v2h-6v-2zm0-4v2h-6v-2zm10 0h2v6h-2zm4 0h2v6h-2z"/>'
            '<path d="M74 84v2h-6v-2zm0-4v2h-6v-2zm6-12h2v6h-2zm4 0h2v6h-2z"/>'
            '<path d="M86 72v2h-6v-2zm0-4v2h-6v-2zm-6 12h2v6h-2zm4 0h2v6h-2z"/>'
            '<path d="M86 84v2h-6v-2zm0-4v2h-6v-2zm-6-28h6v6h-6zM54 86h2v2h-2zm4-2v-2h10v2zm16-6h2v2h-2zm-24 4h2v2h-2zm26-6h2v2h-2zm2-2h2v2h-2zm-4 8h6v2h-6zm6-40h6v6h-6zm4 32v6h-2v-6zm0-16v10h-2V58zm0-26v10h-2V32zm-2 16h2v4h-2zM52 20h2v-6h-2zm4 0h2v-6h-2z"/>'
            '<path d="M58 16v-2h-6v2zm0 4v-2h-6v2zm10 0h2v-6h-2zm4 0h2v-6h-2z"/>'
            '<path d="M74 16v-2h-6v2zm0 4v-2h-6v2zm6 12h2v-6h-2zm4 0h2v-6h-2z"/>'
            '<path d="M86 28v-2h-6v2zm0 4v-2h-6v2zm-6-12h2v-6h-2zm4 0h2v-6h-2z"/>'
            '<path d="M86 16v-2h-6v2zm0 4v-2h-6v2zm-32-6h2v-2h-2zm4 2v2h10v-2zm16 6h2v-2h-2zm-24-4h2v-2h-2zm26 6h2v-2h-2zm2 2h2v-2h-2zm-4-8h6v-2h-6zm10 8v-6h-2v6zm-36-6h-2v-6h2zm-4 0h-2v-6h2z"/>'
            '<path d="M42 16v-2h6v2zm0 4v-2h6v2zm-10 0h-2v-6h2zm-4 0h-2v-6h2z"/>'
            '<path d="M26 16v-2h6v2zm0 4v-2h6v2zm-6 12h-2v-6h2zm-4 0h-2v-6h2z"/>'
            '<path d="M14 28v-2h6v2zm0 4v-2h6v2zm6-12h-2v-6h2zm-4 0h-2v-6h2z"/>'
            '<path d="M14 16v-2h6v2zm0 4v-2h6v2zm6 28h-6v-6h6zm26-34h-2v-2h2zm-4 2v2H32v-2zm-16 6h-2v-2h2zm24-4h-2v-2h2zm-26 6h-2v-2h2zm-2 2h-2v-2h2zm4-8h-6v-2h6zm-6 40h-6v-6h6zm-4-32v-6h2v6zm0 16V32h2v10zm0 26V58h2v10zm2-16h-2v-4h2zm30 28h-2v6h2zm-4 0h-2v6h2z"/>'
            '<path d="M42 84v2h6v-2zm0-4v2h6v-2zm-10 0h-2v6h2zm-4 0h-2v6h2z"/>'
            '<path d="M26 84v2h6v-2zm0-4v2h6v-2zm-6-12h-2v6h2zm-4 0h-2v6h2z"/>'
            '<path d="M14 72v2h6v-2zm0-4v2h6v-2zm6 12h-2v6h2zm-4 0h-2v6h2z"/>'
            '<path d="M14 84v2h6v-2zm0-4v2h6v-2zm32 6h-2v2h2zm-4-2v-2H32v2zm-16-6h-2v2h2zm24 4h-2v2h2zm-26-6h-2v2h2zm-2-2h-2v2h2zm4 8h-6v2h6zm-10-8v6h2v-6z"/>'
        ];
        string[11] memory chipDetailTraits = [
            "Detail 1",
            "Detail 2",
            "Detail 3",
            "Detail 4",
            "Detail 5",
            "Detail 6",
            "Detail 7",
            "Detail 8",
            "Detail 9",
            "Detail 10",
            "Detail 11"
        ];
        return (chipDetailSVGs[idx], chipDetailTraits[idx]);
    }
}
