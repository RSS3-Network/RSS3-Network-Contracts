// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

library Head {
    //h: st-head e:st-head-evenodd
    function getHead(uint256 id) external pure returns (string memory, string memory) {
        string[16] memory res = [
            '<path class="h" d="M66 40v-2h-2v-2h-2v-2h-2v-2h-2v-2h-2v-2h-4v-2h-2v-2H38v2h-2v2h-4v2h-2v4h2v-2h7v4h-4v2h-2v2h-7v2h48v-2zm-8 0H42v-2h16z"/>',
            '<path class="h e" d="M70 34v-4h-2v-2h-2v-2h-6v2h-2v2h-2v2h-2v2h-8v-2h-2v-2h-2v-2h-2v-2h-6v2h-2v2h-2v4h-2v8h44v-8zm-26 4H30v-2h2v-4h2v-2h6v2h2v4h2zm26 0H56v-2h2v-4h2v-2h6v2h2v4h2z"/>',
            '<path class="h e" d="M72 38v4h2v-4zm-46 0v4h2v-4zm42-2v-2h-2v-2h-4v-2h-2v-2H40v2h-2v2h-4v2h-2v2h-4v2h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v4h8v-4h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v4h2v-4h2v-2zm-16 4h-4v-4h4z"/>',
            '<path class="h" d="M28 40h44v2H28z"/>'
            '<path class="h e" d="M40 33v-3h-2v-2h-2v2h-2v2h-2v2h-2v2h-2v2h5v-2h2v2h5v-3h-4v-2z"/>'
            '<path class="h e" d="M42 24v2h-4v2h4v2h5v2h-5v6h7V24zm5 4h-2v-2h2zm23 8v-2h-2v-2h-2v-2h-2v-2h-2v2h-2v3h4v2h-6v-3h-3v6h10v-2h2v2h5v-2z"/>'
            '<path class="h e" d="M58 26v-2h-7v14h2v-8h5v-2h4v-2zm-3 2h-2v-2h2z"/>',
            '<path class="h" d="M30 24h4v2h-4zm4 2h2v8h-2z"/>'
            '<path class="h" d="M72 26v14h-2v2H30v-2h-2V26h2v12h4v-2h2v-2h4v-2h20v2h4v2h2v2h4V26zm-6-2h4v2h-4z"/>'
            '<path class="h" d="M64 26h2v8h-2z"/>',
            '<path class="h" d="M70 38v4H30v-4h2v-2h2v-2h2v-2h2v7h2v-9h4v9h2v-7h8v7h2v-9h4v9h2v-7h2v2h2v2h2v2zM38 26h2v4h-2zm6 0h2v4h-2zm-4-2h4v2h-4zm14 2h2v4h-2zm6 0h2v4h-2zm-4-2h4v2h-4z"/>',
            '<path class="h" d="M72 34v2H28v-2h2v-2h2v-2h2v-2h2v-2h28v2h2v2h2v2h2v2zm-48 4h2v2h-2zm2 2h48v2H26zm48-2h2v2h-2z"/>',
            '<path class="h" d="M72 30v12H28V30h2v6h6v-2h4v-8h2v8h6v2h4v-2h6v-8h2v8h4v2h6v-6z"/>'
            '<path class="h" d="M30 26h2v4h-2zm38 0h2v4h-2zm-36-2h8v2h-8zm28 0h8v2h-8z"/>',
            '<path class="h" d="M47 24h4v2h-4z"/>'
            '<path class="h e" d="M78 40v2H63v-6h-2v-2h-2v-2h-2v-2h-2v-2h4v2h2v2h2v2h3v2h2v2h2v2z"/>'
            '<path class="h e" d="M59 36v-2h-2v-2h-2v-2h-2v-2h-4v2h-2v2h-2v2h-2v-2h2v-2h2v-2h-8v2h-2v2h-2v2h-3v2h-2v2h-2v4h33v-6zm-9 4H38v-2h2v-2h8v2h2z"/>',
            '<path class="h e" d="M74 34v-2h-2v-2h-2v-2h-4v-2h-4v2h-8v-2h-2v-2h-4v2h-2v2h-8v-2h-4v2h-4v2h-2v2h-2v2h-2v6h2v2h2v-6h2v-2h8v2h2v6h20v-6h2v-2h8v2h2v6h2v-2h2v-6zm-18 4h-2v2h-8v-2h-2v-6h2v-2h8v2h2z"/>',
            '<path class="h e" d="M70 28H72V30V32V38V42H28V38V32V30V28H30V30H34V32H36V34H44V32H46V30H48V28H52V30H54V32H56V34H64V32H66V30H70V28ZM62 30H64V32H56V30H58V28H62V30ZM44 32H36V30H38V28H42V30H44V32ZM32 32H30V34V36V38V40H32V38H34V36V34H32V32ZM52 32H48V34H46V36V38H48V40H52V38H54V36V34H52V32ZM70 32H68V34H66V36V38H68V40H70V38V36V34V32Z"/>',
            '<path class="h e" d="M32 26h2v2h-2zm-2 4v-2h2v2zm-2 2v-2h2v2zm0 8h-2v-8h2zm6 0v2h-6v-2zm0-2h2v-2h2v-2h2v-2h4v10h-8v-2h-2zm0-6v6h-2v-6zm0 0h2v-4h-2zm12 10V32h2v-2h4v2h2v10zm10 0h8v-2h2v2h6v-2h2v-8h-2v-2h-2v-2h-2v-2h-2v2h-2v4h2v6h-2v-2h-2v-2h-2v-2h-4zm10-4v2h6v-8h-2v-2h-2v-2h-2v4h2v6zm-14-5h-4v4h4zm-4 5h4v2h-4z"/>',
            '<path class="h e" d="M70 40v2h2v-2zM48 22v2h4v-2z"/>'
            '<path class="h e" d="M74 30v-2h-2v-2H41v2h-7v2h-6v2h-2v2h-2v2h-2v4h4v2h4v-2h-2v-2h2v2h2v2h8v-2h-2v-2h-2v-2h2v2h2v2h2v2h16v-2h2v2h8v-2h2v-2h4v-2h2v-6zM54 40h-8v-6h2v-2h4v2h2z"/>'
            '<path class="h" d="M48 36h4v2h-4z"/>',
            '<path class="h" d="M66 34v2H34v-2h2v-4h2v-2h2v-2h4v2h2v2h8v-2h2v-2h4v2h2v2h2v4z"/>'
            '<path class="h" d="M74 32v6h-2v2h-2v2H30v-2h-2v-2h-2v-6h2v2h2v2h2v2h36v-2h2v-2h2v-2z"/>',
            '<path class="h" d="M32 48h36v2H32z"/>'
            '<path class="h e" d="M40 28h20v2h2v2h4v2h2v2h4v2h2v20H26V38h2v-2h4v-2h2v-2h4v-2h2zm8 2h-2v2h2zM30 46v8h40v-8zm20-16h2v2h-2zm-2 4h-2v2h2zm-2 4h2v2h-2zm2 4h-2v2h2zm-20 0h2v2h-2zm24-8h-2v2h2zm-2 4h2v2h-2zm2 4h-2v2h2zm18 0h2v2h-2z"/>',
            '<path class="h" d="M74 24v2h-4v3h-2v3h2v2H30v-2h2v-3h-2v-3h-4v-2zM28 36h44v2H28zm-4 4h52v2H24zm-2-2h2v2h-2zm54 0h2v2h-2z"/>'
        ];

        string[16] memory headTraits = [
            "Magic Hat",
            "Round Ears",
            "Beanie",
            "Brains",
            "Rabbit Ears",
            "Antenna",
            "Bowler Hat",
            "Tall Ears",
            "Hat",
            "Mushroom",
            "Crown",
            "Viking",
            "Beret",
            "Cowboy Hat",
            "Cyclops",
            "Top Hat"
        ];
        return (res[id % 16], headTraits[id % 16]);
    }
}
