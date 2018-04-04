/// lpc.sol -- really dumb liquidity pool

// Copyright (C) 2017, 2018 Rain <rainbreak@riseup.net>

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.4.20;

import "ds-thing/thing.sol";
import "ds-token/token.sol";
import "ds-value/value.sol";


contract SaiLPC is DSThing {
    // This is a simple two token liquidity pool that uses an external
    // price feed.

    // Makers
    // - `pool` their gems and receive LPS tokens, which are a claim
    //    on the pool.
    // - `exit` and trade their LPS tokens for a share of the gems in
    //    the pool

    // Takers
    // - `take` and exchange one gem for another, whilst paying a
    //   fee (the `gap`). The collected fee goes into the pool.

    // To avoid `pool`, `exit` being used to circumvent the taker fee,
    // makers must pay the same fee on `exit`.

    // provide liquidity for this gem pair
    ERC20    public  ref;
    ERC20    public  alt;

    DSValue  public  pip;  // price feed, giving refs per alt
    uint256  public  gap;  // spread, charged on `take`
    DSToken  public  lps;  // 'liquidity provider shares', earns spread

    function SaiLPC(ERC20 ref_, ERC20 alt_, DSValue pip_, DSToken lps_) public {
        ref = ref_;
        alt = alt_;
        pip = pip_;

        lps = lps_;
        gap = WAD;
    }

    function jump(uint wad) public note auth {
        assert(wad != 0);
        gap = wad;
    }

    // ref per alt
    function tag() public view returns (uint) {
        return uint(pip.read());
    }

    // total pool value
    function pie() public view returns (uint) {
        return add(ref.balanceOf(this), wmul(alt.balanceOf(this), tag()));
    }

    // lps per ref
    function per() public view returns (uint) {
        return lps.totalSupply() == 0
             ? RAY
             : rdiv(lps.totalSupply(), pie());
    }

    // {ref,alt} -> lps
    function pool(ERC20 gem, uint wad) public note auth {
        require(gem == alt || gem == ref);

        uint jam = (gem == ref) ? wad : wmul(wad, tag());
        uint ink = rmul(jam, per());
        lps.mint(ink);
        lps.push(msg.sender, ink);

        gem.transferFrom(msg.sender, this, wad);
    }

    // lps -> {ref,alt}
    function exit(ERC20 gem, uint wad) public note auth {
        require(gem == alt || gem == ref);

        uint jam = (gem == ref) ? wad : wmul(wad, tag());
        uint ink = rmul(jam, per());
        // pay fee to exit, unless you're the last out
        ink = (jam == pie())? ink : wmul(gap, ink);
        lps.pull(msg.sender, ink);
        lps.burn(ink);

        gem.transfer(msg.sender, wad);
    }

    // ref <-> alt
    // TODO: meme 'swap'?
    // TODO: mem 'yen' means to desire. pair with 'pay'? or 'ney'
    function take(ERC20 gem, uint wad) public note auth {
        require(gem == alt || gem == ref);

        uint jam = (gem == ref) ? wdiv(wad, tag()) : wmul(wad, tag());
        jam = wmul(gap, jam);

        ERC20 pay = (gem == ref) ? alt : ref;
        pay.transferFrom(msg.sender, this, jam);
        gem.transfer(msg.sender, wad);
    }
}
