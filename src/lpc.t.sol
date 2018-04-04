pragma solidity ^0.4.20;

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

import "ds-test/test.sol";
import 'ds-roles/roles.sol';
import './lpc.sol';

contract Tester {
    SaiLPC lpc;
    function Tester(SaiLPC lpc_) public {
        lpc = lpc_;

        lpc.lps().approve(lpc, uint(-1));
        lpc.ref().approve(lpc, uint(-1));
        lpc.alt().approve(lpc, uint(-1));
    }
    function pool(ERC20 gem, uint wad) public {
        lpc.pool(gem, wad);
    }
    function exit(ERC20 gem, uint wad) public {
        lpc.exit(gem, wad);
    }
    function take(ERC20 gem, uint wad) public {
        lpc.take(gem, wad);
    }
}

contract LPCTest is DSTest, DSMath {
    ERC20   ref;
    ERC20   alt;
    DSToken lps;
    DSValue pip;
    SaiLPC  lpc;
    DSRoles mom;

    Tester   t1;
    Tester   m1;
    Tester   m2;
    Tester   m3;

    function ray(uint wad) pure internal returns (uint) {
        return wad * 10 ** 9;
    }

    function setRoles() public {
        mom.setRoleCapability(1, address(lpc), bytes4(keccak256("pool(address,uint256)")), true);
        mom.setRoleCapability(1, address(lpc), bytes4(keccak256("exit(address,uint256)")), true);
        mom.setRoleCapability(1, address(lpc), bytes4(keccak256("take(address,uint256)")), true);
    }

    function setUp() public {
        ref = new DSTokenBase(10 ** 24);
        alt = new DSTokenBase(10 ** 24);
        lps = new DSToken('LPS');

        pip = new DSValue();
        pip.poke(bytes32(2 ether)); // 2 refs per gem

        uint gap = 1.04 ether;

        lpc = new SaiLPC(ref, alt, pip, lps);
        lpc.jump(gap);
        lps.setOwner(lpc);

        mom = new DSRoles();
        lpc.setAuthority(mom);
        mom.setRootUser(this, true);
        setRoles();

        t1 = new Tester(lpc);
        m1 = new Tester(lpc);
        m2 = new Tester(lpc);
        m3 = new Tester(lpc);

        mom.setUserRole(t1, 1, true);
        mom.setUserRole(m1, 1, true);
        mom.setUserRole(m2, 1, true);
        mom.setUserRole(m3, 1, true);

        alt.transfer(t1, 100 ether);
        ref.transfer(m1, 100 ether);
        ref.transfer(m2, 100 ether);
        ref.transfer(m3, 100 ether);
    }

    function testBasicLPC() public {
        assertEq(lpc.per(), RAY);
        m1.pool(ref, 100 ether);
        assertEq(lps.balanceOf(m1), 100 ether);

        t1.take(ref, 50 ether);
        assertEq(ref.balanceOf(t1),  50 ether);
        assertEq(alt.balanceOf(lpc), 26 ether);
        assertEq(lpc.pie(), 102 ether);

        m2.pool(ref, 100 ether);
        assertEq(lpc.pie(), 202 ether);

        // m2 still has claim to $100 worth
        assertEq(rdiv(uint(lps.balanceOf(m2)), lpc.per()), 100 ether);

        t1.take(ref, 50 ether);
        assertEq(lpc.pie(), 204 ether);

        pip.poke(bytes32(1 ether));  // 1 ref per gem

        m3.pool(ref, 100 ether);
        assertEq(lpc.pie(), 252 ether);

        // m3 has claim to $100
        assertEq(rdiv(lps.balanceOf(m3), lpc.per()), 100 ether);
        // but m1, m2 have less claim each
        assertEq(rdiv(lps.balanceOf(m1) + lps.balanceOf(m2), lpc.per()), 152 ether);
    }
}
