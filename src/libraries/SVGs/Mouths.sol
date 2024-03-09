// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

library Mouths {
    function getMouth(uint256 id) external pure returns (string memory, string memory) {
        string[19] memory res = [
            '<path d="M38 62h2v6h-2zM60 62h2v6h-2zM40 62v-2h20v2z" fill="#000"/><path d="M40 68v-6h20v6z" fill="#DEE5D9"/><path d="M40 66v-2h20v2zM40 70v-2h20v2z" fill="#000"/>',
            '<path d="M42 62h2v2h-2zM44 62v-2h12v2zM56 62h2v2h-2zM58 64h2v2h-2zM40 64h2v2h-2zM58 64H42v2h16zM56 62H44v2h12zM40 66h2v2h-2zM58 66h2v2h-2zM56 66h2v2h-2zM42 66h14v2H42z" fill="#000"/><path d="M42 64h16v2H42z" fill="#DEE5D9"/>',
            '<path d="M40 62h2v2h-2zM42 64h2v2h-2zM42 62h2v2h-2zM44 64h2v2h-2z" fill="#000"/><path d="M44 64h16v4H44z" fill="#000"/>',
            '<path d="M38 61h2v2h-2zM42 63h4v4h-4zM40 63h2v4h-2z" fill="#000"/><path d="M54 63h4v2h-4z" fill="#DEE5D9"/><path d="M46 63h2v4h-2zM52 63h2v4h-2zM58 63h2v4h-2zM40 61h20v2H40zM54 63h4v4h-4z" fill="#000"/><path d="M54 61h4v2h-4zM44 61h2v2h-2z" fill="#DEE5D9"/><path d="M60 61h2v2h-2zM48 63h4v4h-4zM40 67h20v2H40zM36 63h2v2h-2zM34 61h2v2h-2zM34 63h2v2h-2zM34 65h2v2h-2zM66 61h-2v2h2zM66 63h-2v2h2zM66 65h-2v2h2zM38 63h2v4h-2z" fill="#000"/><path d="M52 67h2v2h-2z" fill="#DEE5D9"/><path d="M60 63h2v4h-2zM62 63h2v2h-2z" fill="#000"/>',
            '<path d="M36 60h2v2h-2zM62 60h2v2h-2zM38 62h24v2H38zM40 64h20v2H40z" fill="#000"/>',
            '<path d="M43 62h2v2h-2zM55 62h2v2h-2zM45 64h2v2h-2zM53 64h2v2h-2zM57 60h2v2h-2zM57 62h2v2h-2zM57 64h2v2h-2zM59 66h2v2h-2zM61 66h2v2h-2zM59 58h2v2h-2zM43 60h-2v2h2zM43 62h-2v2h2zM43 64h-2v2h2zM41 66h-2v2h2zM39 66h-2v2h2zM41 58h-2v2h2zM47 64h6v2h-6zM47 66h6v2h-6z" fill="#000"/>',
            '<path d="M48 62h4v2h-4zM48 68h4v2h-4zM48 64v4h-2v-4zM54 64v4h-2v-4zM52 64v4h-4v-4z" fill="#000"/>',
            '<path d="M28 62h4v2h-4zM32 62h2v2h-2zM66 62h6v2h-6zM34 62h2v4h-2zM64 62h2v4h-2zM36 66h2v2h-2zM38 68h2v2h-2zM40 66h2v2h-2zM42 68h2v2h-2zM44 66h2v2h-2zM48 66h4v2h-4zM46 68h2v2h-2zM52 68h2v2h-2zM54 66h2v2h-2zM56 68h2v2h-2zM58 66h2v2h-2zM60 68h2v2h-2zM62 66h2v2h-2z" fill="#000"/>',
            '<path d="M38 62h24v2H38zM40 64h20v2H40zM42 66h16v2H42zM42 68h16v2H42zM44 70h12v2H44z" fill="#000"/><path d="M46 66h8v8h-8zM48 76h4v-2h-4zM46 64h2v2h-2zM52 64h2v2h-2z" fill="#DEE5D9"/><path d="M36 60h2v2h-2zM62 60h2v2h-2z" fill="#000"/>',
            '<path d="M36 60h28v2H36zM38 62h24v2H38zM40 64h20v2H40z" fill="#000"/><path d="M42 62h16v2H42z" fill="#DEE5D9"/><path d="M42 66h16v2H42z" fill="#000"/>',
            '<path d="M38 61h2v2h-2zM40 63h4v2h-4zM44 61h4v2h-4zM48 63h4v2h-4zM52 61h4v2h-4zM56 63h4v2h-4zM60 61h2v2h-2zM64 65h2v2h-2zM34 65h2v2h-2zM36 63h2v2h-2zM62 63h2v2h-2z" fill="#000"/>',
            '<path d="M44 64h2v2h-2z" fill="#000"/><path d="M42 64h2v2h-2z" fill="#DEE5D9"/><path d="M58 64h2v2h-2zM40 64h2v2h-2zM54 64h2v2h-2z" fill="#000"/><path d="M56 64h2v2h-2z" fill="#DEE5D9"/><path d="M42 66h2v2h-2zM36 60h2v2h-2zM62 60h2v2h-2zM56 66h2v2h-2zM38 62h24v2H38z" fill="#000"/>',
            '<path d="M40 62h20v10H40zm0 12h20v-2H40zm2 2h16v-2H42z" fill="#DEE5D9"/>'
            '<path d="M38 64h2v8h-2zm0-2h2v2h-2zm2-2h2v2h-2zm2 0h2v2h-2zm2 0h2v2h-2zm2 0h2v2h-2zm2 0h2v2h-2zm14 4h-2v8h2zm0-2h-2v2h2zm-2-2h-2v2h2zm-2 0h-2v2h2zm-2 0h-2v2h2zm-2 0h-2v2h2zm-2 0h-2v2h2zm-6 8h8v2h-8zm-2-2h2v2h-2zm10 0h2v2h-2z" fill="#000"/>',
            '<path d="M44 60h12v2H44zM46 66h8v2h-8zM44 62h5v2h-5zM42 62h2v2h-2zM42 64h2v2h-2zM40 64h2v2h-2zM56 64h4v2h-4zM38 62h2v2h-2zM60 62h2v2h-2zM56 62h2v2h-2zM51 62h5v2h-5z" fill="#000"/>',
            '<path d="M36 60h28v8H36z" fill="#000"/><path d="M38 64h24v2H38zM40 66h20v2H40zM38 68h24v2H38zM42 70h16v2H42z" fill="#000"/><path d="M44 66h12v8H44z" fill="#DEE5D9"/><path d="M48 68h4v-2h-4z" fill="#000"/><path d="M38 64h24v-2H38zM46 76h8v-2h-8z" fill="#DEE5D9"/><path d="M36 60h2v2h-2zM62 60h2v2h-2z" fill="#000"/>',
            '<path d="M46 58h8v8h-8z" fill="#DEE5D9"/><path d="M44 60h12v4H44z" fill="#DEE5D9"/><path d="M46 56h8v2h-8zM46 66h8v2h-8zM54 58h2v2h-2zM54 64h2v2h-2zM52 60h2v2h-2zM52 62h2v2h-2zM56 60h2v2h-2zM56 62h2v2h-2zM44 58h2v2h-2zM44 64h2v2h-2zM42 60h2v2h-2zM42 62h2v2h-2zM46 60h2v2h-2zM46 62h2v2h-2z" fill="#140B1C"/>',
            '<path d="M40 66h20v2H40z" fill="#000"/><path d="M44 66h2v2h-2zM48 66h2v2h-2zM52 66h2v2h-2zM56 66h2v2h-2zM42 64h2v2h-2zM46 64h2v2h-2zM50 64h2v2h-2zM54 64h2v2h-2zM58 64h2v2h-2zM40 62h2v2h-2zM38 62h2v4h-2zM60 62h2v4h-2zM44 62h2v2h-2zM48 62h2v2h-2zM52 62h2v2h-2zM56 62h2v2h-2zM42 60h2v2h-2zM46 60h2v2h-2zM50 60h2v2h-2zM54 60h2v2h-2z" fill="#000"/><path d="M38 60h24v2H38z" fill="#000"/>',
            '<path d="M48 60h4v2h-4zM48 66h4v2h-4zM46 62h2v2h-2zM44 64h2v2h-2zM38 60h2v2h-2zM42 62h2v2h-2zM40 62h2v2h-2zM52 62h2v2h-2zM54 64h2v2h-2zM60 60h2v2h-2zM56 62h2v2h-2zM58 62h2v2h-2z" fill="#000"/>',
            '<path d="M36 60h28v2H36z" fill="#000"/><path d="M46 62h8v5h-8z" fill="#DEE5D9"/><path d="M46 60v7h-2v-7zM56 60v7h-2v-7zM51 60v7h-2v-7z" fill="#000"/><path d="M44 65h12v2H44z" fill="#000"/>'
        ];

        string[19] memory mouthTraits = [
            "Grimace",
            "Scared",
            "Smirk",
            "Toothless",
            "Small Smile",
            "Cheeky",
            "Surprised",
            "Skull",
            "Tongue Out",
            "Big Smile",
            "Crumpled",
            "Fangs",
            "Beard",
            "Suave",
            "Big Tongue Out",
            "Pig Nose",
            "Grinding",
            "Moustache",
            "Buck Teeth"
        ];

        return (res[id % 9], mouthTraits[id % 9]);
    }
}
