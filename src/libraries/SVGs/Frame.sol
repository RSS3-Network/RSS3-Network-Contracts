// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

library Frame {
    //class: f

    function getFrame(uint256 id) external pure returns (string memory, string memory) {
        string[9] memory frameSVGs = [
            '<path class="f" d="M51 8h-2V6h2zM27 6h-2v2h2zm12 0h-2v2h2zm42 0v2h-2V6h-2v4h-6V6h-2v2h-2V6h-2v4h-6V6h-2v2h-2V6h-2v4h-6V6h-2v2h-2V6h-2v4h-6V6h-2v2h-2V6h-2v4h-6V6h-2v2h-2V6h-3v6h68V6zM63 6h-2v2h2zm12 0h-2v2h2zM8 63H6v-2h2zm0 10H6v2h2zm0-48H6v2h2zm0 24H6v2h2zM6 16v3h2v2H6v2h4v6H6v2h2v2H6v2h4v6H6v2h2v2H6v2h4v6H6v2h2v2H6v2h4v6H6v2h2v2H6v2h4v6H6v2h2v2H6v3h6V16zm2 21H6v2h2zm84-18v2h2v2h-4v6h4v2h-2v2h2v2h-4v6h4v2h-2v2h2v2h-4v6h4v2h-2v2h2v2h-4v6h4v2h-2v2h2v2h-4v6h4v2h-2v2h2v3h-6V16h6v3zm0 20h2v-2h-2zm0-12h2v-2h-2zm0 24h2v-2h-2zm0 12h2v-2h-2zm0 12h2v-2h-2zM37 92h2v2h-2zm-21-4v6h3v-2h2v2h2v-4h6v4h2v-2h2v2h2v-4h6v4h2v-2h2v2h2v-4h6v4h2v-2h2v2h2v-4h6v4h2v-2h2v2h2v-4h6v4h2v-2h2v2h3v-6zm33 6h2v-2h-2zm12 0h2v-2h-2zm12 0h2v-2h-2zm-48 0h2v-2h-2z"/>',
            '<path class="f" d="M32 10v2H16V6h12v2H18v2h10V8h2v2zm0 0h4V8h-4zm4 2h2v-2h-2zm-6-4h2V6h-2zm42-2v2h10v2H72V8h-2v2h-2v2h16V6zm-4 2h2V6h-2zm-6 4h2v-2h-2zm2-4V6H51v2h5v2h-5V8h-2v2h-5V8h5V6H36v2h6v2h-2v2h20v-2h-2V8zm0 2h4V8h-4zm20 78v6H72v-2h10v-2H68v-2zm-52 2h4v2h-4zm4-2h2v2h-2zm-20 0v6h12v-2H18v-2h10v2h2v-2h2v-2zm14 4h2v2h-2zm40-2v2h2v-2zm-2 2h2v2h-2zm-6-4h2v2h-2zm-4 4v-2h2v-2H40v2h2v2h-6v2h13v-2h-5v-2h5v2h2v-2h5v2h-5v2h13v-2zm6-2h4v2h-4zM12 68v16H6V72h2v10h2V72H8v-2h2v-2zM6 16v12h2V18h2v10H8v2h2v2h2V16zm4 24v2H8v-6H6v13h2v-5h2v5H8v2h2v5H8v-5H6v13h2v-6h2v2h2V40zm0 28v-4H8v4zm2-4v-2h-2v2zm-4 6v-2H6v2zm0-38v-2H6v2zm4 6v-2h-2v2zm-2-2v-4H8v4zm84 36v12h-6V68h2v2h2v2h-2v10h2V72zm-6-56v16h2v-2h2v-2h-2V18h2v10h2V16zm2 33v-5h2v5h2V36h-2v6h-2v-2h-2v20h2v-2h2v6h2V51h-2v5h-2v-5h2v-2zm0 19v-4h2v4zm-2-4v-2h2v2zm4 6v-2h2v2zm0-38v-2h2v2zm-4 6v-2h2v2zm2-2v-4h2v4z"/>',
            '<path class="f" d="M16 10h68v2H16zm4-4h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zM16 88h68v2H16zm4 4h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm8 0h4v2h-4zm14-76v68h-2V16zm4 4v4h-2v-4zm0 8v4h-2v-4zm0 8v4h-2v-4zm0 8v4h-2v-4zm0 8v4h-2v-4zm0 8v4h-2v-4zm0 8v4h-2v-4zm0 8v4h-2v-4zM12 16v68h-2V16zm-4 4v4H6v-4zm0 8v4H6v-4zm0 8v4H6v-4zm0 8v4H6v-4zm0 8v4H6v-4zm0 8v4H6v-4zm0 8v4H6v-4zm0 8v4H6v-4z"/>',
            '<path class="f" d="M12 16v68h-2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2H8v-4h2v-2zm78 6v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h2v4h-2v2h-2V16h2v2h2v4zm-6-12v2H16v-2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2h2V8h4v2zm0 78v2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-4v-2h-2v-2z"/>',
            '<path class="f" d="M84 6v6H16V6h4v4h4V6h4v4h4V6h4v4h4V6h4v4h4V6h4v4h4V6h4v4h4V6h4v4h4V6h4v4h4V6zm6 14v4h4v4h-4v4h4v4h-4v4h4v4h-4v4h4v4h-4v4h4v4h-4v4h4v4h-4v4h4v4h-4v4h4v4h-6V16h6v4zm-6 68v6h-4v-4h-4v4h-4v-4h-4v4h-4v-4h-4v4h-4v-4h-4v4h-4v-4h-4v4h-4v-4h-4v4h-4v-4h-4v4h-4v-4h-4v4h-4v-6zM12 16v68H6v-4h4v-4H6v-4h4v-4H6v-4h4v-4H6v-4h4v-4H6v-4h4v-4H6v-4h4v-4H6v-4h4v-4H6v-4h4v-4H6v-4z"/>',
            '<path class="f" d="M92 18v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h2v2h-2v2h-4V16h6v2zm-80-2v68H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2H6v-2h2v-2zm72 72v4h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-2h-2v2h-2v-6zm0-82v6H16V8h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6h2v2h2V6z"/>',
            '<path class="f" d="M6 16h4v8H6zm0 10h4v4H6zm0 6h4v10H6zm4 52H6v-8h4zm0-10H6v-4h4zm0-6H6V58h4zM4 44v12h6V44zm4 10H6v-8h2zM84 6v4h-8V6zM74 6v4h-4V6zm-6 0v4H58V6zm-52 4V6h8v4zm10 0V6h4v4zm6 0V6h10v4zm12-6v6h12V4zm10 4h-8V6h8zM16 94v-4h8v4zm10 0v-4h4v4zm6 0v-4h10v4zm52-4v4h-8v-4zm-10 0v4h-4v-4zm-6 0v4H58v-4zm-24 0v6h12v-6zm10 4h-8v-2h8zm40-10h-4v-8h4zm0-10h-4v-4h4zm0-6h-4V58h4zm-4-52h4v8h-4zm0 10h4v4h-4zm0 6h4v10h-4zm0 12v12h6V44zm4 10h-2v-8h2z"/>',
            '<path class="f" d="M92 18v2h2v4h-2v2h2v2h-2v2h2v4h-2v2h2v4h-2v2h2v2h-2v2h2v8h-2v2h2v2h-2v2h2v4h-2v2h2v2h-2v2h2v4h-2v2h2v4h-2v2h2v2h-4V16h4v2zM84 6v4H16V6h2v2h2V6h4v2h2V6h4v2h2V6h2v2h2V6h4v2h2V6h2v2h2V6h8v2h2V6h2v2h2V6h4v2h2V6h4v2h2V6h2v2h2V6h4v2h2V6zm0 84v4h-2v-2h-2v2h-4v-2h-2v2h-2v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-2v-2h-2v2h-8v-2h-2v2h-2v-2h-2v2h-4v-2h-2v2h-2v-2h-2v2h-4v-2h-2v2h-4v-2h-2v2h-2v-4zM10 16v68H6v-2h2v-2H6v-4h2v-2H6v-4h2v-2H6v-2h2v-2H6v-4h2v-2H6v-2h2v-2H6v-8h2v-2H6v-2h2v-2H6v-4h2v-2H6v-4h2v-2H6v-2h2v-2H6v-4h2v-2H6v-2z"/>',
            '<path class="f" d="M16 88h68v2H16zm0 4h4v2h-4zm6 0h2v2h-2zm4 0h6v2h-6zm12 0h6v2h-6zm8 0h3v2h-3zm5 0h3v2h-3zm-17 0h2v2h-2zm22 0h6v2h-6zm8 0h2v2h-2zm4 0h6v2h-6zm12 0h4v2h-4zm-4 0h2v2h-2zM16 10h68v2H16zm0-4h4v2h-4zm6 0h2v2h-2zm4 0h6v2h-6zm12 0h6v2h-6zm8 0h3v2h-3zm5 0h3v2h-3zM34 6h2v2h-2zm22 0h6v2h-6zm8 0h2v2h-2zm4 0h6v2h-6zm12 0h4v2h-4zm-4 0h2v2h-2zM12 16v68h-2V16zM6 84v-4h2v4zm0-6v-2h2v2zm0-4v-6h2v6zm0-12v-6h2v6zm0-8v-3h2v3zm0-5v-3h2v3zm0 17v-2h2v2zm0-22v-6h2v6zm0-8v-2h2v2zm0-4v-6h2v6zm0-12v-4h2v4zm0 4v-2h2v2zm84-8v68h-2V16zm2 68v-4h2v4zm0-6v-2h2v2zm0-4v-6h2v6zm0-12v-6h2v6zm0-8v-3h2v3zm0-5v-3h2v3zm0 17v-2h2v2zm0-22v-6h2v6zm0-8v-2h2v2zm0-4v-6h2v6zm0-12v-4h2v4zm0 4v-2h2v2z"/>'
        ];

        string[9] memory frameTraits = [
            "Frame 1",
            "Frame 2",
            "Frame 3",
            "Frame 4",
            "Frame 5",
            "Frame 6",
            "Frame 7",
            "Frame 8",
            "Frame 9"
        ];

        uint256 idx = id % 9;

        return (frameSVGs[idx], frameTraits[idx]);
    }
}
