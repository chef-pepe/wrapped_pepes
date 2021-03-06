//SPDX-License-Identifier: Unlicense
pragma solidity =0.6.11;

import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./Mintable.sol";

contract Minter is Ownable {
    event Claimed(
        uint256 index,
        bytes32 sig,
        address account,
        uint256 count
    );

    bytes32 public immutable merkleRoot;

    Mintable public mintable;

    mapping(uint256 => bool) public claimed;

    uint256 public nextId = 1;
    mapping(bytes32 => uint256) public sigToTokenId;

    constructor(bytes32 _merkleRoot) public {
        merkleRoot = _merkleRoot;
    }

    function setMintable(Mintable _mintable) public onlyOwner {
        require(address(mintable) == address(0), "Minter: Can't set Mintable contract twice");
        mintable = _mintable;
    }

    function merkleVerify(bytes32 node, bytes32[] memory proof) public view returns (bool) {
        return MerkleProof.verify(proof, merkleRoot, node);
    }

    function makeNode(
        uint256 index,
        bytes32 sig,
        address account,
        uint256 count
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(index, sig, account, count));
    }

    function claim(
        uint256 index,
        bytes32 sig,
        address account,
        uint256 count,
        bytes32[] memory proof
    ) public {
        require(address(mintable) != address(0), "Minter: Must have a mintable set");

        require(!claimed[index], "Minter: Can't claim a drop that's already been claimed");
        claimed[index] = true;

        bytes32 node = makeNode(index, sig, account, count);
        require(merkleVerify(node, proof), "Minter: merkle verification failed");

        uint256 id = sigToTokenId[sig];
        if (id == 0) {
            sigToTokenId[sig] = nextId;
            mintable.setTokenId(nextId, sig);
            id = nextId;

            nextId++;
        }

        mintable.mint(account, id, count);

        emit Claimed(index, sig, account, count);
    }
}
